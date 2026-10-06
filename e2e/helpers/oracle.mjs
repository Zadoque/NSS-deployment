export const DISEASES = ['DENG', 'FMAC', 'TOXC', 'TOXG'];
export const SEXES = [undefined, 'M', 'F'];
export const AGE_BANDS = [
  undefined, 'LT1', '01_04', '05_09', '10_14', '15_19', '20_39',
  '40_59', '60_64', '65_69', '70_74', '75_79', '80_PLUS',
];
export const MUNICIPALITIES = ['3301009', '3302205', '3302403', '3305000'];
export const YEARS = [2026];
export const MONTHS = [1, 2, 3, 4, 5, 6, 7, 8, 9];
export const SEDE = 'CG_DIST_SEDE';

export function query(filters) {
  const params = new URLSearchParams({ geography: filters.geography, disease: filters.disease });
  for (const [key, value] of Object.entries(filters)) {
    if (key !== 'geography' && value !== undefined && value !== null && value !== 'ALL') params.set(key, String(value));
  }
  const endpoint = { MUNICIPALITY: 'municipalities', DISTRICT: 'districts', NEIGHBORHOOD: 'neighborhoods' }[filters.geography];
  return `/api/v1/epidemiology/${endpoint}?${params}`;
}

export function assertEnvelope(body, filters) {
  if (!body || !Array.isArray(body.items)) throw new Error('Envelope sem items');
  if (body.totalNotifications !== null && (!Number.isSafeInteger(body.totalNotifications) || body.totalNotifications < 0)) throw new Error('Total inválido');
  if (!body.coverage || !['AVAILABLE', 'PARTIAL', 'UNAVAILABLE'].includes(body.coverage.status)) throw new Error('Cobertura inválida');
  for (const key of ['mappedNotificationsTotal', 'unmappedNotificationsTotal']) {
    if (!Number.isSafeInteger(body.coverage[key]) || body.coverage[key] < 0) throw new Error(`Cobertura inválida: ${key}`);
  }
  if (body.totalNotifications !== null && body.coverage.mappedNotificationsTotal + body.coverage.unmappedNotificationsTotal !== body.totalNotifications) throw new Error('Cobertura não reconcilia total');
  const codes = body.items.map((item) => item.code);
  if (new Set(codes).size !== codes.length) throw new Error('Territórios duplicados');
  for (const item of body.items) {
    if (typeof item.code !== 'string' || !Number.isSafeInteger(item.notificationsTotal) || item.notificationsTotal < 0) throw new Error('Item inválido');
  }
  return body;
}
