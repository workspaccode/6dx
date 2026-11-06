import { onCall } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import {
  db,
  auth,
  requireAuth,
  requireAdmin,
  callerEmail,
  httpsError,
  memberRef,
  logActivity,
} from './admin';

/**
 * Port of `supabase/migrations/0008_invitations.sql`.
 *
 * In the Supabase backend an invite row triggered a DB trigger that notified
 * an existing account (`notify_invite()`). Firestore has no such trigger, so
 * the whole invite — row + notification + activity — is one callable.
 *
 * Notification ids are deterministic (`<wsId>_<inviteId>`), so syncing twice
 * or re-notifying can never duplicate anything.
 */

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/** An invite notification for `uid`, idempotent on the invite id. */
async function notifyInvitee(
  uid: string,
  wsId: string,
  inviteId: string,
  role: string,
  workspaceName: string,
  inviterName: string | null,
) {
  await db
    .doc(`users/${uid}/notifications/${wsId}_${inviteId}`)
    .set(
      {
        workspaceId: wsId,
        kind: 'invite',
        title: `دعوة للانضمام إلى ${workspaceName}`,
        body: `${inviterName ?? 'أحد المدراء'} دعاك للانضمام بدور ${role}`,
        actionLabel: 'قبول الدعوة',
        projectId: null,
        isRead: false,
        inviteId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

/** Creates one invite per e-mail and notifies existing accounts. */
export const sendInvites = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = requireAuth(request);
  const wsId = request.data?.workspaceId as string | undefined;
  const emails = (request.data?.emails as string[] | undefined) ?? [];
  const role = (request.data?.role as string | undefined) ?? 'developer';

  if (!wsId) throw httpsError('invalid-argument', 'مطلوب: workspaceId.');
  if (emails.length === 0) throw httpsError('invalid-argument', 'لا يوجد بريد لدعوته.');

  const callerRole = await requireAdmin(wsId, uid);
  // The RLS policies of 0001: `owner` can never be handed out by an invite,
  // and only the owner may invite an admin.
  if (role === 'owner') {
    throw httpsError('permission-denied', 'لا يمكن دعوة أحد كمالك.');
  }
  if (role === 'admin' && callerRole !== 'owner') {
    throw httpsError('permission-denied', 'دعوة مدير تحتاج مالك المساحة.');
  }

  const workspace = await db.doc(`workspaces/${wsId}`).get();
  const workspaceName = (workspace.get('name') as string | undefined) ?? 'مساحة عمل';
  let inviterName: string | null = null;
  try {
    const inviter = await auth.getUser(uid);
    inviterName = inviter.displayName || inviter.email || null;
  } catch {
    inviterName = null;
  }

  const created: { email: string; invited: boolean }[] = [];
  for (const rawEmail of emails) {
    const email = rawEmail.trim().toLowerCase();
    if (!email) continue;

    const inviteRef = db.collection(`workspaces/${wsId}/invites`).doc();
    await inviteRef.set({
      email,
      role,
      status: 'pending',
      invitedBy: uid,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + INVITE_TTL_MS),
    });

    // The 0008 trigger: notify the invitee when the account already exists.
    try {
      const invitee = await auth.getUserByEmail(email);
      if (invitee) {
        await notifyInvitee(invitee.uid, wsId, inviteRef.id, role, workspaceName, inviterName);
      }
    } catch {
      // No account with that e-mail yet — `syncMyInvites` delivers later.
    }
    created.push({ email, invited: true });
  }

  await logActivity(wsId, 'member_invited', `تمت دعوة ${created.length} عضو بدور ${role}`, uid);
  return { created };
});

/** The invites visible on the accept screen, newest first. */
export const myPendingInvites = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = requireAuth(request);
  const email = await callerEmail(uid);
  if (!email) return { invites: [] };

  const snap = await db
    .collectionGroup('invites')
    .where('email', '==', email)
    .where('status', '==', 'pending')
    .get();

  const invites: {
    inviteId: string;
    workspaceId: string;
    workspaceName: unknown;
    role: unknown;
    email: unknown;
    sentAt: number;
    sentAtIso: string | null;
  }[] = [];
  for (const doc of snap.docs) {
    const expiresAt = doc.get('expiresAt') as admin.firestore.Timestamp | undefined;
    if (!expiresAt || expiresAt.toMillis() <= Date.now()) continue;
    const wsId = doc.ref.parent.parent!.id;
    if ((await memberRef(wsId, uid).get()).exists) continue;

    const workspace = await db.doc(`workspaces/${wsId}`).get();
    invites.push({
      inviteId: doc.id,
      workspaceId: wsId,
      workspaceName: workspace.get('name') ?? 'مساحة عمل',
      role: doc.get('role'),
      email: doc.get('email'),
      sentAt: doc.get('sentAt')?.toMillis?.() ?? 0,
      sentAtIso: doc.get('sentAt')?.toDate?.().toISOString?.() ?? null,
    });
  }

  invites.sort((a, b) => b.sentAt - a.sentAt);
  return { invites };
});

