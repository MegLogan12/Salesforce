/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SF_INSTANCE_URL?: string;
  readonly VITE_SF_ACCESS_TOKEN?: string;
  readonly VITE_SF_USER_ID?: string;
  readonly VITE_SF_ORG_ID?: string;
  readonly VITE_SF_USERNAME?: string;
  readonly VITE_SF_CLIENT_ID?: string;
  readonly VITE_SF_REDIRECT_URI?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
