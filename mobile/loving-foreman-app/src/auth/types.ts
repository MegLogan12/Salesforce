export interface SalesforceAuthTokens {
  accessToken: string;
  refreshToken: string;
  instanceUrl: string;
  issuedAt: string;
}

export interface AuthenticatedUser {
  userId: string;
  username: string;
  orgId: string;
}
