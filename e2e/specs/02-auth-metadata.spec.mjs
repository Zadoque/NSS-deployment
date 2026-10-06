import { test, expect } from '@playwright/test';
import { credentials, login, authHeaders } from '../helpers/auth.mjs';

test('AUTH-E2E-002 login inválido permanece na tela de login', async ({ page }) => {
  const { email } = credentials();
  test.skip(!email, 'Credenciais E2E não configuradas');
  await page.goto('/login');
  await page.getByLabel('E-mail', { exact: true }).fill(email);
  await page.getByLabel('Senha', { exact: true }).fill('senha-e2e-invalida');
  const response = page.waitForResponse((r) => r.url().includes('/api/v1/auth/login'));
  await page.getByRole('button', { name: 'Entrar', exact: true }).click();
  expect((await response).status()).toBe(401);
  await expect(page).toHaveURL(/\/login$/);
  await expect(page.getByRole('alert')).toBeVisible();
});

test('AUTH-E2E-003 refresh sem sessão é rejeitado', async ({ request }) => {
  const response = await request.post('/api/v1/auth/refresh', { headers: { Accept: 'application/json' } });
  expect([401, 403]).toContain(response.status());
});

test('AUTH-E2E-004 logout encerra a sessão', async ({ request }) => {
  const session = await login(request);
  const response = await request.post('/api/v1/auth/logout', { headers: authHeaders(session) });
  expect([200, 204]).toContain(response.status());
});

test('META-E2E-001 metadata contém recorte publicado', async ({ request }) => {
  const session = await login(request);
  const response = await request.get('/api/v1/metadata', { headers: authHeaders(session) });
  expect(response.status()).toBe(200);
  const body = await response.json();
  expect(body.availableYears).toContain(2026);
  expect(body.availableMonthsByYear['2026']).toEqual(expect.arrayContaining([1, 9]));
  expect(body.supportedGeographies).toEqual(expect.arrayContaining(['MUNICIPALITY', 'DISTRICT', 'NEIGHBORHOOD']));
  expect(body.supportedAgeBands).toHaveLength(12);
});

test('META-E2E-002 diseases lista os quatro agravos publicados', async ({ request }) => {
  const session = await login(request);
  const response = await request.get('/api/v1/diseases', { headers: authHeaders(session) });
  expect(response.status()).toBe(200);
  expect(await response.json()).toEqual({ items: expect.arrayContaining(['DENG', 'FMAC', 'TOXC', 'TOXG']) });
});
