export interface AppEnv {
  salesforceClientId: string;
  salesforceAuthUrl: string;
  salesforceInstanceUrl: string;
  salesforceRedirectUri: string;
  wexApiBaseUrl: string;
  ripplingApiBaseUrl: string;
  weatherApiBaseUrl: string;
}

export const env: AppEnv = {
  salesforceClientId: '',
  salesforceAuthUrl: '',
  salesforceInstanceUrl: '',
  salesforceRedirectUri: '',
  wexApiBaseUrl: '',
  ripplingApiBaseUrl: '',
  weatherApiBaseUrl: ''
};
