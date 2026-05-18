// OAuth2 PKCE for browser + Capacitor.
// Mode priority: debug token → OAuth PKCE → demo (no session).
// Env vars:
//   VITE_SF_ACCESS_TOKEN + VITE_SF_INSTANCE_URL  → debug/token mode (dev only)
//   VITE_SF_CLIENT_ID + VITE_SF_INSTANCE_URL + VITE_SF_REDIRECT_URI → OAuth PKCE

export interface SalesforceSession {
  instanceUrl: string;
  accessToken: string;
  userId: string;
  orgId: string;
  username: string;
}

export type AppMode = 'loading' | 'login' | 'live' | 'demo';

const SESSION_KEY = 'loving-fm:sf-session:v1';
const PKCE_VERIFIER_KEY = 'loving-fm:pkce-verifier';

// ─── PKCE helpers ─────────────────────────────────────────────────────────────

function base64url(buf: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function generateVerifier(): string {
  const bytes = new Uint8Array(96);
  crypto.getRandomValues(bytes);
  return base64url(bytes.buffer);
}

async function generateChallenge(verifier: string): Promise<string> {
  const encoded = new TextEncoder().encode(verifier);
  const hash = await crypto.subtle.digest('SHA-256', encoded);
  return base64url(hash);
}

// ─── Session storage ──────────────────────────────────────────────────────────

export function getStoredSession(): SalesforceSession | null {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    return raw ? (JSON.parse(raw) as SalesforceSession) : null;
  } catch {
    return null;
  }
}

export function storeSession(session: SalesforceSession): void {
  localStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

export function clearSession(): void {
  localStorage.removeItem(SESSION_KEY);
  localStorage.removeItem(PKCE_VERIFIER_KEY);
}

// ─── Debug token mode ─────────────────────────────────────────────────────────

export function getDebugTokenSession(): SalesforceSession | null {
  const instanceUrl = import.meta.env.VITE_SF_INSTANCE_URL as string | undefined;
  const accessToken = import.meta.env.VITE_SF_ACCESS_TOKEN as string | undefined;
  if (!instanceUrl || !accessToken) return null;
  return {
    instanceUrl: instanceUrl.replace(/\/$/, ''),
    accessToken,
    userId: import.meta.env.VITE_SF_USER_ID as string ?? 'debug-user',
    orgId: import.meta.env.VITE_SF_ORG_ID as string ?? 'debug-org',
    username: import.meta.env.VITE_SF_USERNAME as string ?? 'debug@example.com'
  };
}

// ─── OAuth PKCE flow ──────────────────────────────────────────────────────────

export function getOAuthConfig(): { clientId: string; instanceUrl: string; redirectUri: string } | null {
  const clientId = import.meta.env.VITE_SF_CLIENT_ID as string | undefined;
  const instanceUrl = import.meta.env.VITE_SF_INSTANCE_URL as string | undefined;
  const redirectUri = import.meta.env.VITE_SF_REDIRECT_URI as string | undefined
    ?? `${window.location.origin}/oauth/callback`;
  if (!clientId || !instanceUrl) return null;
  return { clientId, instanceUrl: instanceUrl.replace(/\/$/, ''), redirectUri };
}

export async function startOAuthFlow(): Promise<void> {
  const config = getOAuthConfig();
  if (!config) throw new Error('VITE_SF_CLIENT_ID and VITE_SF_INSTANCE_URL are required for OAuth.');
  const verifier = generateVerifier();
  const challenge = await generateChallenge(verifier);
  sessionStorage.setItem(PKCE_VERIFIER_KEY, verifier);
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: config.clientId,
    redirect_uri: config.redirectUri,
    code_challenge: challenge,
    code_challenge_method: 'S256',
    scope: 'api refresh_token'
  });
  window.location.href = `${config.instanceUrl}/services/oauth2/authorize?${params}`;
}

export async function handleOAuthCallback(code: string): Promise<SalesforceSession> {
  const config = getOAuthConfig();
  if (!config) throw new Error('OAuth config missing on callback.');
  const verifier = sessionStorage.getItem(PKCE_VERIFIER_KEY);
  if (!verifier) throw new Error('PKCE verifier missing. Start the login flow again.');
  sessionStorage.removeItem(PKCE_VERIFIER_KEY);
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    client_id: config.clientId,
    redirect_uri: config.redirectUri,
    code,
    code_verifier: verifier
  });
  const response = await fetch(`${config.instanceUrl}/services/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString()
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Token exchange failed: ${response.status} ${text}`);
  }
  const token = await response.json() as {
    access_token: string; instance_url: string;
    id: string; token_type: string;
  };
  // Resolve userId and orgId from the identity URL
  const idResponse = await fetch(token.id, {
    headers: { Authorization: `Bearer ${token.access_token}` }
  });
  const identity = await idResponse.json() as {
    user_id: string; organization_id: string; preferred_username: string;
  };
  const session: SalesforceSession = {
    instanceUrl: token.instance_url.replace(/\/$/, ''),
    accessToken: token.access_token,
    userId: identity.user_id,
    orgId: identity.organization_id,
    username: identity.preferred_username
  };
  storeSession(session);
  return session;
}

// ─── Startup resolver ────────────────────────────────────────────────────────

export function resolveStartupMode(): { mode: AppMode; session: SalesforceSession | null; oauthCode: string | null } {
  // 1. OAuth callback
  const params = new URLSearchParams(window.location.search);
  const code = params.get('code');
  if (code) return { mode: 'loading', session: null, oauthCode: code };

  // 2. Debug token (dev only)
  const debug = getDebugTokenSession();
  if (debug) return { mode: 'live', session: debug, oauthCode: null };

  // 3. Stored OAuth session
  const stored = getStoredSession();
  if (stored) return { mode: 'live', session: stored, oauthCode: null };

  // 4. OAuth config exists — show login
  const config = getOAuthConfig();
  if (config) return { mode: 'login', session: null, oauthCode: null };

  // 5. No config — demo mode
  return { mode: 'demo', session: null, oauthCode: null };
}
