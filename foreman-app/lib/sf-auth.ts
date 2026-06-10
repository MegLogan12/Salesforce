/**
 * Salesforce OAuth 2.0 + PKCE auth for LOVING Field app.
 *
 * Setup required in Salesforce:
 * 1. Setup → App Manager → New Connected App
 *    - Enable OAuth, add scopes: api, refresh_token, offline_access
 *    - Set Callback URL: lovingfield://oauth/callback
 *    - Enable PKCE
 *    - Copy Consumer Key → SF_CLIENT_ID below
 */

import * as AuthSession from 'expo-auth-session';
import * as SecureStore from 'expo-secure-store';
import * as WebBrowser from 'expo-web-browser';

WebBrowser.maybeCompleteAuthSession();

const SF_INSTANCE   = process.env.EXPO_PUBLIC_SF_INSTANCE ?? 'https://thelovingcompanies.my.salesforce.com';
const SF_CLIENT_ID  = process.env.EXPO_PUBLIC_SF_CLIENT_ID ?? 'YOUR_CONNECTED_APP_CLIENT_ID';
const REDIRECT_URI  = AuthSession.makeRedirectUri({ scheme: 'lovingfield', path: 'oauth/callback' });

const KEYS = { accessToken: 'sf_access_token', refreshToken: 'sf_refresh_token', instanceUrl: 'sf_instance_url', userId: 'sf_user_id' };

export interface SfSession {
  accessToken: string;
  refreshToken: string;
  instanceUrl: string;
  userId: string;
}

/** Start OAuth PKCE flow — opens Salesforce login in browser */
export async function sfLogin(): Promise<SfSession | null> {
  const discovery = {
    authorizationEndpoint: `${SF_INSTANCE}/services/oauth2/authorize`,
    tokenEndpoint: `${SF_INSTANCE}/services/oauth2/token`,
    revocationEndpoint: `${SF_INSTANCE}/services/oauth2/revoke`,
  };

  const request = new AuthSession.AuthRequest({
    clientId: SF_CLIENT_ID,
    redirectUri: REDIRECT_URI,
    scopes: ['api', 'refresh_token', 'offline_access'],
    usePKCE: true,
    responseType: AuthSession.ResponseType.Code,
  });

  const result = await request.promptAsync(discovery);

  if (result.type !== 'success' || !result.params.code) return null;

  const tokenRes = await fetch(`${SF_INSTANCE}/services/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: SF_CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      code: result.params.code,
      code_verifier: request.codeVerifier ?? '',
    }).toString(),
  });

  if (!tokenRes.ok) return null;

  const data = await tokenRes.json();
  const session: SfSession = {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    instanceUrl: data.instance_url ?? SF_INSTANCE,
    userId: data.id?.split('/').pop() ?? '',
  };

  await saveSession(session);
  return session;
}

/** Refresh access token using stored refresh token */
export async function sfRefreshSession(): Promise<SfSession | null> {
  const stored = await loadSession();
  if (!stored?.refreshToken) return null;

  const res = await fetch(`${stored.instanceUrl}/services/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      client_id: SF_CLIENT_ID,
      refresh_token: stored.refreshToken,
    }).toString(),
  });

  if (!res.ok) return null;

  const data = await res.json();
  const session: SfSession = { ...stored, accessToken: data.access_token };
  await saveSession(session);
  return session;
}

export async function sfLogout(): Promise<void> {
  const stored = await loadSession();
  if (stored) {
    await fetch(`${stored.instanceUrl}/services/oauth2/revoke`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ token: stored.accessToken }).toString(),
    }).catch(() => {});
  }
  await Promise.all(Object.values(KEYS).map(k => SecureStore.deleteItemAsync(k)));
}

export async function loadSession(): Promise<SfSession | null> {
  const [accessToken, refreshToken, instanceUrl, userId] = await Promise.all([
    SecureStore.getItemAsync(KEYS.accessToken),
    SecureStore.getItemAsync(KEYS.refreshToken),
    SecureStore.getItemAsync(KEYS.instanceUrl),
    SecureStore.getItemAsync(KEYS.userId),
  ]);
  if (!accessToken || !refreshToken || !instanceUrl || !userId) return null;
  return { accessToken, refreshToken, instanceUrl, userId };
}

async function saveSession(s: SfSession) {
  await Promise.all([
    SecureStore.setItemAsync(KEYS.accessToken, s.accessToken),
    SecureStore.setItemAsync(KEYS.refreshToken, s.refreshToken),
    SecureStore.setItemAsync(KEYS.instanceUrl, s.instanceUrl),
    SecureStore.setItemAsync(KEYS.userId, s.userId),
  ]);
}
