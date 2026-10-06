import { loadEnvFile } from 'node:process';

loadEnvFile(new URL('../.env', import.meta.url));

export function credentials() {
  return { email: process.env.E2E_EMAIL, password: process.env.E2E_PASSWORD };
}

let sharedSessionPromise;

async function authenticate(request) {
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

export async function login(request, { fresh = false } = {}) {
  if (fresh) return authenticate(request);

  sharedSessionPromise ??= authenticate(request).catch((error) => {
    sharedSessionPromise = undefined;
    throw error;
  });
  return sharedSessionPromise;
}

export function authHeaders(session) {
  return { Authorization: `Bearer ${session.token}`, Accept: 'application/json' };
}
