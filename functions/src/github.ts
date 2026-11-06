import { onRequest } from 'firebase-functions/v2/https';
import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { db, auth } from './admin';

/**
 * The GitHub App broker — port of `supabase/functions/github-app/index.ts`
 * (three review rounds of security fixes are preserved verbatim).
 *
 *   Leg 1  POST install-url (a callable, see githubActions.ts) hands the app a
 *          signed state and opens `github.com/apps/<slug>/installations/new`.
 *   Leg 2  GET  ?installation_id=…&state=…   — GitHub's Setup URL. The signed
 *          state names the workspace; GitHub does not promise to echo the
 *          state back, so a missing state falls back to a recovery token that
 *          names the installation alone.
 *   Leg 3  GET  ?code=…&state=…              — the OAuth callback. The user
 *          token proves the browser's identity (checked against the Firebase
 *          account linked to that GitHub id), the installation's account must
 *          belong to that user (personal) or be administered by them (org),
 *          and only then is anything stored. The token is revoked afterwards.
 *   Webhook POST /webhook — HMAC verified, pull request state upserted.
 *
 * Fail closed: without GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET the legs refuse
 * instead of falling back to a weaker check.
 */

const GITHUB_API = 'https://api.github.com';
const GITHUB_OAUTH = 'https://github.com/login/oauth';
const STATE_TTL_MS = 30 * 60 * 1000;

type Json = Record<string, unknown>;

function env(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`missing secret: ${name}`);
  return value;
}

function optionalEnv(name: string): string | null {
  const value = process.env[name];
  return value && value.length > 0 ? value : null;
}

function stateSecret(): string {
  return process.env.STATE_SECRET ?? env('GITHUB_WEBHOOK_SECRET');
}

function htmlPage(message: string): { body: string; contentType: string } {
  return {
    body: `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>6DX</title>
<style>body{font-family:system-ui,sans-serif;background:#0F1115;color:#E8EAF0;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
div{max-width:420px;padding:28px;border-radius:16px;background:#171A21;
border:1px solid #2A2F3A;text-align:center;line-height:1.7}</style></head>
<body><div>${message}</div></body></html>`,
    contentType: 'text/html; charset=utf-8',
  };
}

function pageResponse(message: string) {
  const page = htmlPage(message);
  return new Response(page.body, { headers: { 'Content-Type': page.contentType } });
}

// --- state -------------------------------------------------------------------

function hmac(secret: string, value: string): string {
  return crypto.createHmac('sha256', secret).update(value).digest('hex');
}

