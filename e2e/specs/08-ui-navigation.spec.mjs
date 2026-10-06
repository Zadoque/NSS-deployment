import { test, expect } from '@playwright/test';
import { credentials } from '../helpers/auth.mjs';

for (const [name, width] of [['desktop', 1440], ['mobile', 375]]) {
  test(`UI-E2E-navigation-${name}`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    const { email, password } = credentials();
    await page.goto('/login');
    await page.getByLabel(/e-mail/i).fill(email);
    await page.getByLabel(/senha/i).fill(password);
    await page.getByRole('button', { name: /entrar|acessar|login/i }).click();
    await expect(page).toHaveURL(/\/mapa/);
    await expect(page.locator('body')).not.toContainText(/erro interno|internal server error/i);
  });
}
