// 6DX — GitHub App broker.
//
// Why this exists: a GitHub App needs a private key to mint installation
// tokens, so the client can never talk to GitHub directly. This function holds
// the key, exchanges it for a short-lived installation token, and returns only
// what the UI needs. The Flutter app therefore stores no GitHub credential.
//
// Routes (all under /functions/v1/github-app):
//   POST  { action: 'installation' | 'repositories' | 'install-url' | 'disconnect' }
//   GET   ?installation_id=…&state=…   ← GitHub's post-install redirect
//   POST  /webhook                     ← GitHub App webhook (HMAC verified)
//
// Secrets (supabase secrets set …):
//   GITHUB_APP_ID          numeric App id
//   GITHUB_APP_SLUG        the App slug used in the install URL
//   GITHUB_PRIVATE_KEY     the App private key (PEM, \n escaped)
//   GITHUB_WEBHOOK_SECRET  webhook signing secret (also signs the OAuth state)
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are injected by
// the platform.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { SignJWT, importPKCS8 } from 'https://esm.sh/jose@5';

const GITHUB_API = 'https://api.github.com';

type Json = Record<string, unknown>;

const encoder = new TextEncoder();

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing secret: ${name}`);
  return value;
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

type WorkspaceResult =
  | { workspaceId: string }
  | { error: string; status: number };

/** The workspace the caller may use: admin for writes, member for reads. */
async function resolveWorkspace(
  client: any,
  userId: string,
  workspaceId: string | null,
  requireAdmin: boolean,
): Promise<WorkspaceResult> {
  const checkAdmin = async (id: string) => {
    const result = await client.rpc('is_workspace_admin', { target: id });
    return !result.error && result.data === true;
  };

  if (workspaceId) {
    const member = await client.rpc('is_workspace_member', { target: workspaceId });
    if (member.error || member.data !== true) {
      return { error: 'not_workspace_member', status: 403 };
    }
    if (requireAdmin && !(await checkAdmin(workspaceId))) {
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
  const jwt = await appJwt();
  const response = await fetch(
    `${GITHUB_API}/app/installations/${installationId}/access_tokens`,
    { method: 'POST', headers: githubHeaders(jwt) },
  );
  if (!response.ok) throw new Error(`installation token ${response.status}`);
  const body = await response.json();
  return body.token as string;
}

// --- state signing (install redirect) -------------------------------------

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

async function signState(workspaceId: string, userId: string): Promise<string> {
  const payload = `${workspaceId}.${userId}.${Date.now()}`;
  return `${payload}.${await hmac(stateSecret(), payload)}`;
}

async function verifyState(
  state: string,
): Promise<{ workspaceId: string; userId: string; issuedAt: number } | null> {
  const parts = state.split('.');
  if (parts.length !== 4) return null;
  const [workspaceId, userId, issuedAt, signature] = parts;
  const expected = await hmac(stateSecret(), `${workspaceId}.${userId}.${issuedAt}`);
  if (expected.length !== signature.length) return null;

  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  if (diff !== 0) return null;

  // The link is only valid for 30 minutes.
  const issued = Number(issuedAt);
  const age = Date.now() - issued;
  if (!Number.isFinite(age) || age < 0 || age > 30 * 60 * 1000) return null;

  return { workspaceId, userId, issuedAt: issued };
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

      const slug = env('GITHUB_APP_SLUG');
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

/** GitHub redirects the browser here right after the App is installed. */
async function handleCallback(url: URL): Promise<Response> {
  const installationId = Number(url.searchParams.get('installation_id') ?? '0');
  if (!installationId) return htmlPage('لم يصل معرّف التثبيت من GitHub.');

  const verified = await verifyState(url.searchParams.get('state') ?? '');
  if (!verified) return htmlPage('انتهت صلاحية الطلب — أعد المحاولة من التطبيق.');

  const response = await fetch(
    `${GITHUB_API}/app/installations/${installationId}`,
    { headers: githubHeaders(await appJwt()) },
  );
  if (!response.ok) {
    return htmlPage(`تعذّر قراءة التثبيت من GitHub (${response.status}).`);
  }
  const installation = await response.json();

  // `installation_id` is user-controllable (GitHub's own warning), so only accept
  // an installation created *by this very install flow*: it has to be newer than
  // the signed state. That makes it impossible to attach somebody else's older
  // installation — and therefore their repositories — to your workspace.
  const setupAction = url.searchParams.get('setup_action') ?? 'install';
  if (setupAction !== 'update') {
    const createdAt = Date.parse(installation.created_at ?? '');
    const skew = 5 * 60 * 1000;
    if (!Number.isFinite(createdAt) || createdAt < verified.issuedAt - skew) {
      return htmlPage(
        'هذا التثبيت قديم ولم يبدأ من التطبيق — ابدأ التثبيت من شاشة ربط المستودع.',
      );
    }
  }

  const account = installation.account ?? {};

  const { error } = await serviceClient().from('github_installations').upsert(
    {
      workspace_id: verified.workspaceId,
      installation_id: installationId,
      account_login: account.login ?? 'unknown',
      account_type: account.type ?? 'User',
      created_by: verified.userId,
    },
    { onConflict: 'workspace_id,installation_id' },
  );
  if (error) return htmlPage('تعذّر حفظ التثبيت في قاعدة البيانات.');

  return htmlPage(
    'تم ربط تطبيق 6DX بحساب GitHub. ارجع إلى التطبيق واضغط «تحديث».',
  );
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
  const projectName = payload.repository?.full_name as string | undefined;
  if (!installationId || !projectName) return json({ ignored: true });

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

  return json({ synced: pr.number ?? null, repository: projectName });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);

  try {
    if (url.pathname.endsWith('/webhook')) {
      if (req.method !== 'POST') return fail('method_not_allowed', 405);
      return await handleWebhook(req);
    }
    if (req.method === 'GET') return await handleCallback(url);
    if (req.method === 'POST') return await handleAction(req);
    return fail('method_not_allowed', 405);
  } catch (error) {
    const detail = error instanceof Error ? error.message : 'unexpected_error';
    // A missing App secret is a deployment problem, not a user error.
    if (detail.startsWith('missing secret')) {
      return fail('github_not_configured', 500, { detail });
    }
    return fail('unexpected_error', 500, { detail });
  }
});
