#!/usr/bin/env bash
set -Eeuo pipefail

# Configura o ambiente do deployment para a URL HTTPS do ngrok e mantém o
# único ponto HTTP público no Caddy, em 127.0.0.1:8080.

DEPLOY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${DEPLOY_ROOT}/.env"
NGROK_ORIGIN="${1:-${NGROK_ORIGIN:-}}"

if [[ -z "${NGROK_ORIGIN}" ]]; then
  printf 'Uso: %s https://seu-endereco.ngrok-free.dev\n' "$0" >&2
  exit 2
fi

NGROK_ORIGIN="${NGROK_ORIGIN%/}"
if [[ ! "${NGROK_ORIGIN}" =~ ^https://[^/[:space:]]+$ ]]; then
  printf 'Erro: informe somente a origem HTTPS, por exemplo https://exemplo.ngrok-free.dev\n' >&2
  exit 2
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${DEPLOY_ROOT}/.env.example" "${ENV_FILE}"
  chmod 600 "${ENV_FILE}"
  printf 'Criado %s a partir do .env.example; preencha os segredos antes de subir.\n' "${ENV_FILE}" >&2
fi

set_env() {
  local key="$1"
  local value="$2"
  local temporary
  temporary="$(mktemp "${ENV_FILE}.XXXXXX")"
  awk -v key="${key}" -v value="${value}" '
    BEGIN { found = 0 }
    $0 ~ "^" key "=" { print key "=" value; found = 1; next }
    { print }
    END { if (!found) print key "=" value }
  ' "${ENV_FILE}" > "${temporary}"
  chmod 600 "${temporary}"
  mv -f "${temporary}" "${ENV_FILE}"
}

set_env NSS_HTTP_PORT 8080
set_env CORS_ALLOWED_ORIGINS "${NGROK_ORIGIN}"

cd "${DEPLOY_ROOT}"
docker compose config --quiet
docker compose up -d --force-recreate java caddy

printf '\nConfigurado com sucesso.\n'
printf '%s\n' "- origem CORS: ${NGROK_ORIGIN}" \
  '- entrada pública: somente Caddy em 127.0.0.1:8080' \
  '- Java, PostgreSQL e Grafana continuam sem exposição externa'
printf '\nValide com:\n  curl -I http://127.0.0.1:8080/\n  docker compose ps\n'
