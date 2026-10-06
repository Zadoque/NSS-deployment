import { test, expect } from '@playwright/test';
import { login, authHeaders } from '../helpers/auth.mjs';
import { AGE_BANDS, DISEASES, SEDE, SEXES, query, assertEnvelope } from '../helpers/oracle.mjs';

const selectedAgeBands = [AGE_BANDS[0], 'LT1', '20_39'];

for (const disease of DISEASES) {
  for (const sex of SEXES) {
    for (const ageBand of selectedAgeBands) {
      test(`TERRITORY-E2E-${disease}-${sex ?? 'ALL'}-${ageBand ?? 'ALL'}`, async ({ request }) => {
        const session = await login(request);
        const filters = {
          geography: 'DISTRICT',
          disease,
          year: 2026,
          municipalityCode: '3301009',
          districtCode: SEDE,
          sex,
          ageBand,
        };
        const response = await request.get(query(filters), { headers: authHeaders(session) });
        expect(response.status()).toBe(200);
        assertEnvelope(await response.json(), filters);
      });
    }
  }
}
