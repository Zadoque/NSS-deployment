import { test, expect } from '@playwright/test';
import { login, authHeaders } from '../helpers/auth.mjs';
import { MUNICIPALITIES, SEDE, query, assertEnvelope } from '../helpers/oracle.mjs';

for (const municipalityCode of MUNICIPALITIES) {
  test(`GEO-E2E-MUNICIPALITY-${municipalityCode}`, async ({ request }) => {
    const session = await login(request);
    const filters = { geography: 'MUNICIPALITY', disease: 'DENG', year: 2026, municipalityCode };
    const response = await request.get(query(filters), { headers: authHeaders(session) });
    expect(response.status()).toBe(200);
    assertEnvelope(await response.json(), filters);
  });
}

test('GEO-E2E-DISTRICT-CAMPOS', async ({ request }) => {
  const session = await login(request);
  const filters = { geography: 'DISTRICT', disease: 'DENG', year: 2026, municipalityCode: '3301009' };
  const body = assertEnvelope(await (await request.get(query(filters), { headers: authHeaders(session) })).json(), filters);
  expect(body.totalNotifications).toBe(23);
  expect(body.coverage.mappedNotificationsTotal).toBe(23);
});

test('GEO-E2E-NEIGHBORHOOD-SEDE', async ({ request }) => {
  const session = await login(request);
  const filters = { geography: 'NEIGHBORHOOD', disease: 'DENG', year: 2026, municipalityCode: '3301009', districtCode: SEDE };
  const body = assertEnvelope(await (await request.get(query(filters), { headers: authHeaders(session) })).json(), filters);
  expect(body.totalNotifications).toBe(23);
  expect(body.coverage.mappedNotificationsTotal).toBe(21);
});

test('GEO-E2E-NEIGHBORHOOD-WITHOUT-DISTRICT-is-unavailable', async ({ request }) => {
  const session = await login(request);
  const filters = { geography: 'NEIGHBORHOOD', disease: 'DENG', municipalityCode: '3301009' };
  const response = await request.get(query(filters), { headers: authHeaders(session) });
  expect(response.status()).toBe(200);
  const body = await response.json();
  expect(body.totalNotifications).toBeNull();
  expect(body.coverage.status).toBe('UNAVAILABLE');
});
