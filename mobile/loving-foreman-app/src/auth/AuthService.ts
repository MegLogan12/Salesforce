import type { AuthenticatedUser, SalesforceAuthTokens } from '@/auth/types';

export interface AuthService {
  signIn(): Promise<{ tokens: SalesforceAuthTokens; user: AuthenticatedUser }>;
  refresh(refreshToken: string): Promise<SalesforceAuthTokens>;
  signOut(): Promise<void>;
}
