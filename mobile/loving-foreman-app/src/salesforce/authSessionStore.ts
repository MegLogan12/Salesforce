import * as SecureStore from 'expo-secure-store';
import type { AuthSessionState } from '@/core/types';

const AUTH_KEY = 'loving-foreman-auth-session-v1';

export async function loadStoredAuthSession(): Promise<AuthSessionState | null> {
  const raw = await SecureStore.getItemAsync(AUTH_KEY);
  return raw ? (JSON.parse(raw) as AuthSessionState) : null;
}

export async function saveStoredAuthSession(authState: AuthSessionState): Promise<void> {
  await SecureStore.setItemAsync(AUTH_KEY, JSON.stringify(authState));
}

export async function clearStoredAuthSession(): Promise<void> {
  await SecureStore.deleteItemAsync(AUTH_KEY);
}
