# Contrato de autenticação - NSS 1.0

Status: **normativo para NSS 1.0**

## Objetivo

Proteger o dashboard epidemiológico com sessão web baseada em e-mail/senha, access token JWT curto e refresh token revogável. A Home pode permanecer pública.

## Estado inicial do backend

O backend Java já possui Spring Security stateless, login por e-mail/senha, Argon2, JWT Bearer e filtro de autenticação. A NSS 1.0 evolui esse fluxo sem substituir a base existente.

## Access token

- formato: JWT;
- transporte: `Authorization: Bearer <token>`;
- duração alvo bootstrap: 15 minutos, configurável;
- armazenamento no frontend: memória da aplicação, não persistência permanente;
- somente claims necessários à autenticação/autorização.

## Refresh token

- token opaco aleatório, não JWT;
- duração alvo bootstrap: 7 dias, configurável;
- persistência do servidor: somente hash criptográfico do token;
- associação a usuário, criação, expiração e revogação;
- rotação obrigatória a cada refresh bem-sucedido;
- token anterior revogado quando novo é emitido.

Cookie:

```text
HttpOnly
Secure
SameSite=Strict
Path=/api/v1/auth
```

O valor do refresh token nunca é exposto a JavaScript.

## Endpoints

### Login - `POST /api/v1/auth/login`

Valida e-mail/senha, emite access, cria refresh, grava hash e envia cookie. Credenciais inválidas retornam `401` sem revelar se o e-mail existe.

### Refresh - `POST /api/v1/auth/refresh`

Lê cookie, rejeita token ausente/expirado/revogado, rotaciona refresh em transação, emite novo access e atualiza cookie.

### Logout - `POST /api/v1/auth/logout`

Revoga refresh quando presente, remove cookie e retorna `204` de forma idempotente.

## Cadastro e usuários

- auto-registro público **desabilitado**;
- usuários iniciais provisionados administrativamente por mecanismo controlado;
- `/users/**` não pode ficar genericamente disponível a qualquer usuário autenticado;
- painel administrativo completo fica fora do escopo imediato.

`cargo` de negócio não deve ser aceito como autoridade de autenticação sem validação administrativa. Em evolução posterior, separar explicitamente cargo/atributo de domínio de role/authority.

## Mesma origem

Caddy apresenta Frontend e `/api/*` sob a mesma origem. Isso evita dependência de cookies cross-site e reduz configuração CORS.

## Segredos

Nunca versionar `JWT_SECRET`, senhas PostgreSQL, token ngrok, credenciais Grafana ou refresh tokens reais.

## Testes mínimos

1. login válido retorna access e cookie refresh;
2. login inválido retorna 401;
3. endpoint protegido rejeita request sem Bearer;
4. access válido permite endpoint protegido;
5. refresh válido rotaciona token;
6. refresh antigo falha após rotação;
7. logout revoga refresh;
8. dashboard não restaura sessão após logout;
9. registro público está bloqueado;
10. usuário comum não possui CRUD irrestrito sobre outros usuários.
