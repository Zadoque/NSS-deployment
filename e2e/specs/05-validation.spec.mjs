import { test, expect } from '@playwright/test';
import { login, authHeaders } from '../helpers/auth.mjs';

const invalidCases = [
  ['year-zero', 'year=0'],
  ['month-zero', 'month=0'],
  ['month-thirteen', 'month=13'],
  ['sex-invalid', 'sex=X'],
  ['age-invalid', 'ageBand=INVALID'],
  ['municipality-invalid', 'municipalityCode=abc'],
];

for (const [name, parameter] of invalidCases) {
  test(`VALIDATION-E2E-${name}`, async ({ request }) => {
    const session = await login(request);
    const response = await request.get(`/api/v1/epidemiology/municipalities?geography=MUNICIPALITY&disease=DENG&${parameter}`, { headers: authHeaders(session) });
    expect([400, 422]).toContain(response.status());
  });
}

test('RESILIENCE-E2E-401-protected-endpoint', async ({ request }) => {
  const response = await request.get('/api/v1/metadata');
  expect([401, 403]).toContain(response.status());
});

test('RESILIENCE-E2E-unknown-endpoint', async ({ request }) => {
  const session = await login(request);
  const response = await request.get('/api/v1/does-not-exist', { headers: authHeaders(session) });
  expect([404, 405]).toContain(response.status());
});

test('UI-E2E-responsive-dashboard', async ({ page }) => {
  test.skip(!process.env.E2E_EMAIL || !process.env.E2E_PASSWORD, 'Credenciais E2E não configuradas');
  await page.goto('/login');
  await page.getByLabel('E-mail', { exact: true }).fill(process.env.E2E_EMAIL);
  await page.getByLabel('Senha', { exact: true }).fill(process.env.E2E_PASSWORD);
  await page.getByRole('button', { name: 'Entrar', exact: true }).click();
  await expect(page).toHaveURL(/\/mapa$/);
  for (const width of [375, 768, 1024, 1440]) {
    await page.setViewportSize({ width, height: 900 });
    if (width < 1024) {
      await expect(page.locator('.mobile-controls').getByRole('button', { name: /Filtros e informações/ })).toBeVisible();
    } else {
      await expect(page.getByRole('complementary').getByText('Filtros e informações')).toBeVisible();
    }
  }
});
