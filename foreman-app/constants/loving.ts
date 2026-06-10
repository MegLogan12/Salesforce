// FSL-inspired design tokens
export const C = {
  // Brand
  navy:    '#032D60',   // deep SF navy
  blue:    '#0176D3',   // SF action blue
  green:   '#2E844A',   // SF success
  orange:  '#F59300',   // FSL in-progress amber
  red:     '#BA0517',   // SF error
  purple:  '#534ab7',
  teal:    '#0D9DDA',

  // Surface
  bg:      '#F3F3F3',
  white:   '#FFFFFF',
  card:    '#FFFFFF',
  dark:    '#1A1F36',

  // Text
  text:    '#181818',
  text2:   '#3E3E3C',
  muted:   '#706E6B',
  subtle:  '#AEAEAE',

  // Border
  border:  '#DDDBDA',
  divider: '#EBEBEB',
} as const;

export const lovingColors = C;

export const Sh = {
  xs: { shadowColor: '#000', shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.06, shadowRadius: 2, elevation: 1 },
  sm: { shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.09, shadowRadius: 5, elevation: 3 },
  md: { shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.13, shadowRadius: 10, elevation: 5 },
} as const;

export const R = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
} as const;
