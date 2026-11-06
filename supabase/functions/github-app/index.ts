// 6DX — GitHub App broker.
//
// A GitHub App needs a private key to mint installation tokens, so the client
// can never talk to GitHub directly: this function holds the key and returns
// only what the UI needs. The Flutter app stores no GitHub credential.
//
// Install flow (three legs, all browser-visible):
//
//   1. app  → POST { action: 'install-url' }  → signed state → GitHub install page
//   2. GitHub → GET /github-app?installation_id=…&state=…      (the Setup URL)
//              verifies the state, then 302 to
//              github.com/login/oauth/authorize?client_id=…&state=<state+installation>
//   3. GitHub → GET /github-app?code=…&state=…                 (the OAuth callback)
//              exchanges the code for a USER token, proves the installation
//              belongs to that user, then stores it.
//
// Step 2 does not save anything: `installation_id` in that redirect is
// user-controllable (GitHub says so explicitly), so ownership is only recorded
// after step 3 proves it with a user token.
//
// Routes (all under /functions/v1/github-app):
//   POST  { action: 'installation' | 'repositories' | 'install-url' | 'disconnect' }
//   GET   ?installation_id=…&state=…   ← Setup URL
//   GET   ?code=…&state=…              ← OAuth callback
//   POST  /webhook                     ← GitHub webhook (HMAC verified)
//
// Secrets (supabase secrets set …):
//   GITHUB_APP_ID           numeric App id (not the OAuth client id)
//   GITHUB_APP_SLUG         slug used in the install URL
//   GITHUB_PRIVATE_KEY      App private key (PEM, \n escaped)
//   GITHUB_CLIENT_ID        App OAuth client id
//   GITHUB_CLIENT_SECRET    App OAuth client secret
//   GITHUB_WEBHOOK_SECRET   webhook secret; also signs the OAuth state
//
// Nothing here falls back to a weaker check: if the OAuth credentials are
// missing the install is refused (fail closed).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5';

const GITHUB_API = 'https://api.github.com';
const GITHUB_OAUTH = 'https://github.com/login/oauth';
const STATE_TTL_MS = 30 * 60 * 1000;

type Json = Record<string, unknown>;

