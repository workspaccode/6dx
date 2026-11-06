import { onCall } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { db, requireAuth, requireMember, httpsError, logActivity, ADMIN_ROLES } from './admin';

/**
 * Port of `submit_client_decision(target, option_index)` —
 * `supabase/migrations/0007_client_decision_rules.sql`.
 *
 * The tightening of 0007 is preserved verbatim:
 *   * the report is a single document, so "the report" is well defined,
 *   * an out-of-range index is rejected instead of recorded,
 *   * the decision is written once; an owner/admin may correct it.
 */
export const submitClientDecision = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = requireAuth(request);
  const wsId = request.data?.workspaceId as string | undefined;
  const optionIndex = request.data?.optionIndex as number | undefined;

  if (!wsId || typeof optionIndex !== 'number') {
    throw httpsError('invalid-argument', 'مطلوب: workspaceId و optionIndex.');
  }
  const role = await requireMember(wsId, uid);

  const reportRef = db.doc(`workspaces/${wsId}/clientReport/report`);
  const report = await reportRef.get();
  if (!report.exists) {
    throw httpsError('failed-precondition', 'لا يوجد تقرير عميل لهذه المساحة.');
  }

  const options = (report.get('decisionOptions') as string[] | undefined) ?? [];
  if (!Number.isInteger(optionIndex) || optionIndex < 0 || optionIndex >= options.length) {
    throw httpsError(
      'invalid-argument',
      `اختيار خارج النطاق (0..${Math.max(options.length - 1, 0)}).`,
    );
  }
  const chosen = options[optionIndex];

  const decidedAt = report.get('decidedAt') as admin.firestore.Timestamp | undefined;
  if (decidedAt && !ADMIN_ROLES.includes(role)) {
    throw httpsError('failed-precondition', 'قرار العميل اتسجّل بالفعل.');
  }

  await reportRef.update({
    decisionChoice: chosen,
    decidedBy: uid,
    decidedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await logActivity(wsId, 'client_decision', `قرار العميل: ${chosen}`, uid);

  return { chosen };
});
