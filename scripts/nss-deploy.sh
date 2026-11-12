#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${DEPLOY_ROOT}"
STATE_FILE="${NSS_DEPLOY_STATE_FILE:-${DEPLOY_ROOT}/.nss-deploy-state}"
ENV_FILE="${NSS_ENV_FILE:-/etc/nss/deployment.env}"
RELEASE_MANIFEST="${NSS_RELEASE_MANIFEST:-${DEPLOY_ROOT}/releases.yaml}"

REPO_DATABASE="${NSS_DATABASE_REPO:-${DEPLOY_ROOT}/../NSS-database}"
REPO_JAVA="${NSS_JAVA_REPO:-${DEPLOY_ROOT}/../Site-Sala-de-Situa-o-de-Saude-Java}"
REPO_FRONTEND="${NSS_FRONTEND_REPO:-${DEPLOY_ROOT}/../NSS-front-end}"
REPO_PIPELINE="${NSS_PIPELINE_REPO:-${DEPLOY_ROOT}/../NSS-pipeline}"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { printf '[%s] %s\n' "$(timestamp)" "$*"; }
die() { log "ERRO: $*" >&2; exit 1; }

state_has() { [[ -f "$STATE_FILE" ]] && grep -Fxq "$1" "$STATE_FILE"; }
state_mark() { mkdir -p "$(dirname "$STATE_FILE")"; grep -Fxq "$1" "$STATE_FILE" 2>/dev/null || printf '%s\n' "$1" >> "$STATE_FILE"; }
state_reset() { rm -f "$STATE_FILE"; log "Estado removido: $STATE_FILE"; }