const encoder = new TextEncoder();

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing secret: ${name}`);
  return value;
}

function optionalEnv(name: string): string | null {
  const value = Deno.env.get(name);
  return value && value.length > 0 ? value : null;
}

function json(body: Json, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function fail(error: string, status = 400, extra: Json = {}): Response {
  return json({ error, ...extra }, status);
}

/** The App's registered user-authorization callback URL. */
function callbackUrl(): string {
  const base = Deno.env.get('SUPABASE_URL') ?? '';
  return `${base.replace(/\/$/, '')}/functions/v1/github-app`;
}

// --- supabase helpers ------------------------------------------------------

function serviceClient() {
  return createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false },
  });
}

/** Resolves the caller from the Supabase access token of the request. */
async function caller(req: Request) {
  const header = req.headers.get('Authorization') ?? '';
  const token = header.replace(/^Bearer\s+/i, '');
  if (!token) return null;

  const client = createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;
  return { client, userId: data.user.id };
}

type WorkspaceResult = { workspaceId: string } | { error: string; status: number };

async function resolveWorkspace(
  client: any,
  userId: string,
  workspaceId: string | null,
  requireAdmin: boolean,
): Promise<WorkspaceResult> {
  const isAdmin = async (id: string) => {
    const result = await client.rpc('is_workspace_admin', { target: id });
    return !result.error && result.data === true;
  };

  if (workspaceId) {
    const member = await client.rpc('is_workspace_member', { target: workspaceId });
    if (member.error || member.data !== true) {
      return { error: 'not_workspace_member', status: 403 };
    }
    if (requireAdmin && !(await isAdmin(workspaceId))) {
      return { error: 'not_workspace_admin', status: 403 };
    }
    return { workspaceId };
  }

  const { data, error } = await client
    .from('workspace_members')
    .select('workspace_id, role')
    .eq('user_id', userId)
    .order('created_at')
    .limit(1);
  if (error) return { error: 'workspace_lookup_failed', status: 500 };
  if (!data?.length) return { error: 'no_workspace', status: 409 };

  const row = data[0];
  if (requireAdmin && !['owner', 'admin'].includes(row.role)) {
    return { error: 'not_workspace_admin', status: 403 };
  }
  return { workspaceId: row.workspace_id };
}

// --- GitHub App authentication --------------------------------------------

let appKey: CryptoKey | null = null;
let appJwtCache: { token: string; expiresAt: number } | null = null;

async function appJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (appJwtCache && appJwtCache.expiresAt - 30 > now) return appJwtCache.token;

  if (!appKey) {
    const pem = env('GITHUB_PRIVATE_KEY').replace(/\\n/g, '\n');
    appKey = await importPKCS8(pem, 'RS256');
  }

  const token = await new SignJWT({})
    .setProtectedHeader({ alg: 'RS256' })
    .setIssuedAt(now - 60)
    .setExpirationTime(now + 540) // GitHub allows 10 minutes at most
    .setIssuer(env('GITHUB_APP_ID'))
    .sign(appKey);

  appJwtCache = { token, expiresAt: now + 540 };
  return token;
}

function githubHeaders(token: string): Record<string, string> {
  return {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
}

async function installationToken(installationId: number): Promise<string> {
  const response = await fetch(
    `${GITHUB_API}/app/installations/${installationId}/access_tokens`,
    { method: 'POST', headers: githubHeaders(await appJwt()) },
  );
  if (!response.ok) throw new Error(`installation token ${response.status}`);
  const body = await response.json();
  return body.token as string;
}

// --- signed state ----------------------------------------------------------
//
// `v1.<workspaceId>.<userId>.<installationId|0>.<issuedAtMs>.<hmac>`

async function hmac(secret: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const digest = await crypto.subtle.sign('HMAC', key, encoder.encode(value));
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function stateSecret(): string {
  return Deno.env.get('STATE_SECRET') ?? env('GITHUB_WEBHOOK_SECRET');
}

async function signState(
  workspaceId: string,
  userId: string,
  installationId = 0,
): Promise<string> {
  const payload = `v1.${workspaceId}.${userId}.${installationId}.${Date.now()}`;
  return `${payload}.${await hmac(stateSecret(), payload)}`;
}

type StatePayload = {
  workspaceId: string;
  userId: string;
  installationId: number;
  issuedAt: number;
};

function sameSignature(expected: string, actual: string): boolean {
  if (expected.length !== actual.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ actual.charCodeAt(i);
  }
  return diff === 0;
}

function freshEnough(issuedAt: string): boolean {
  const age = Date.now() - Number(issuedAt);
  return Number.isFinite(age) && age >= 0 && age <= STATE_TTL_MS;
}

async function verifyState(state: string): Promise<StatePayload | null> {
  const parts = state.split('.');
  if (parts.length !== 6 || parts[0] !== 'v1') return null;

  const [, workspaceId, userId, installationId, issuedAt, signature] = parts;
  const payload = `v1.${workspaceId}.${userId}.${installationId}.${issuedAt}`;
  if (!sameSignature(await hmac(stateSecret(), payload), signature)) return null;
  if (!freshEnough(issuedAt)) return null;

  return { workspaceId, userId, installationId: Number(installationId) || 0, issuedAt: Number(issuedAt) };
}

/**
 * GitHub documents only `installation_id` and `setup_action` on the setup URL,
 * not `state`: the signed state can legitimately go missing between the install
 * page and our handler. Rather than dead-end the install, fall back to a token
 * that names the installation alone — the workspace is then derived from the
 * authenticated GitHub identity, which is no weaker: a victim's installation
 * lands in the victim's own workspace, never in the sender's.
 */
async function signRecovery(installationId: number): Promise<string> {
  const payload = `r1.${installationId}.${Date.now()}`;
  return `${payload}.${await hmac(stateSecret(), payload)}`;
}

async function verifyRecovery(state: string): Promise<{ installationId: number } | null> {
  const parts = state.split('.');
  if (parts.length !== 4 || parts[0] !== 'r1') return null;

  const [, installationId, issuedAt, signature] = parts;
  const payload = `r1.${installationId}.${issuedAt}`;
  if (!sameSignature(await hmac(stateSecret(), payload), signature)) return null;
  if (!freshEnough(issuedAt)) return null;

  const id = Number(installationId) || 0;
  return id ? { installationId: id } : null;
}

// --- handlers --------------------------------------------------------------

async function handleAction(req: Request): Promise<Response> {
  const session = await caller(req);
  if (!session) return fail('unauthenticated', 401);

  let body: Json = {};
  try {
    body = (await req.json()) as Json;
  } catch {
    return fail('invalid_body', 400);
  }

  const action = String(body.action ?? '');
  const requested = body.workspace_id ? String(body.workspace_id) : null;

  switch (action) {
    case 'installation':
    case 'repositories': {
      const resolved = await resolveWorkspace(
        session.client,
        session.userId,
        requested,
        false,
      );
      if ('error' in resolved) return fail(resolved.error, resolved.status);

      const db = serviceClient();
      const { data, error } = await db
        .from('github_installations')
        .select('installation_id, account_login, account_type')
        .eq('workspace_id', resolved.workspaceId)
        .order('created_at')
        .limit(1);
      if (error) return fail('installation_lookup_failed', 500);

      const installation = data?.[0] ?? null;
      if (action === 'installation') return json({ installation });
      if (!installation) return fail('no_installation', 409);

      const token = await installationToken(installation.installation_id);
      const response = await fetch(
        `${GITHUB_API}/installation/repositories?per_page=100`,
        { headers: githubHeaders(token) },
      );
      if (!response.ok) return fail(`github_error_${response.status}`, 502);

      const payload = await response.json();
      return json({
        total_count: payload.total_count ?? 0,
        repositories: payload.repositories ?? [],
      });
    }

    case 'install-url': {
      const resolved = await resolveWorkspace(
        session.client,
        session.userId,
        requested,
        true,
      );
      if ('error' in resolved) return fail(resolved.error, resolved.status);

      const slug = optionalEnv('GITHUB_APP_SLUG');
      if (!slug) return fail('github_not_configured', 500, { detail: 'GITHUB_APP_SLUG' });

      const state = await signState(resolved.workspaceId, session.userId);
      return json({
        url: `https://github.com/apps/${slug}/installations/new?state=${
          encodeURIComponent(state)
        }`,
      });
    }

    case 'disconnect': {
      const resolved = await resolveWorkspace(
        session.client,
        session.userId,
        requested,
        true,
      );
      if ('error' in resolved) return fail(resolved.error, resolved.status);

      const { error } = await serviceClient()
        .from('github_installations')
        .delete()
        .eq('workspace_id', resolved.workspaceId);
      if (error) return fail('disconnect_failed', 500);
      return json({ ok: true });
    }

    default:
      return fail('unknown_action', 400);
  }
}

/**
 * Leg 2 — GitHub's Setup URL. Nothing is stored yet: the `installation_id` here
 * is user-controllable, so the browser is sent through the App's own OAuth
 * authorize step to obtain a user token that can prove ownership (leg 3).
 */
async function handleSetup(url: URL): Promise<Response> {
  const installationId = Number(url.searchParams.get('installation_id') ?? '0');
  if (!installationId) return htmlPage('لم يصل معرّف التثبيت من GitHub.');

  // Fail closed: without these the ownership check of leg 3 cannot run, and a
  // weaker check is what we are trying to avoid.
  const clientId = optionalEnv('GITHUB_CLIENT_ID');
  const clientSecret = optionalEnv('GITHUB_CLIENT_SECRET');
  if (!clientId || !clientSecret) {
    return htmlPage(
      'تطبيق GitHub غير مُهيّأ على الخادم (GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET).',
    );
  }

  // A missing state is not fatal: GitHub does not promise to echo it back to
  // the setup URL, so the installation alone is signed and the workspace is
  // resolved from the identity in leg 3.
  const state = await verifyState(url.searchParams.get('state') ?? '');
  const next = state
    ? await signState(state.workspaceId, state.userId, installationId)
    : await signRecovery(installationId);

  const authorize = `${GITHUB_OAUTH}/authorize?client_id=${
    encodeURIComponent(clientId)
  }&state=${encodeURIComponent(next)}&redirect_uri=${encodeURIComponent(callbackUrl())}`;

  return new Response(null, { status: 302, headers: { Location: authorize } });
}

/**
 * Leg 3 — OAuth callback. Exchanges the code for a user token and proves the
 * installation belongs to that user before anything is stored.
 */
async function handleOAuthCallback(url: URL): Promise<Response> {
  const code = url.searchParams.get('code');
  if (!code) return htmlPage('لم يصل رمز التفويض من GitHub.');

  const rawState = url.searchParams.get('state') ?? '';
  const state = await verifyState(rawState);
  const recovery = state ? null : await verifyRecovery(rawState);
  if (!state && !recovery) {
    return htmlPage('انتهت صلاحية الطلب — أعد المحاولة من التطبيق.');
  }
  if (state && !state.installationId) {
    return htmlPage('انتهت صلاحية الطلب — أعد المحاولة من التطبيق.');
  }
  const installationId = state ? state.installationId : recovery!.installationId;

  const clientId = optionalEnv('GITHUB_CLIENT_ID');
  const clientSecret = optionalEnv('GITHUB_CLIENT_SECRET');
  if (!clientId || !clientSecret) {
    return htmlPage(
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
      redirect_uri: callbackUrl(),
    }),
  });
  if (!tokenResponse.ok) {
    return htmlPage(`تعذّر استبدال رمز التفويض (${tokenResponse.status}).`);
  }
  const tokenBody = await tokenResponse.json();
  const userToken = tokenBody.access_token as string | undefined;
  if (!userToken) {
    return htmlPage(`تعذّر استبدال رمز التفويض (${tokenBody.error ?? 'no_token'}).`);
  }

  const [userResponse, installationResponse] = await Promise.all([
    fetch(`${GITHUB_API}/user`, { headers: githubHeaders(userToken) }),
    fetch(`${GITHUB_API}/app/installations/${installationId}`, {
      headers: githubHeaders(await appJwt()),
    }),
  ]);
  if (!userResponse.ok || !installationResponse.ok) {
    return htmlPage('تعذّر قراءة بيانات GitHub. أعد المحاولة.');
  }

  const user = await userResponse.json();
  const installation = await installationResponse.json();
  const account = installation.account ?? {};

  // Anti-CSRF: the browser might not be the person who started the flow. With a
  // signed state that user is named explicitly; on the recovery path the
  // workspace is derived from the GitHub identity instead, so a crafted install
  // link can only ever attach an installation to the installer's own workspace.
  let workspaceId: string;
  let actorId: string;
  if (state) {
    const identity = await identityMatches(state.userId, user.id);
    if (!identity.ok) return htmlPage(identity.message);
    workspaceId = state.workspaceId;
    actorId = state.userId;
  } else {
    const resolved = await resolveWorkspaceForGithubUser(user.id);
    if (!resolved.ok) return htmlPage(resolved.message);
    workspaceId = resolved.workspaceId;
    actorId = resolved.userId;
  }

  const ownership = await checkOwnership(userToken, user, account);
  if (!ownership.ok) {
    await revokeUserToken(userToken);
    return htmlPage(ownership.message);
  }

  const { error } = await serviceClient().from('github_installations').upsert(
    {
      workspace_id: workspaceId,
      installation_id: installationId,
      account_login: account.login ?? 'unknown',
      account_type: account.type ?? 'User',
      created_by: actorId,
    },
    { onConflict: 'workspace_id,installation_id' },
  );
  if (error) return htmlPage('تعذّر حفظ التثبيت في قاعدة البيانات.');

  // The user token was only needed to prove ownership; drop it.
  await revokeUserToken(userToken);

  return htmlPage(
    'تم ربط تطبيق 6DX بحساب GitHub. ارجع إلى التطبيق واضغط «تحديث».',
  );
}

/**
 * The signed state names a 6DX user; the OAuth token names a GitHub user. Only
 * the same person may finish the flow, otherwise a crafted install link could
 * attach a victim's installation to the attacker's workspace.
 */
async function identityMatches(
  supabaseUserId: string,
  githubUserId: number | undefined,
): Promise<{ ok: boolean; message: string }> {
  if (!githubUserId) {
    return { ok: false, message: 'تعذّر قراءة حساب GitHub.' };
  }

  const { data, error } = await serviceClient()
    .schema('auth')
    .from('identities')
    .select('provider_id')
    .eq('user_id', supabaseUserId)
    .eq('provider', 'github')
    .limit(1);

  if (error) {
    console.error('github-app: identity lookup failed', error.message);
    return { ok: false, message: 'تعذّر التحقق من هوية المستخدم.' };
  }
  const providerId = data?.[0]?.provider_id as string | undefined;
  if (!providerId) {
    return {
      ok: false,
      message:
        'حساب 6DX ده مش مربوط بـ GitHub. اربط حساب GitHub من إعدادات الحساب ' +
        'ثم أعد التثبيت من التطبيق.',
    };
  }
  if (providerId !== String(githubUserId)) {
    return {
      ok: false,
      message:
        'الحساب اللي في المتصفح مختلف عن الحساب اللي سجّلت بيه في 6DX. ' +
        'افتح رابط التثبيت من جديد بعد تسجيل الدخول بنفس الحساب.',
    };
  }
  return { ok: true, message: '' };
}

/**
 * Recovery path: the setup URL arrived without a usable state, so the workspace
 * has to come from the person rather than from a token. Only an unambiguous
 * membership is accepted — anything else is sent back to the app, which is the
 * only place where the user can say which workspace they meant.
 */
async function resolveWorkspaceForGithubUser(
  githubUserId: number | undefined,
): Promise<{ ok: true; userId: string; workspaceId: string } | { ok: false; message: string }> {
  if (!githubUserId) return { ok: false, message: 'تعذّر قراءة حساب GitHub.' };

  const db = serviceClient();
  const { data: identities, error } = await db
    .schema('auth')
    .from('identities')
    .select('user_id')
    .eq('provider', 'github')
    .eq('provider_id', String(githubUserId))
    .limit(1);

  if (error) {
    console.error('github-app: identity lookup failed', error.message);
    return { ok: false, message: 'تعذّر التحقق من هوية المستخدم.' };
  }
  const userId = identities?.[0]?.user_id as string | undefined;
  if (!userId) {
    return {
      ok: false,
      message:
        'حساب GitHub ده مش مربوط بأي حساب 6DX. سجّل الدخول بـ GitHub في التطبيق ' +
        'ثم ابدأ التثبيت من هناك.',
    };
  }

  const { data: owned } = await db
    .from('workspace_members')
    .select('workspace_id')
    .eq('user_id', userId)
    .eq('role', 'owner')
    .limit(2);
  if (owned?.length === 1) {
    return { ok: true, userId, workspaceId: owned[0].workspace_id as string };
  }
  if (owned && owned.length > 1) {
    return {
      ok: false,
      message:
        'عندك أكتر من مساحة عمل تملكها. ابدأ التثبيت من داخل التطبيق عشان نعرف ' +
        'نربطه بأنهي مساحة.',
    };
  }

  const { data: member } = await db
    .from('workspace_members')
    .select('workspace_id')
    .eq('user_id', userId)
    .limit(2);
  if (member?.length === 1) {
    return { ok: true, userId, workspaceId: member[0].workspace_id as string };
  }
  return {
    ok: false,
    message: 'مش لاقي مساحة عمل واحدة للحساب ده. ابدأ التثبيت من داخل التطبيق.',
  };
}

/** Best effort: the user token is not needed once ownership is proven. */
async function revokeUserToken(userToken: string): Promise<void> {
  const clientId = optionalEnv('GITHUB_CLIENT_ID');
  const clientSecret = optionalEnv('GITHUB_CLIENT_SECRET');
  if (!clientId || !clientSecret) return;
  try {
    await fetch(`${GITHUB_API}/applications/${clientId}/token`, {
      method: 'DELETE',
      headers: {
        Authorization: `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
        Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ access_token: userToken }),
    });
  } catch (error) {
    console.warn('github-app: token revocation failed', String(error));
  }
}

