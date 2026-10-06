import { test, expect } from '@playwright/test';
import { login, authHeaders } from '../helpers/auth.mjs';
import { DISEASES, SEXES, AGE_BANDS, query, assertEnvelope } from '../helpers/oracle.mjs';

test.describe.configure({ mode: 'parallel' });

for (const disease of DISEASES) {
  for (const sex of SEXES) {
    for (const ageBand of AGE_BANDS) {
      const sexLabel = sex ?? 'ALL';
      const ageLabel = ageBand ?? 'ALL';
      test(`FILTER-E2E-${disease}-${sexLabel}-${ageLabel}`, async ({ request }) => {
        const session = await login(request);
        const filters = { geography: 'MUNICIPALITY', disease, year: 2026, month: 1, sex, ageBand };
        const response = await request.get(query(filters), { headers: authHeaders(session) });
        expect(response.status()).toBe(200);
        const body = assertEnvelope(await response.json(), filters);
        expect(body.geography).toBe('MUNICIPALITY');
        expect(body.filters.disease).toBe(disease);
        expect(body.filters.year).toBe(2026);
        expect(body.filters.month).toBe(1);
        if (sex) expect(body.filters.sex).toBe(sex);
        if (ageBand) expect(body.filters.ageBand).toBe(ageBand);
      });
    }
  }
}
