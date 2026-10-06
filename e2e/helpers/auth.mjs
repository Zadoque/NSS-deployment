import { loadEnvFile } from 'node:process';

loadEnvFile(new URL('../.env', import.meta.url));

export function credentials() {
  return { email: process.env.E2E_EMAIL, password: process.env.E2E_PASSWORD };
}

export async function login(request) {
  const { email, password } = credentials();
  if (!email || !password) throw new Error('E2E_EMAIL/E2E_PASSWORD não configurados');
  const response = await request.post('/api/v1/auth/login', {
    data: { email, password },
    headers: { Accept: 'application/json' },
  });
  if (!response.ok()) throw new Error(`Login E2E falhou: ${response.status()}`);
  const body = await response.json();
  const token = body.accessToken ?? body.token;
  if (!token) throw new Error('Login E2E não retornou access token');
  return { token, user: body.user, permissions: body.permissions ?? [] };
}

export function authHeaders(session) {
  return { Authorization: `Bearer ${session.token}`, Accept: 'application/json' };
}
