export function encodeSoql(soql: string): string {
  return encodeURIComponent(soql.replace(/\s+/g, ' ').trim());
}

export function buildAddress(parts: Array<string | null | undefined>): string | undefined {
  const clean = parts.filter(Boolean) as string[];
  return clean.length > 0 ? clean.join(', ') : undefined;
}

export function startOfDayIso(dateString: string): string {
  return `${dateString}T00:00:00.000Z`;
}

export function endOfDayIso(dateString: string): string {
  const date = new Date(`${dateString}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + 1);
  return date.toISOString();
}