type OwnershipVerdict = { ok: boolean; message: string };

/**
 * `/user/installations` alone is not enough: it also lists installations the
 * user can reach through an organization membership, which would let a plain
 * member attach the whole org installation (and its full token) to their own
 * workspace. So the person must own the account, or administer the org.
 */
async function checkOwnership(
  userToken: string,
  user: { id?: number; login?: string },
  account: { id?: number; login?: string; type?: string },
): Promise<OwnershipVerdict> {
  if ((account.type ?? 'User') === 'User') {
    return account.id === user.id
      ? { ok: true, message: '' }
      : {
          ok: false,
          message:
            'التثبيت ده على حساب GitHub تاني. سجّل الدخول بنفس الحساب اللي ثبّت عليه التطبيق.',
        };
  }

  const membershipResponse = await fetch(
    `${GITHUB_API}/user/memberships/orgs/${account.login}`,
    { headers: githubHeaders(userToken) },
  );
  if (!membershipResponse.ok) {
    return {
      ok: false,
      message: 'تعذّر التحقق من عضويتك في المؤسسة على GitHub.',
    };
  }
  const membership = await membershipResponse.json();
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

function htmlPage(message: string): Response {
  return new Response(
    `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>6DX</title>
<style>body{font-family:system-ui,sans-serif;background:#0F1115;color:#E8EAF0;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
div{max-width:420px;padding:28px;border-radius:16px;background:#171A21;
border:1px solid #2A2F3A;text-align:center;line-height:1.7}</style></head>
<body><div>${message}</div></body></html>`,
    { headers: { 'Content-Type': 'text/html; charset=utf-8' } },
  );
}

/** Verifies `x-hub-signature-256` and syncs pull request state. */
async function handleWebhook(req: Request): Promise<Response> {
  const raw = await req.text();
  const signature = req.headers.get('x-hub-signature-256') ?? '';
  const secret = Deno.env.get('GITHUB_WEBHOOK_SECRET') ?? '';
  if (!secret) return fail('webhook_not_configured', 500);
  if (signature !== `sha256=${await hmac(secret, raw)}`) {
    return fail('invalid_signature', 401);
  }

  const event = req.headers.get('x-github-event') ?? '';
  const payload = JSON.parse(raw);
  if (event !== 'pull_request') return json({ ignored: event });

  const installationId = payload.installation?.id as number | undefined;
  const repository = payload.repository?.full_name as string | undefined;
  if (!installationId || !repository) return json({ ignored: true });

  const db = serviceClient();
  const { data: installations } = await db
    .from('github_installations')
    .select('workspace_id')
    .eq('installation_id', installationId);
  if (!installations?.length) return json({ ignored: 'unknown_installation' });

  const pr = payload.pull_request ?? {};
  const { error } = await db.from('pull_requests').upsert(
    {
      workspace_id: installations[0].workspace_id,
      number: pr.number ?? payload.number ?? 0,
      title: pr.title ?? '(untitled)',
      author: pr.user?.login ?? null,
      branch: pr.head?.ref ?? '',
      base_branch: pr.base?.ref ?? 'main',
      state: pr.merged ? 'merged' : (pr.state ?? 'open'),
      additions: pr.additions ?? 0,
      deletions: pr.deletions ?? 0,
      last_commit: pr.head?.sha ?? null,
    },
    { onConflict: 'workspace_id,number' },
  );
  if (error) return fail('sync_failed', 500);

  return json({ synced: pr.number ?? null, repository });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);

  try {
    // GitHub App webhooks are recognised by their delivery headers, not only by
    // the path: a trailing slash or a stale `/github-app/` URL in the App
    // settings would otherwise route every delivery into the action handler and
    // answer `unauthenticated`.
    const isWebhook =
      url.pathname.endsWith('/webhook') || req.headers.has('x-github-event');
    if (isWebhook) {
      if (req.method !== 'POST') return fail('method_not_allowed', 405);
      return await handleWebhook(req);
    }
    if (req.method === 'GET') {
      return url.searchParams.has('code')
        ? await handleOAuthCallback(url)
        : await handleSetup(url);
    }
    if (req.method === 'POST') return await handleAction(req);
    return fail('method_not_allowed', 405);
  } catch (error) {
    const detail = error instanceof Error ? error.message : 'unexpected_error';
    if (detail.startsWith('missing secret')) {
      return fail('github_not_configured', 500, { detail });
    }
    return fail('unexpected_error', 500, { detail });
  }
});
