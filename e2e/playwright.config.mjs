import { defineConfig } from '@playwright/test';
import { loadEnvFile } from 'node:process';

const explicitBaseURL = process.env.E2E_BASE_URL;
loadEnvFile(new URL('.env', import.meta.url));

export default defineConfig({
  testDir: './specs',
  timeout: 30_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list'], ['html', { outputFolder: 'playwright-report', open: 'never' }]],
  use: {
    baseURL: explicitBaseURL || process.env.E2E_BASE_URL,
    extraHTTPHeaders: { 'ngrok-skip-browser-warning': 'true' },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'off',
    launchOptions: { executablePath: process.env.CHROMIUM_PATH || undefined },
  },
});
