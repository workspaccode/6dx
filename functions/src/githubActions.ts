import { onCall } from 'firebase-functions/v2/https';
import { db, requireAuth, requireMember, requireAdmin, httpsError } from './admin';
import {
  optionalEnv,
  signState,
  installationToken,
  githubHeaders,
} from './github';

/**
 * The app-facing actions of the GitHub App broker — the callable twin of the
 * old edge function's `POST {action}` endpoint. `onCall` verifies the Firebase
 * ID token itself, so the manual JWT parsing of the Supabase version is gone.
 *
 *   installation | repositories  — any member may look
 *   install-url | disconnect     — admins only
 */
const GITHUB_API = 'https://api.github.com';

export const githubAction = onCall({ region: 'europe-west1' }, async (request) => {
  const uid = requireAuth(request);
  const action = request.data?.action as string | undefined;
  const wsId = request.data?.workspaceId as string | undefined;
  if (!action) throw httpsError('invalid-argument', 'مطلوب: action.');
  if (!wsId) throw httpsError('invalid-argument', 'مطلوب: workspaceId.');

  switch (action) {
    case 'installation':
    case 'repositories': {
      await requireMember(wsId, uid);
      const installations = await db
        .collection(`workspaces/${wsId}/githubInstallations`)
        .orderBy('createdAt')
        .limit(1)
        .get();
      const installation = installations.empty
        ? null
        : {
            installationId: installations.docs[0].id,
            accountLogin: installations.docs[0].get('accountLogin'),
            accountType: installations.docs[0].get('accountType'),
          };
      if (action === 'installation') return { installation };

      if (!installation) throw httpsError('failed-precondition', 'لا يوجد تثبيت مربوط بهذه المساحة.');
      const token = await installationToken(Number(installation.installationId));
      const response = await fetch(`${GITHUB_API}/installation/repositories?per_page=100`, {
        headers: githubHeaders(token),
      });
      if (!response.ok) {
        throw httpsError('internal', `تعذّر قراءة مستودعات GitHub (${response.status}).`);
      }
      const payload = (await response.json()) as {
        total_count?: number;
        repositories?: unknown[];
      };
      return { totalCount: payload.total_count ?? 0, repositories: payload.repositories ?? [] };
    }

    case 'install-url': {
      await requireAdmin(wsId, uid);
      const slug = optionalEnv('GITHUB_APP_SLUG');
      if (!slug) {
        throw httpsError('internal', 'تطبيق GitHub غير مُهيّأ (GITHUB_APP_SLUG).');
      }
      const state = await signState(wsId, uid);
      return {
        url: `https://github.com/apps/${slug}/installations/new?state=${encodeURIComponent(state)}`,
      };
    }

    case 'disconnect': {
      await requireAdmin(wsId, uid);
      const installations = await db
        .collection(`workspaces/${wsId}/githubInstallations`)
        .get();
      const batch = db.batch();
      installations.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      return { ok: true };
    }

    default:
      throw httpsError('invalid-argument', `أمر غير معروف: ${action}`);
  }
});
