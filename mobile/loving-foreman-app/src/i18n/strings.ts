import type { LanguageCode } from '@/data/contracts';

export const strings: Record<LanguageCode, Record<string, string>> = {
  en: {
    appTitle: 'LOVING Field App',
    prototypeNotice: 'Production foreman app scaffold',
    syncQueue: 'Sync Queue',
    settings: 'Settings'
  },
  es: {
    appTitle: 'LOVING Field App',
    prototypeNotice: 'Base de la aplicacion de produccion',
    syncQueue: 'Cola de sync',
    settings: 'Configuracion'
  }
};
