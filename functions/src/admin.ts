import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

/**
 * The Admin SDK bypasses Firestore security rules; every callable re-checks
 * membership itself before it touches anything. This is the Firebase
 * equivalent of the `SECURITY DEFINER` functions the Supabase backend used
 * (they had to exist because RLS could not express "create the first
 * workspace together with its owner").
 */
admin.initializeApp();

export const db = admin.firestore();
export const auth = admin.auth();

export type MemberRole = 'owner' | 'admin' | 'developer' | 'reviewer' | 'viewer';

export const ADMIN_ROLES: MemberRole[] = ['owner', 'admin'];
export const EDITOR_ROLES: MemberRole[] = ['owner', 'admin', 'developer', 'reviewer'];

export function httpsError(
  code: 'unauthenticated' | 'permission-denied' | 'invalid-argument' | 'failed-precondition' | 'internal',
  message: string,
): HttpsError {
  return new HttpsError(code, message);
}

export function memberRef(wsId: string, uid: string) {
  return db.doc(`workspaces/${wsId}/members/${uid}`);
}

export function requireAuth(request: { auth?: { uid?: string } }): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw httpsError('unauthenticated', 'سجّل الدخول أولاً.');
  }
  return uid;
}

/** The role of `uid` in `wsId`, or null when they are not a member. */
export async function roleIn(wsId: string, uid: string): Promise<MemberRole | null> {
  const snap = await memberRef(wsId, uid).get();
  const role = snap.get('role') as MemberRole | undefined;
  return role ?? null;
}

export async function requireMember(wsId: string, uid: string): Promise<MemberRole> {
  const role = await roleIn(wsId, uid);
  if (!role) {
    throw httpsError('permission-denied', 'أنت لست عضواً في مساحة العمل.');
  }
  return role;
}

export async function requireAdmin(wsId: string, uid: string): Promise<MemberRole> {
  const role = await requireMember(wsId, uid);
  if (!ADMIN_ROLES.includes(role)) {
    throw httpsError('permission-denied', 'الأمر يحتاج صلاحية مدير.');
  }
  return role;
}

export async function requireOwner(wsId: string, uid: string): Promise<void> {
  const role = await requireMember(wsId, uid);
  if (role !== 'owner') {
    throw httpsError('permission-denied', 'الأمر خاص بمالك مساحة العمل فقط.');
  }
}

/** The caller's e-mail, lowercased, or null. */
export async function callerEmail(uid: string): Promise<string | null> {
  const user = await auth.getUser(uid);
  const email = user.email?.trim().toLowerCase();
  return email ? email : null;
}

export function logActivity(
  wsId: string,
  type: string,
  text: string,
  actorId: string | null,
  projectId: string | null = null,
) {
  return db.collection(`workspaces/${wsId}/activity`).add({
    type,
    text,
    actorId,
    projectId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
