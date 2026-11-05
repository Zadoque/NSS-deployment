#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${DEPLOY_ROOT}"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { printf '[%s] %s\n' "$(timestamp)" "$*"; }
die() { log "ERRO: $*" >&2; exit 1; }

require_env() {
  [[ -f .env ]] || die '.env não existe; copie .env.example e preencha os segredos.'
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
  local missing=()
  for name in POSTGRES_DB POSTGRES_ADMIN_USER POSTGRES_ADMIN_PASSWORD \
    POSTGRES_APP_DB NSS_APP_RUNTIME_USER NSS_APP_RUNTIME_PASSWORD \
    NSS_APP_MIGRATOR_USER NSS_APP_MIGRATOR_PASSWORD \
    NSS_ANALYTICS_READER_USER NSS_ANALYTICS_READER_PASSWORD \
    NSS_ANALYTICS_WRITER_USER NSS_ANALYTICS_WRITER_PASSWORD \
    JWT_SECRET GRAFANA_ADMIN_PASSWORD; do
    [[ -n "${!name:-}" ]] || missing+=("${name}")
  done
  ((${#missing[@]} == 0)) || die "variáveis ausentes no .env: ${missing[*]}"
}

step() {
  local name="$1"; shift
  local started ended
  started=$(date +%s)
  log "INÍCIO: ${name}"
  if "$@"; then
    ended=$(date +%s)
    log "CONCLUÍDO: ${name} ($((ended - started))s)"
  else
    ended=$(date +%s)
    log "FALHOU: ${name} ($((ended - started))s)"
    log 'Execute a opção 8 para separar falha de rede, serviço ou configuração.'
    return 1
  fi
}

check_prerequisites() {
  command -v docker >/dev/null || die 'docker não encontrado'
  docker compose version >/dev/null || die 'Docker Compose v2 não encontrado'
  require_env
  docker compose config --quiet
  log 'Compose válido; imagens e variáveis obrigatórias estão presentes.'
}

build_images() {
  step 'imagem Java' docker build -t "${NSS_JAVA_IMAGE:-nss-java:local}" ../Site-Sala-de-Situa-o-de-Saude-Java
  step 'imagem frontend' docker build --build-arg VITE_USE_MOCKS=false --build-arg VITE_API_BASE_URL= -t "${NSS_FRONTEND_IMAGE:-nss-frontend:local}" ../NSS-front-end
  step 'imagem pipeline' docker build -t "${NSS_PIPELINE_IMAGE:-nss-pipeline:local}" ../NSS-pipeline
}

start_database() {
  step 'PostgreSQL' docker compose up -d db
  step 'aguardar PostgreSQL' docker compose exec -T db pg_isready -U "${POSTGRES_ADMIN_USER}" -d "${POSTGRES_DB}"
  step 'roles PostgreSQL' docker compose run --rm db-permissions
}

start_java() {
  step 'Redis persistente' docker compose up -d redis
  step 'health Redis' docker compose exec -T redis redis-cli ping
  step 'schema analítico Alembic' docker compose run --rm migrate
  step 'Java e Flyway 0001' docker compose up -d java
  step 'health Java' bash -c 'for i in {1..30}; do curl -fsS http://127.0.0.1:8080/actuator/health >/dev/null 2>&1 && return 0; sleep 2; done; docker compose logs --tail=100 java; return 1'
}

catalog_status() {
  step 'catálogo IBGE ativo' docker compose --profile jobs run --rm --entrypoint python pipeline -c \
    'from pathlib import Path; from app.pipeline.reference.ibge.storage import load_active_catalog; c=load_active_catalog(Path("/data/reference/ibge")); print({"catalog_id":c.metadata.catalog_id,"year":c.metadata.reference_year,"status":c.metadata.validation_status,"municipalities":len(c.municipalities())})'
  step 'lotes CNES' docker compose --profile jobs run --rm --entrypoint python pipeline -c \
    'from pathlib import Path; import json; root=Path("/data/silver/cnes"); print([{ "batch_id":p.parent.name.removeprefix("batch_id="), **json.loads((p.parent/"metadata.json").read_text())} for p in root.glob("batch_id=*/data.parquet")])'
}

run_pipeline() {
  local disease year scope
  read -r -p 'Doença (ex.: DENG): ' disease
  read -r -p 'Ano (ex.: 2024): ' year
  read -r -p 'Escopo [all-brazil]: ' scope
  scope=${scope:-all-brazil}
  [[ "${scope}" == 'all-brazil' ]] || die 'esta versão do menu aceita apenas all-brazil; use o comando manual para escopo parcial.'
  step "pipeline ${disease}/${year}" docker compose --profile jobs run --rm pipeline --disease "${disease}" --year "${year}" --all-brazil
}

run_cnes() {
  local workers checkpoint
  read -r -p 'Workers CNES [8]: ' workers
  workers=${workers:-8}
  read -r -p 'Checkpoint [cnes-national-ibge-2025.json]: ' checkpoint
  checkpoint=${checkpoint:-cnes-national-ibge-2025.json}
  step 'CNES nacional' docker compose --profile jobs run --rm --entrypoint python pipeline \
    -m app.pipeline.run_cnes \
    --catalog-root /data/reference/ibge \
    --all-brazil \
    --workers "${workers}" \
    --continue-on-error \
    --checkpoint "/data/checkpoints/${checkpoint}"
}

start_web() {
  step 'frontend, Caddy, Prometheus e Grafana' docker compose up -d frontend caddy prometheus grafana
  step 'smoke Caddy' curl -fsSI http://127.0.0.1:"${NSS_HTTP_PORT:-8080}"/
}

status() {
  docker compose ps
  printf '\nPortas locais:\n'
  ss -lnt 2>/dev/null | awk 'NR==1 || /:8080|:3000|:9090|:9091|:6379/' || true
  printf '\nRecursos:\n'
  docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' 2>/dev/null || true
}

diagnose() {
  log 'Diagnóstico de configuração'
  docker compose config --quiet && log 'compose.yaml: OK' || log 'compose.yaml: INVÁLIDO'
  log 'DNS interno e Redis'
  docker compose exec -T java getent hosts redis 2>/dev/null || log 'Java ainda não está em execução'
  docker compose exec -T redis redis-cli ping 2>/dev/null || log 'Redis não responde'
  log 'HTTP local'
  curl -fsS -o /dev/null -w 'Caddy HTTP %{http_code}, %{time_total}s\n' http://127.0.0.1:"${NSS_HTTP_PORT:-8080}"/ || true
  log 'Logs recentes'
  docker compose logs --tail=40 java redis caddy frontend
}

menu() {
  while true; do
    cat <<'EOF'

NSS deployment
  1) verificar pré-requisitos e Compose
  2) construir imagens Java/frontend/pipeline
  3) subir PostgreSQL e provisionar roles
  4) subir Redis, Flyway 0001, Alembic e Java
  5) verificar catálogo IBGE e lotes CNES
  6) ingerir CNES nacional com checkpoint
  7) executar pipeline nacional (confirmação explícita)
  8) subir frontend, Caddy e observabilidade
  9) status e diagnóstico
  10) sair
EOF
    read -r -p 'Escolha: ' choice
    case "${choice}" in
      1) step 'pré-requisitos' check_prerequisites ;;
      2) build_images ;;
      3) start_database ;;
      4) start_java ;;
      5) catalog_status ;;
      6) run_cnes ;;
      7) read -r -p 'Confirma execução nacional da pipeline? [digite SIM]: ' confirm; [[ "${confirm}" == SIM ]] && run_pipeline || log 'Pipeline não executada.' ;;
      8) start_web ;;
      9) status; diagnose ;;
      10) return 0 ;;
      *) log 'Opção inválida.' ;;
    esac
  done
}

require_env
menu