/** Delivers notifications for invites that pre-date the account. */
export const syncMyInvites = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = requireAuth(request);
  const email = await callerEmail(uid);
  if (!email) return { created: 0 };

  const snap = await db
    .collectionGroup('invites')
    .where('email', '==', email)
    .where('status', '==', 'pending')
    .get();

  let created = 0;
  for (const doc of snap.docs) {
    const expiresAt = doc.get('expiresAt') as admin.firestore.Timestamp | undefined;
    if (!expiresAt || expiresAt.toMillis() <= Date.now()) continue;
    const wsId = doc.ref.parent.parent!.id;
    if ((await memberRef(wsId, uid).get()).exists) continue;

    const workspace = await db.doc(`workspaces/${wsId}`).get();
    await notifyInvitee(
      uid,
      wsId,
      doc.id,
      doc.get('role') ?? 'developer',
      workspace.get('name') ?? 'مساحة عمل',
      null,
    );
    created++;
  }
  return { created };
});

/** Turns the caller's pending invite into a membership — port of `accept_invite()`. */
export const acceptInvite = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = requireAuth(request);
  const email = await callerEmail(uid);
  if (!email) {
    throw httpsError('failed-precondition', 'حسابك بلا بريد إلكتروني لمطابقة الدعوة.');
  }
  const target = request.data?.inviteId as string | undefined;

  let found: {
    id: string;
    wsId: string;
    role: string;
    status: string;
    email: string;
    invitedBy: string | null;
    expiresAt: admin.firestore.Timestamp;
  } | null = null;

  if (target) {
    // The invite lives under a workspace we do not know yet, so the id is
    // looked up across the collection group.
    const exact = await db
      .collectionGroup('invites')
      .where(admin.firestore.FieldPath.documentId(), '==', target)
      .limit(1)
      .get();
    if (!exact.empty) {
      const doc = exact.docs[0];
      found = {
        id: doc.id,
        wsId: doc.ref.parent.parent!.id,
        role: doc.get('role') ?? 'developer',
        status: doc.get('status') ?? 'pending',
        email: doc.get('email') ?? '',
        invitedBy: doc.get('invitedBy') ?? null,
        expiresAt: doc.get('expiresAt'),
      };
    }
  } else {
    const snap = await db
      .collectionGroup('invites')
      .where('email', '==', email)
      .where('status', '==', 'pending')
      .get();
    const fresh = snap.docs
      .filter((doc) => {
        const at = doc.get('expiresAt') as admin.firestore.Timestamp | undefined;
        return at && at.toMillis() > Date.now();
      })
      .sort((a, b) => {
        const sa = (a.get('sentAt') as admin.firestore.Timestamp)?.toMillis() ?? 0;
        const sb = (b.get('sentAt') as admin.firestore.Timestamp)?.toMillis() ?? 0;
        return sb - sa;
      });
    if (fresh.length > 0) {
      const doc = fresh[0];
      found = {
        id: doc.id,
        wsId: doc.ref.parent.parent!.id,
        role: doc.get('role') ?? 'developer',
        status: doc.get('status') ?? 'pending',
        email: doc.get('email') ?? '',
        invitedBy: doc.get('invitedBy') ?? null,
        expiresAt: doc.get('expiresAt'),
      };
    }
  }

  const invite = found;
  if (!invite) throw httpsError('failed-precondition', 'لا توجد دعوة في انتظار هذا الحساب.');
  if (invite.email.toLowerCase() !== email) {
    throw httpsError('permission-denied', 'هذه الدعوة موجهة لبريد آخر.');
  }
  if (invite.status !== 'pending') {
    throw httpsError('failed-precondition', 'هذه الدعوة اتقبلت أو اتلغت بالفعل.');
  }
  if (invite.expiresAt.toMillis() <= Date.now()) {
    await db.doc(`workspaces/${invite.wsId}/invites/${invite.id}`).update({ status: 'expired' });
    throw httpsError('failed-precondition', 'انتهت صلاحية الدعوة.');
  }

  const wsId = invite.wsId;
  const inviteRef = db.doc(`workspaces/${wsId}/invites/${invite.id}`);
  const inviteSnapshot = invite;

  await db.runTransaction(async (tx) => {
    tx.set(memberRef(wsId, uid), {
      userId: uid,
      role: inviteSnapshot.role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(inviteRef, { status: 'accepted' });
    tx.set(
      db.doc(`users/${uid}/notifications/${wsId}_${inviteSnapshot.id}`),
      { isRead: true },
      { merge: true },
    );
    tx.set(db.doc(`users/${uid}`), { defaultWorkspaceId: wsId }, { merge: true });
    // Tell whoever sent the invite (the 0008 tail).
    if (inviteSnapshot.invitedBy) {
      tx.set(
        db.doc(`users/${inviteSnapshot.invitedBy}/notifications/${wsId}_joined_${uid}`),
        {
          workspaceId: wsId,
          kind: 'member_joined',
          title: 'عضو جديد في مساحة العمل',
          body: `${email} قبل الدعوة وانضم بدور ${inviteSnapshot.role}`,
          actionLabel: null,
          projectId: null,
          isRead: false,
          inviteId: null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  });

  await logActivity(wsId, 'member_joined', `${email} انضم بدور ${invite.role}`, uid);
  return { workspaceId: wsId };
});
