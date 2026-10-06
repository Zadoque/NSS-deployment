import { test, expect } from '@playwright/test';
import { loadEnvFile } from 'node:process';

loadEnvFile(new URL('../.env', import.meta.url));

test('AUTH-E2E-001 login válido abre o mapa epidemiológico', async ({ page }) => {
  test.skip(!process.env.E2E_EMAIL || !process.env.E2E_PASSWORD, 'Credenciais E2E não configuradas');

  const serverErrors = [];
  page.on('response', (response) => {
    if (response.url().includes('/api/v1/') && response.status() >= 500) {
      serverErrors.push(`${response.status()} ${response.url()}`);
    }
  });

  await page.goto('/login');
  await expect(page.getByRole('heading', { name: 'Entrar no NSS' })).toBeVisible();
  await page.getByLabel('E-mail', { exact: true }).fill(process.env.E2E_EMAIL);
  await page.getByLabel('Senha', { exact: true }).fill(process.env.E2E_PASSWORD);

  const login = page.waitForResponse((response) =>
    response.url().includes('/api/v1/auth/login'),
  );
  await page.getByRole('button', { name: 'Entrar', exact: true }).click();
  expect((await login).status()).toBe(200);

  await expect(page).toHaveURL(/\/mapa$/);
  await expect(page.getByRole('complementary').getByText('RECORTE EPIDEMIOLÓGICO')).toBeVisible();
  expect(serverErrors).toEqual([]);
});