require_repositories() {
  local missing=()
  for pair in "NSS-database:${REPO_DATABASE}" "Java:${REPO_JAVA}" "frontend:${REPO_FRONTEND}" "pipeline:${REPO_PIPELINE}"; do
    local name=${pair%%:*} path=${pair#*:}
    [[ -d "$path" ]] || missing+=("${name} em ${path}")
  done
  ((${#missing[@]} == 0)) || die "repositórios ausentes: ${missing[*]}. Defina NSS_*_REPO ou monte os diretórios esperados."
  log "Repositórios encontrados: database=${REPO_DATABASE}, java=${REPO_JAVA}, frontend=${REPO_FRONTEND}, pipeline=${REPO_PIPELINE}"
}

require_env() {
  [[ -f "$ENV_FILE" ]] || die "arquivo de ambiente não encontrado: ${ENV_FILE}. Para o deploy integrado, copie SOMENTE nss-deployment/.env.example para esse caminho, preencha-o fora do Git e proteja-o com chmod 600. Os .env.example dos demais repositórios são apenas para execução isolada."
  [[ -r "$ENV_FILE" ]] || die "arquivo de ambiente sem permissão de leitura: ${ENV_FILE}"
  if [[ "$(stat -c '%a' "$ENV_FILE" 2>/dev/null || true)" != "600" ]]; then
    log "AVISO: ${ENV_FILE} não está com modo 600; ajuste com: chmod 600 ${ENV_FILE}"
  fi
  set -a
  # shellcheck disable=SC1091
  source "$ENV_FILE"
  set +a
  export COMPOSE_ENV_FILES="$ENV_FILE"
  local missing=()
  for name in POSTGRES_DB POSTGRES_ADMIN_USER POSTGRES_ADMIN_PASSWORD \
    POSTGRES_APP_DB NSS_APP_RUNTIME_USER NSS_APP_RUNTIME_PASSWORD \
    NSS_APP_MIGRATOR_USER NSS_APP_MIGRATOR_PASSWORD \
    NSS_ANALYTICS_READER_USER NSS_ANALYTICS_READER_PASSWORD \
    NSS_ANALYTICS_WRITER_USER NSS_ANALYTICS_WRITER_PASSWORD \
    JWT_SECRET GRAFANA_ADMIN_PASSWORD; do
    [[ -n "${!name:-}" ]] || missing+=("${name}")
  done
  ((${#missing[@]} == 0)) || die "variáveis ausentes em ${ENV_FILE}: ${missing[*]}"
  local placeholders
  placeholders=$(grep -E '(^|=)(CHANGE_ME|change-me-before-deploy|<[^>]+>)($|\s*$)' "$ENV_FILE" || true)
  [[ -z "$placeholders" ]] || die "valores placeholder ainda existem em ${ENV_FILE}; substitua-os antes do deploy"
  local jwt_decoded
  jwt_decoded=$(printf '%s' "$JWT_SECRET" | base64 --decode 2>/dev/null) || \
    die 'JWT_SECRET deve ser Base64 válido; gere-o com: openssl rand -base64 64'
  ((${#jwt_decoded} >= 32)) || \
    die 'JWT_SECRET decodificado deve conter pelo menos 32 bytes; gere-o com: openssl rand -base64 64'
}

progress_bar() {
  local label="$1" percent="$2" elapsed="$3" width=28 filled
  filled=$((width * percent / 100))
  printf '\r%-34s [' "$label"
  printf '%*s' "$filled" '' | tr ' ' '#'
  printf '%*s' "$((width - filled))" '' | tr ' ' '.'
  printf '] %3d%% (%ss)' "$percent" "$elapsed"
}

step() {
  local name="$1"; shift
  local started ended
  started=$(date +%s)
  log "INÍCIO: ${name}"
  local output_file pid elapsed
  output_file=$(mktemp "${TMPDIR:-/tmp}/nss-deploy-step.XXXXXX")
  "$@" >"$output_file" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    elapsed=$(( $(date +%s) - started ))
    progress_bar "$name" $((10 + (elapsed % 80))) "$elapsed"
    sleep 1
  done
  if wait "$pid"; then
    progress_bar "$name" 100 "$(( $(date +%s) - started ))"
    printf '\n'
    sed -n '1,120p' "$output_file"
    ended=$(date +%s)
    log "CONCLUÍDO: ${name} ($((ended - started))s)"
    rm -f "$output_file"
  else
    progress_bar "$name" 100 "$(( $(date +%s) - started ))"
    printf '\n'
    sed -n '1,200p' "$output_file" >&2
    ended=$(date +%s)
    log "FALHOU: ${name} ($((ended - started))s)"
    log 'Consulte a saída acima e execute a opção de diagnóstico antes de repetir.'
    rm -f "$output_file"
    return 1
  fi
}

check_prerequisites() {
  command -v docker >/dev/null || die 'docker não encontrado'
  docker compose version >/dev/null || die 'Docker Compose v2 não encontrado'
  require_env
  docker compose --env-file "$ENV_FILE" config --quiet
  require_repositories
  NSS_RELEASE_MANIFEST="$RELEASE_MANIFEST" scripts/nss-release.sh validate >/dev/null
  log 'Compose válido; imagens e variáveis obrigatórias estão presentes.'
}

preflight_menu() {
  cat <<EOF

NSS deployment — pré-voo obrigatório
  1) Validar Docker Compose instalado
  2) Validar caminhos dos repositórios
  3) Validar arquivo de ambiente completo
  4) Validar configuração efetiva do Compose
  5) Continuar para build e bootstrap

Arquivo de ambiente esperado: ${ENV_FILE}
EOF
  step '1/4 Docker Compose' bash -c 'command -v docker >/dev/null && docker compose version >/dev/null'
  step '2/4 repositórios' require_repositories
  step '3/4 arquivo de ambiente' require_env
  step '4/4 configuração Compose' docker compose --env-file "$ENV_FILE" config --quiet
  read -r -p 'Pré-voo concluído. Continuar? [S/n] ' answer
  [[ -z "$answer" || "$answer" =~ ^[Ss]$ ]] || die 'bootstrap cancelado pelo operador'
}

build_images() {
  step 'imagem do banco central' docker build -t "${NSS_DATABASE_IMAGE:-nss-database:0001}" "$REPO_DATABASE"
  step 'imagem Java' docker build -t "${NSS_JAVA_IMAGE:-nss-java:local}" "$REPO_JAVA"
  step 'imagem frontend' docker build --build-arg VITE_USE_MOCKS=false --build-arg VITE_API_BASE_URL= -t "${NSS_FRONTEND_IMAGE:-nss-frontend:local}" "$REPO_FRONTEND"
  step 'imagem pipeline' docker build -t "${NSS_PIPELINE_IMAGE:-nss-pipeline:local}" "$REPO_PIPELINE"
}

start_database() {
  step 'PostgreSQL' docker compose up -d db
  step 'aguardar PostgreSQL' bash -c '
    for i in {1..60}; do
      if docker compose exec -T db pg_isready -U "${POSTGRES_ADMIN_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; then
        printf "PostgreSQL pronto após %ss\\n" "$(( (i - 1) * 2 ))"
        exit 0
      fi
      sleep 2
    done
    docker compose logs --tail=100 db
    exit 1
  '
  step 'roles PostgreSQL' docker compose run --rm db-permissions
  step 'auditar roles PostgreSQL' docker compose exec -T db psql -U "${POSTGRES_ADMIN_USER}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 -c "SELECT rolname FROM pg_roles WHERE rolname IN ('${NSS_APP_RUNTIME_USER}','${NSS_APP_MIGRATOR_USER}','${NSS_ANALYTICS_READER_USER}','${NSS_ANALYTICS_WRITER_USER}') ORDER BY rolname;"
}

start_java() {
  step 'Redis persistente' docker compose up -d redis redis-rate-limit redis-analytics
  step 'health Redis' docker compose exec -T redis redis-cli ping
  step 'health Redis de limites' docker compose exec -T redis-rate-limit redis-cli ping
  step 'health Redis de analytics' docker compose exec -T redis-analytics redis-cli ping
  step 'schema central NSS 0001' docker compose run --rm migrate
  step 'Java'  docker compose up -d java
  step 'health Java' bash -c '
    container=$(docker compose ps -q java)
    [[ -n "$container" ]] || { docker compose logs --tail=100 java; return 1; }
    for i in {1..30}; do
      status=$(docker inspect --format "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}" "$container")
      [[ "$status" == healthy || "$status" == running ]] && exit 0
      sleep 2
    done
    docker compose logs --tail=100 java
    exit 1
  '
}

bootstrap_tty() {
  log 'Bootstrap completo em modo TTY'
  preflight_menu; state_mark prerequisites
  if ! state_has images; then build_images; state_mark images; else log 'SKIP images: estado concluído'; fi
  if ! state_has database; then start_database; state_mark database; else log 'SKIP database: estado concluído'; fi
  if ! state_has java; then start_java; state_mark java; else log 'SKIP java: estado concluído'; fi
  if ! state_has web; then start_web; state_mark web; else log 'SKIP web: estado concluído'; fi
  status
}

catalog_status() {
  step 'catálogo IBGE ativo' docker compose --profile jobs run --rm --entrypoint python pipeline -c \
    'from pathlib import Path; from app.pipeline.reference.ibge.storage import load_active_catalog; c=load_active_catalog(Path("/data/reference/ibge")); print({"catalog_id":c.metadata.catalog_id,"year":c.metadata.reference_year,"status":c.metadata.validation_status,"municipalities":len(c.municipalities())})'
  step 'lotes CNES' docker compose --profile jobs run --rm --entrypoint python pipeline -c \
    'from pathlib import Path; import json; root=Path("/data/silver/cnes"); print([{ "batch_id":p.parent.name.removeprefix("batch_id="), **json.loads((p.parent/"metadata.json").read_text())} for p in root.glob("batch_id=*/data.parquet")])'
}

refresh_ibge() {
  local catalog_id reference_year dtb_url expected_sha
  read -r -p 'IBGE catalog-id [ibge-dtb-2025]: ' catalog_id; catalog_id=${catalog_id:-ibge-dtb-2025}
  read -r -p 'Ano de referência [2025]: ' reference_year; reference_year=${reference_year:-2025}
  read -r -p 'URL DTB oficial: ' dtb_url
  [[ -n "$dtb_url" ]] || die 'URL DTB é obrigatória para atualizar o IBGE'
  read -r -p 'SHA-256 esperado (opcional): ' expected_sha
  local args=(--root /data/reference/ibge --catalog-id "$catalog_id" --reference-year "$reference_year" --dtb-url "$dtb_url")
  [[ -n "$expected_sha" ]] && args+=(--expected-sha256 "$expected_sha")
  step "atualizar catálogo IBGE ${catalog_id}" docker compose --profile jobs run --rm --entrypoint python pipeline \
    -m app.pipeline.reference.ibge.refresh "${args[@]}"
}

cnes_status() {
  step 'verificar carga CNES' docker compose --profile jobs run --rm --entrypoint python pipeline -c \
    'from pathlib import Path; import json; root=Path("/data/silver/cnes"); items=[]
for p in sorted(root.glob("batch_id=*/metadata.json")):
    data=json.loads(p.read_text()); items.append({"batch_id":p.parent.name.removeprefix("batch_id="),"status":data.get("status"),"rows":data.get("rows"),"municipalities":data.get("municipalities")})
print(json.dumps(items,ensure_ascii=False,indent=2))'
}

update_sinan() {
  local diseases years cnes_batch
  read -r -p 'Doenças separadas por vírgula [DENG]: ' diseases; diseases=${diseases:-DENG}
  read -r -p 'Anos separados por vírgula [2024]: ' years; years=${years:-2024}
  read -r -p 'Batch CNES COMPLETED (opcional): ' cnes_batch
  local args=(--diseases "$diseases" --years "$years" --catalog-root /data/reference/ibge --all-brazil --continue-on-error)
  [[ -n "$cnes_batch" ]] && args+=(--cnes-batch-id "$cnes_batch")
  step "verificar/baixar atualizações SINAN ${diseases}/${years}" docker compose --profile jobs run --rm --entrypoint python pipeline \
    -m app.pipeline.update_sinan "${args[@]}"
}

parquet_status() {
  step 'verificar manifestos Parquet SINAN' docker compose --profile jobs run --rm --entrypoint python pipeline -c \
    'from pathlib import Path; import json; p=Path("/data/source/sinan/manifest.json"); print(json.dumps(json.loads(p.read_text()) if p.exists() else {"status":"missing","path":str(p)},ensure_ascii=False,indent=2))'
}

run_serving_load() {
  local disease year cnes_batch
  read -r -p 'Doença [DENG]: ' disease; disease=${disease:-DENG}
  read -r -p 'Ano [2024]: ' year; year=${year:-2024}
  read -r -p 'Batch CNES COMPLETED: ' cnes_batch
  [[ -n "$cnes_batch" ]] || die 'batch CNES explícito é obrigatório para Gold Serving'
  step "carga Gold Serving ${disease}/${year}" docker compose --profile jobs run --rm --entrypoint python pipeline \
    -m app.pipeline.run_load --disease "$disease" --year "$year" \
    --catalog-root /data/reference/ibge --all-brazil --cnes-batch-id "$cnes_batch"
}

pipeline_preflight() {
  step 'preflight pipeline' docker compose --profile jobs run --rm --entrypoint python \
    -e POSTGRES_USER="${POSTGRES_ADMIN_USER}" \
    -e POSTGRES_PASSWORD="${POSTGRES_ADMIN_PASSWORD}" \
    -e POSTGRES_DB="${POSTGRES_DB}" \
    -e GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}" \
    -e GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD}" \
    -e GRAFANA_DB_USER="${NSS_GRAFANA_DB_USER:-nss_grafana}" \
    -e GRAFANA_DB_PASSWORD="${NSS_GRAFANA_DB_PASSWORD:-${POSTGRES_ADMIN_PASSWORD}}" \
    -e NSS_PIPELINE_IMAGE="${NSS_PIPELINE_IMAGE}" \
    pipeline -m app.pipeline.preflight
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
  step 'frontend, Caddy, Prometheus, Pushgateway e Grafana' docker compose up -d frontend caddy prometheus pushgateway grafana
  step 'smoke Caddy' curl -fsSI http://127.0.0.1:"${NSS_HTTP_PORT:-8080}"/
}

status() {
  docker compose ps || log 'Não foi possível consultar os serviços; verifique Docker/Compose e o .env.'
  printf '\nPortas locais:\n'
  ss -lnt 2>/dev/null | awk -v ports=":${NSS_HTTP_PORT:-8080}|:${NSS_GRAFANA_PORT:-3000}|:${NSS_PROMETHEUS_PORT:-9090}|:${NSS_PUSHGATEWAY_PORT:-9091}|:6379" 'NR==1 || $0 ~ ports' || true
  printf '\nRecursos:\n'
  docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' 2>/dev/null || true
}

diagnose() {
  log 'Diagnóstico de configuração'
  docker compose --env-file "$ENV_FILE" config --quiet && log 'compose.yaml: OK' || log 'compose.yaml: INVÁLIDO'
  log 'DNS interno e Redis'
  docker compose exec -T java getent hosts redis 2>/dev/null || log 'Java ainda não está em execução'
  docker compose exec -T redis redis-cli ping 2>/dev/null || log 'Redis não responde'
  log 'HTTP local'
  curl -fsS -o /dev/null -w 'Caddy HTTP %{http_code}, %{time_total}s\n' http://127.0.0.1:"${NSS_HTTP_PORT:-8080}"/ || true
  log 'Logs recentes'
  docker compose logs --tail=40 java redis redis-rate-limit redis-analytics caddy frontend
}

show_state() {
  printf 'Arquivo de estado: %s\n' "$STATE_FILE"
  if [[ -f "$STATE_FILE" ]]; then sed 's/^/  [concluído] /' "$STATE_FILE"; else echo '  nenhum estado persistido'; fi
}

if [[ "${1:-}" == "up" || "${1:-}" == "resume" ]]; then
  # Carrega o ambiente no processo principal. As etapas executadas por `step`
  # rodam em background e não conseguem devolver exports ao menu pai.
  require_env
  bootstrap_tty
  exit 0
fi
if [[ "${1:-}" == "status" ]]; then show_state; status; exit 0; fi
if [[ "${1:-}" == "reset-state" ]]; then state_reset; exit 0; fi

menu() {
  while true; do
    cat <<'EOF'

NSS deployment
  1) verificar pré-requisitos e Compose
  2) construir imagens Java/frontend/pipeline
  3) subir PostgreSQL e provisionar roles
  4) subir Redis, schema central e Java
  5) preflight da pipeline
  6) verificar catálogo IBGE ativo
  7) atualizar release/catálogo IBGE
  8) verificar carga CNES
  9) baixar/atualizar carga CNES nacional
  10) verificar manifestos Parquet SINAN
  11) verificar/baixar atualizações Parquet SINAN
  12) executar Gold Serving/PostgreSQL
  13) subir frontend, Caddy e observabilidade
  14) status e diagnóstico
  15) mostrar máquina de estados
  16) limpar estado persistido
  17) sair
EOF
    read -r -p 'Escolha: ' choice
    case "${choice}" in
      1) step 'pré-requisitos' check_prerequisites ;;
      2) build_images ;;
      3) start_database ;;
      4) start_java ;;
      5) pipeline_preflight ;;
      6) catalog_status ;;
      7) refresh_ibge ;;
      8) cnes_status ;;
      9) run_cnes ;;
      10) parquet_status ;;
      11) update_sinan ;;
      12) read -r -p 'Confirma carga Gold nacional? [digite SIM]: ' confirm; [[ "${confirm}" == SIM ]] && run_serving_load || log 'Gold Serving não executada.' ;;
      13) start_web ;;
      14) status; diagnose ;;
      15) show_state ;;
      16) read -r -p 'Digite LIMPAR para confirmar: ' confirm; [[ "$confirm" == LIMPAR ]] && state_reset || log 'Estado preservado.' ;;
      17) return 0 ;;
      *) log 'Opção inválida.' ;;
    esac
  done
}

# O menu também precisa manter as variáveis carregadas entre operações. Sem
# isso, a opção 1 valida o ambiente em um processo filho e a opção 3 pode
# encontrar POSTGRES_ADMIN_USER/POSTGRES_DB indefinidas.
require_env
menu