function sameSignature(expected: string, actual: string): boolean {
  const a = Buffer.from(expected);
  const b = Buffer.from(actual);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function freshEnough(issuedAt: string): boolean {
  const age = Date.now() - Number(issuedAt);
  return Number.isFinite(age) && age >= 0 && age <= STATE_TTL_MS;
}

async function signState(workspaceId: string, userId: string, installationId = 0): Promise<string> {
  const payload = `v1.${workspaceId}.${userId}.${installationId}.${Date.now()}`;
  return `${payload}.${hmac(stateSecret(), payload)}`;
}

type StatePayload = { workspaceId: string; userId: string; installationId: number };

async function verifyState(state: string): Promise<StatePayload | null> {
  const parts = state.split('.');
  if (parts.length !== 6 || parts[0] !== 'v1') return null;

  const [, workspaceId, userId, installationId, issuedAt, signature] = parts;
  const payload = `v1.${workspaceId}.${userId}.${installationId}.${issuedAt}`;
  if (!sameSignature(hmac(stateSecret(), payload), signature)) return null;
  if (!freshEnough(issuedAt)) return null;

  return { workspaceId, userId, installationId: Number(installationId) || 0 };
}

/** The fallback when GitHub drops the state on the setup redirect. */
async function signRecovery(installationId: number): Promise<string> {
  const payload = `r1.${installationId}.${Date.now()}`;
  return `${payload}.${hmac(stateSecret(), payload)}`;
}

async function verifyRecovery(state: string): Promise<{ installationId: number } | null> {
  const parts = state.split('.');
  if (parts.length !== 4 || parts[0] !== 'r1') return null;

  const [, installationId, issuedAt, signature] = parts;
  const payload = `r1.${installationId}.${issuedAt}`;
  if (!sameSignature(hmac(stateSecret(), payload), signature)) return null;
  if (!freshEnough(issuedAt)) return null;

  const id = Number(installationId) || 0;
  return id ? { installationId: id } : null;
}

// --- GitHub ------------------------------------------------------------------

async function appJwt(): Promise<string> {
  const b64 = (input: object) =>
    Buffer.from(JSON.stringify(input)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned =
    b64({ alg: 'RS256', typ: 'JWT' }) +
    '.' +
    b64({ iat: now - 60, exp: now + 540, iss: env('GITHUB_APP_ID') });
  const signature = crypto
    .createSign('RSA-SHA256')
    .update(unsigned)
    .sign(env('GITHUB_PRIVATE_KEY'))
    .toString('base64url');
  return `${unsigned}.${signature}`;
}

async function installationToken(installationId: number): Promise<string> {
  const response = await fetch(
    `${GITHUB_API}/app/installations/${installationId}/access_tokens`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${await appJwt()}`,
        Accept: 'application/vnd.github+json',
      },
    },
  );
  if (!response.ok) throw new Error(`installation token failed (${response.status})`);
  const body = (await response.json()) as { token?: string };
  if (!body.token) throw new Error('installation token missing');
  return body.token;
}

function githubHeaders(token: string): Record<string, string> {
  return {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github+json',
    'User-Agent': '6dx',
  };
}

async function revokeUserToken(userToken: string): Promise<void> {
  const clientId = optionalEnv('GITHUB_CLIENT_ID');
  const clientSecret = optionalEnv('GITHUB_CLIENT_SECRET');
  if (!clientId || !clientSecret) return;
  try {
    await fetch(`${GITHUB_API}/applications/${clientId}/token`, {
      method: 'DELETE',
      headers: {
        Authorization: `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`,
        Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ access_token: userToken }),
    });
  } catch (error) {
    console.warn('github: token revocation failed', String(error));
  }
}

/**
 * Anti-CSRF, the Firebase way: the signed state names a 6DX user, the OAuth
 * token names a GitHub user. The Firebase account must be linked to that
 * GitHub id, otherwise an attacker could hand a fresh install link to a victim
 * and have the victim's installation stored in the attacker's workspace.
 */
async function identityMatches(
  firebaseUserId: string,
  githubUserId: number | undefined,
): Promise<{ ok: boolean; message: string }> {
  if (!githubUserId) return { ok: false, message: 'تعذّر قراءة حساب GitHub.' };
  let linked: admin.auth.UserRecord;
  try {
    linked = await auth.getUserByProviderUid('github.com', String(githubUserId));
  } catch {
    return {
      ok: false,
      message:
        'حساب GitHub ده مش مربوط بأي حساب 6DX. سجّل الدخول بـ GitHub في التطبيق ' +
        'ثم أعد التثبيت من هناك.',
    };
  }
  if (linked.uid !== firebaseUserId) {
    return {
      ok: false,
      message:
        'الحساب اللي في المتصفح مختلف عن الحساب اللي سجّلت بيه في 6DX. ' +
        'افتح رابط التثبيت من جديد بعد تسجيل الدخول بنفس الحساب.',
    };
  }
  return { ok: true, message: '' };
}

/** Recovery path: derive the workspace from the GitHub identity instead of the state. */
async function resolveWorkspaceForGithubUser(
  githubUserId: number | undefined,
): Promise<{ ok: true; userId: string; workspaceId: string } | { ok: false; message: string }> {
  if (!githubUserId) return { ok: false, message: 'تعذّر قراءة حساب GitHub.' };
  let user: admin.auth.UserRecord;
  try {
    user = await auth.getUserByProviderUid('github.com', String(githubUserId));
  } catch {
    return {
      ok: false,
      message:
        'حساب GitHub ده مش مربوط بأي حساب 6DX. سجّل الدخول بـ GitHub في التطبيق ' +
        'ثم أعد التثبيت من هناك.',
    };
  }

  const pointer = await db.doc(`users/${user.uid}`).get();
  const cached = pointer.get('defaultWorkspaceId') as string | undefined;
  if (cached) {
    const stillMember = await db.doc(`workspaces/${cached}/members/${user.uid}`).get();
    if (stillMember.exists) return { ok: true, userId: user.uid, workspaceId: cached };
  }

  const owned = await db
    .collectionGroup('members')
    .where('userId', '==', user.uid)
    .where('role', '==', 'owner')
    .limit(2)
    .get();
  if (owned.size === 1) {
    return {
      ok: true,
      userId: user.uid,
      workspaceId: owned.docs[0].ref.parent.parent!.id,
    };
  }
  if (owned.size > 1) {
    return {
      ok: false,
      message:
        'عندك أكتر من مساحة عمل تملكها. ابدأ التثبيت من داخل التطبيق عشان نعرف ' +
        'نربطه بأنهي مساحة.',
    };
  }

  const member = await db
    .collectionGroup('members')
    .where('userId', '==', user.uid)
    .limit(2)
    .get();
  if (member.size === 1) {
    return {
      ok: true,
      userId: user.uid,
      workspaceId: member.docs[0].ref.parent.parent!.id,
    };
  }
  return {
    ok: false,
    message: 'مش لاقي مساحة عمل واحدة للحساب ده. ابدأ التثبيت من داخل التطبيق.',
  };
}

/**
 * `/user/installations` is too broad: a plain org member could attach the whole
 * org installation to their workspace. The installer must own the account, or
 * administer the org.
 */
async function checkOwnership(
  userToken: string,
  user: { id: number; login: string },
  account: { id?: number; type?: string; login?: string },
): Promise<{ ok: boolean; message: string }> {
  if (account.type === 'User') {
    if (account.id !== user.id) {
      return {
        ok: false,
        message: 'التثبيت ده على حساب GitHub تاني — سجّل الدخول بحسابك هو.',
      };
    }
    return { ok: true, message: '' };
  }
  if (account.type === 'Organization') {
    const orgLogin = account.login;
    if (!orgLogin) return { ok: false, message: 'تعذّر قراءة بيانات المؤسسة.' };
    const response = await fetch(
      `${GITHUB_API}/user/memberships/orgs/${encodeURIComponent(orgLogin)}`,
      { headers: githubHeaders(userToken) },
    );
    if (!response.ok) {
      return {
        ok: false,
        message: `تعذّر التحقق من عضويتك في ${orgLogin} (${response.status}).`,
      };
    }
    const membership = (await response.json()) as {
      state?: string;
      role?: string;
    };
    if (membership.state !== 'active' || membership.role !== 'admin') {
      return {
        ok: false,
        message:
          'تثبيت التطبيق على مؤسسة يحتاج صلاحية admin فيها. اطلب من مالك المؤسسة ' +
          'يعمل التثبيت أو يرفع صلاحيتك.',
      };
    }
    return { ok: true, message: '' };
  }
  return { ok: false, message: 'نوع الحساب ده غير مدعوم.' };
}

function callbackUrl(requestUrl: URL): string {
  // The callback must be the function's own URL — derived from the request so
  // the App settings stay in sync with the deployed region.
  const url = new URL(requestUrl.toString());
  url.search = '';
  return url.toString();
}

// --- the browser legs --------------------------------------------------------

async function handleSetup(url: URL): Promise<Response> {
  const installationId = Number(url.searchParams.get('installation_id') ?? '0');
  if (!installationId) return pageResponse('لم يصل معرّف التثبيت من GitHub.');

  const clientId = optionalEnv('GITHUB_CLIENT_ID');
  const clientSecret = optionalEnv('GITHUB_CLIENT_SECRET');
  if (!clientId || !clientSecret) {
    return pageResponse(
      'تطبيق GitHub غير مُهيّأ على الخادم (GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET).',
    );
  }

  const state = await verifyState(url.searchParams.get('state') ?? '');
  const next = state
    ? await signState(state.workspaceId, state.userId, installationId)
    : await signRecovery(installationId);

  const authorize = `${GITHUB_OAUTH}/authorize?client_id=${
    encodeURIComponent(clientId)
  }&state=${encodeURIComponent(next)}&redirect_uri=${encodeURIComponent(callbackUrl(url))}`;
  return new Response(null, { status: 302, headers: { Location: authorize } });
}

async function handleOAuthCallback(url: URL): Promise<Response> {
  const code = url.searchParams.get('code');
  if (!code) return pageResponse('لم يصل رمز التفويض من GitHub.');

  const rawState = url.searchParams.get('state') ?? '';
  const state = await verifyState(rawState);
  const recovery = state ? null : await verifyRecovery(rawState);
  if (!state && !recovery) {
    return pageResponse('انتهت صلاحية الطلب — أعد المحاولة من التطبيق.');
  }
  if (state && !state.installationId) {
    return pageResponse('انتهت صلاحية الطلب — أعد المحاولة من التطبيق.');
  }
  const installationId = state ? state.installationId : recovery!.installationId;

  const clientId = optionalEnv('GITHUB_CLIENT_ID');
  const clientSecret = optionalEnv('GITHUB_CLIENT_SECRET');
  if (!clientId || !clientSecret) {
    return pageResponse(
      'تطبيق GitHub غير مُهيّأ على الخادم (GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET).',
    );
  }

  const tokenResponse = await fetch(`${GITHUB_OAUTH}/access_token`, {
    method: 'POST',
    headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: clientId,
      client_secret: clientSecret,
      code,
      redirect_uri: callbackUrl(url),
    }),
  });
  if (!tokenResponse.ok) {
    return pageResponse(`تعذّر استبدال رمز التفويض (${tokenResponse.status}).`);
  }
  const tokenBody = (await tokenResponse.json()) as {
    access_token?: string;
    error?: string;
  };
  const userToken = tokenBody.access_token;
  if (!userToken) {
    return pageResponse(`تعذّر استبدال رمز التفويض (${tokenBody.error ?? 'no_token'}).`);
  }

  const [userResponse, installationResponse] = await Promise.all([
    fetch(`${GITHUB_API}/user`, { headers: githubHeaders(userToken) }),
    fetch(`${GITHUB_API}/app/installations/${installationId}`, {
      headers: githubHeaders(await appJwt()),
    }),
  ]);
  if (!userResponse.ok || !installationResponse.ok) {
    return pageResponse('تعذّر قراءة بيانات GitHub. أعد المحاولة.');
  }

  const user = (await userResponse.json()) as { id: number; login: string };
  const installation = (await installationResponse.json()) as Json;
  const account = (installation.account ?? {}) as {
    id?: number;
    type?: string;
    login?: string;
  };

  let workspaceId: string;
  let actorId: string;
  if (state) {
    const identity = await identityMatches(state.userId, user.id);
    if (!identity.ok) return pageResponse(identity.message);
    workspaceId = state.workspaceId;
    actorId = state.userId;
  } else {
    const resolved = await resolveWorkspaceForGithubUser(user.id);
    if (!resolved.ok) return pageResponse(resolved.message);
    workspaceId = resolved.workspaceId;
    actorId = resolved.userId;
  }

  const ownership = await checkOwnership(userToken, user, account);
  if (!ownership.ok) {
    await revokeUserToken(userToken);
    return pageResponse(ownership.message);
  }

  await db.doc(`workspaces/${workspaceId}/githubInstallations/${installationId}`).set({
    accountLogin: account.login ?? 'unknown',
    accountType: account.type ?? 'User',
    createdBy: actorId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await revokeUserToken(userToken);
  return pageResponse(
    'تم ربط تطبيق 6DX بحساب GitHub. ارجع إلى التطبيق واضغط «تحديث».',
  );
}

// --- webhook -----------------------------------------------------------------

/**
 * The signature is computed over the raw bytes exactly as GitHub sent them —
 * re-serializing the parsed body would break it — so the raw body travels all
 * the way here untouched.
 */
async function handleWebhook(
  rawBody: string,
  signature: string,
  event: string,
): Promise<{ status: number; body: Json }> {
  const secret = process.env.GITHUB_WEBHOOK_SECRET ?? '';
  if (!secret) return { status: 500, body: { error: 'webhook_not_configured' } };
  if (signature !== `sha256=${hmac(secret, rawBody)}`) {
    return { status: 401, body: { error: 'invalid_signature' } };
  }

  const payload = JSON.parse(rawBody) as Json;
  if (event !== 'pull_request') return { status: 200, body: { ignored: event } };

  const installationId = (payload.installation as Json | undefined)?.id as
    | number
    | undefined;
  const repository = (payload.repository as Json | undefined)?.full_name as
    | string
    | undefined;
  if (!installationId || !repository) return { status: 200, body: { ignored: true } };

  const installations = await db
    .collectionGroup('githubInstallations')
    .where(admin.firestore.FieldPath.documentId(), '==', String(installationId))
    .limit(1)
    .get();
  if (installations.empty) return { status: 200, body: { ignored: 'unknown_installation' } };
  const wsId = installations.docs[0].ref.parent.parent!.id;

  const pr = (payload.pull_request ?? {}) as Json;
  const number = (pr.number as number | undefined) ?? (payload.number as number | undefined) ?? 0;
  await db.doc(`workspaces/${wsId}/pullRequests/${number}`).set(
    {
      number,
      title: (pr.title as string | undefined) ?? '(untitled)',
      author: ((pr.user as Json | undefined)?.login as string | undefined) ?? null,
      branch: (((pr.head as Json | undefined)?.ref) as string | undefined) ?? '',
      baseBranch: (((pr.base as Json | undefined)?.ref) as string | undefined) ?? 'main',
      state: pr.merged ? 'merged' : ((pr.state as string | undefined) ?? 'open'),
      additions: (pr.additions as number | undefined) ?? 0,
      deletions: (pr.deletions as number | undefined) ?? 0,
      lastCommit: (((pr.head as Json | undefined)?.sha) as string | undefined) ?? null,
      repository,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { status: 200, body: { synced: number, repository } };
}

// --- router -----------------------------------------------------------------

export const githubApp = onRequest({ region: 'europe-west1', cors: true }, async (request, response) => {
  try {
    const url = new URL(
      `https://${request.headers.host ?? 'localhost'}${request.originalUrl}`,
    );

    // GitHub App webhooks are recognised by their delivery header, not only by
    // the path: a trailing slash or a stale URL in the App settings would
    // otherwise route every delivery into a browser leg.
    const isWebhook =
      url.pathname.endsWith('/webhook') ||
      request.headers['x-github-event'] !== undefined;
    if (isWebhook) {
      if (request.method !== 'POST') {
        response.status(405).json({ error: 'method_not_allowed' });
        return;
      }
      // The raw bytes must reach the HMAC untouched.
      const raw = request.rawBody?.toString('utf8') ?? '';
      const signatureHeader = request.headers['x-hub-signature-256'];
      const eventHeader = request.headers['x-github-event'];
      const result = await handleWebhook(
        raw,
        Array.isArray(signatureHeader) ? (signatureHeader[0] ?? '') : (signatureHeader ?? ''),
        Array.isArray(eventHeader) ? (eventHeader[0] ?? '') : (eventHeader ?? ''),
      );
      response.status(result.status).json(result.body);
      return;
    }

    if (request.method === 'GET') {
      const result = url.searchParams.has('code')
        ? await handleOAuthCallback(url)
        : await handleSetup(url);
      const location = result.headers.get('Location');
      if (result.status === 302 && location) {
        response.redirect(location);
        return;
      }
      response
        .status(result.status)
        .set('Content-Type', result.headers.get('Content-Type') ?? 'text/html')
        .send(await result.text());
      return;
    }

    response.status(405).json({ error: 'method_not_allowed' });
  } catch (error) {
    const detail = error instanceof Error ? error.message : 'unexpected_error';
    if (detail.startsWith('missing secret')) {
      response.status(500).json({ error: 'github_not_configured', detail });
      return;
    }
    response.status(500).json({ error: 'unexpected_error', detail });
  }
});

export { env, optionalEnv, hmac, signState, installationToken, githubHeaders };
