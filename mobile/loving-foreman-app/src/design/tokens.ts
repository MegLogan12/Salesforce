export const tokens = {
  color: {
    navy: '#16325c',
    salesforceBlue: '#0070d2',
    green: '#04844b',
    red: '#c23934',
    amber: '#fe9339',
    grayText: '#54698d',
    background: '#f3f3f3',
    card: '#ffffff',
    border: '#d8dde6',
    badgeOffline: '#c23934',
    badgeSyncing: '#fe9339',
    badgeSynced: '#04844b'
  },
  radius: {
    card: 18,
    button: 16,
    badge: 999
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24
  },
  typography: {
    titleSize: 24,
    sectionSize: 18,
    bodySize: 15,
    metaSize: 12,
    buttonSize: 16
  }
} as const;

export type Tokens = typeof tokens;
