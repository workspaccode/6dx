import { onCall } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { db, requireAuth, requireOwner, httpsError, memberRef, logActivity } from './admin';

/**
 * Port of `supabase/migrations/0002_workspace_bootstrap.sql` and the
 * `transfer_ownership()` RPC of `0004`.
 *
 * A workspace cannot be created through a plain Firestore write (the rules
 * refuse `create` on /workspaces): it must appear together with the owner
 * membership, which only this callable does.
 */
export const ensureMyWorkspace = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = requireAuth(request);
  const name = (request.data?.name as string | undefined)?.trim() || 'مساحة عملي';

  // Reuse the cached pointer first — the common case for every launch.
  const userDoc = await db.doc(`users/${uid}`).get();
  const cached = userDoc.get('defaultWorkspaceId') as string | undefined;
  if (cached) {
    const stillMember = await memberRef(cached, uid).get();
    if (stillMember.exists) return { workspaceId: cached };
  }

  // Then a full lookup (covers invites accepted on another device).
  const memberships = await db
    .collectionGroup('members')
    .where('userId', '==', uid)
    .limit(1)
    .get();
  if (!memberships.empty) {
    const wsId = memberships.docs[0].ref.parent.parent!.id;
    await db.doc(`users/${uid}`).set(
      { defaultWorkspaceId: wsId },
      { merge: true },
    );
    return { workspaceId: wsId };
  }

  // First sign-in: create the workspace, the owner membership and the
  // pointer atomically. The slug mirrors 0002 (unique by construction).
  const slug = `ws-${uid.replace(/-/g, '').slice(0, 8)}-${Date.now()
    .toString(36)
    .toUpperCase()}`;
  const wsRef = db.collection('workspaces').doc();
  const wsId = wsRef.id;

  await db.runTransaction(async (tx) => {
    tx.set(wsRef, {
      name,
      slug,
      ownerId: uid,
      settings: {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(memberRef(wsId, uid), {
      userId: uid,
      role: 'owner',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.doc(`users/${uid}`), { defaultWorkspaceId: wsId }, { merge: true });
  });

  return { workspaceId: wsId };
});

/**
 * Port of `transfer_ownership(target, new_owner)`:
 *   * only the current owner may call it,
 *   * the new owner must already be a member,
 *   * the swap is atomic (Firestore transaction) — the partial unique index
 *     "one owner per workspace" is guaranteed by construction here.
 */
export const transferOwnership = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = requireAuth(request);
  const wsId = request.data?.workspaceId as string | undefined;
  const newOwner = request.data?.newOwnerId as string | undefined;
  if (!wsId || !newOwner) {
    throw httpsError('invalid-argument', 'مطلوب: workspaceId و newOwnerId.');
  }
  await requireOwner(wsId, uid);
  if (newOwner === uid) return { ok: true };

  const newOwnerDoc = await memberRef(wsId, newOwner).get();
  if (!newOwnerDoc.exists) {
    throw httpsError('failed-precondition', 'المالك الجديد لازم يكون عضواً في المساحة.');
  }

  await db.runTransaction(async (tx) => {
    tx.update(memberRef(wsId, newOwner), { role: 'owner' });
    tx.update(memberRef(wsId, uid), { role: 'admin' });
    tx.update(db.doc(`workspaces/${wsId}`), {
      ownerId: newOwner,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await logActivity(wsId, 'ownership_transferred', 'تم نقل ملكية مساحة العمل', uid);
  return { ok: true };
});
