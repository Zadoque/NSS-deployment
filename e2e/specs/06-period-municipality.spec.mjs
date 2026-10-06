import { test, expect } from '@playwright/test';
import { login, authHeaders } from '../helpers/auth.mjs';
import { DISEASES, MUNICIPALITIES, query, assertEnvelope } from '../helpers/oracle.mjs';

const periods = [
  { name: 'year-total', year: 2026 },
  { name: 'month-01', year: 2026, month: 1 },
];

for (const disease of DISEASES) {
  for (const municipalityCode of MUNICIPALITIES) {
    for (const period of periods) {
      test(`PERIOD-E2E-${disease}-${municipalityCode}-${period.name}`, async ({ request }) => {
        const session = await login(request);
        const filters = { geography: 'MUNICIPALITY', disease, municipalityCode, ...period };
        const response = await request.get(query(filters), { headers: authHeaders(session) });
        expect(response.status()).toBe(200);
        assertEnvelope(await response.json(), filters);
      });
    }
  }
}
