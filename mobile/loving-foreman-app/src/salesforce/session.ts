import * as AuthSession from 'expo-auth-session';
import * as Linking from 'expo-linking';
import type { AuthSessionState } from '@/core/types';

const nativeRedirectUri = process.env.EXPO_PUBLIC_SF_REDIRECT_URI ?? 'lovingforeman://oauth/callback';
const redirectUri = AuthSession.makeRedirectUri({
  native: nativeRedirectUri,
  scheme: 'lovingforeman',
  path: 'oauth/callback'
});

export function getAuthSessionState(): AuthSessionState {
  const instanceUrl = process.env.EXPO_PUBLIC_SF_INSTANCE_URL;
  const accessToken = process.env.EXPO_PUBLIC_SF_ACCESS_TOKEN;
  const username = process.env.EXPO_PUBLIC_SF_USERNAME;
  const userId = process.env.EXPO_PUBLIC_SF_USER_ID;
  const orgId = process.env.EXPO_PUBLIC_SF_ORG_ID;

  if (instanceUrl && accessToken) {
    return {
      mode: 'debugToken',
      instanceUrl,
      accessToken,
      username,
      userId,
      orgId
    };
  }

  const clientId = process.env.EXPO_PUBLIC_SF_CLIENT_ID;
  const authUrl = process.env.EXPO_PUBLIC_SF_AUTH_URL;
  if (clientId && authUrl && redirectUri) {
    return {
      mode: 'oauth',
      instanceUrl: process.env.EXPO_PUBLIC_SF_INSTANCE_URL,
      blocker: undefined
    };
  }

  return {
    mode: 'blocked',
    blocker:
      'Connected App LOVING_Operations_iOS exists in Salesforce, but local mobile OAuth is not configured. Missing EXPO_PUBLIC_SF_CLIENT_ID and/or EXPO_PUBLIC_SF_AUTH_URL.'
  };
}

export function getOAuthConfig() {
  const authUrl = process.env.EXPO_PUBLIC_SF_AUTH_URL ?? '';
  const tokenUrl = process.env.EXPO_PUBLIC_SF_TOKEN_URL
    ?? (authUrl ? authUrl.replace(/\/authorize$/, '/token') : '');

  return {
    clientId: process.env.EXPO_PUBLIC_SF_CLIENT_ID ?? '',
    authUrl,
    tokenUrl,
    redirectUri,
    responseType: AuthSession.ResponseType.Code,
    scopes: ['api', 'refresh_token', 'full']
  };
}

export function getOAuthDiscovery() {
  const config = getOAuthConfig();
  return {
    authorizationEndpoint: config.authUrl,
    tokenEndpoint: config.tokenUrl
  };
}

export const authRedirectUri = redirectUri;
export const appSchemeUrl = Linking.createURL('/');
