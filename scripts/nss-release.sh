#!/usr/bin/env bash
set -Eeuo pipefail

DEPLOY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_FILE="${NSS_RELEASE_MANIFEST:-${DEPLOY_ROOT}/releases.yaml}"

die() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }

[[ -r "$MANIFEST_FILE" ]] || die "manifesto não encontrado: ${MANIFEST_FILE}"

manifest_value() {
  local component="$1" field="$2"
  awk -v component="$component" -v field="$field" '
    $0 == component ":" { in_section=1; next }
    in_section && $0 ~ /^[^[:space:]#]/ { in_section=0 }
    in_section && $1 == field ":" {
      sub(/^[[:space:]]*[^:]+:[[:space:]]*/, "")
      sub(/[[:space:]]+#.*$/, "")
      print
      exit
    }
  ' "$MANIFEST_FILE"
}

validate_manifest() {
  local component repository branch commit
  for component in database java frontend pipeline; do
    repository=$(manifest_value "$component" repository)
    branch=$(manifest_value "$component" branch)
    commit=$(manifest_value "$component" commit)
    [[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] ||
      die "${component}.repository inválido no manifesto"
    [[ -n "$branch" && "$branch" != *[[:space:]]* ]] ||
      die "${component}.branch ausente ou inválido no manifesto"
    [[ "$commit" =~ ^[0-9a-fA-F]{40,64}$ ]] ||
      die "${component}.commit deve ser um SHA Git no manifesto"
    printf '%-8s %s %s %s\n' "$component" "$repository" "$branch" "$commit"
  done
  validate_ibge
  printf 'ibge     %s %s %s %s\n' \
    "$(manifest_value ibge catalogId)" \
    "$(manifest_value ibge referenceYear)" \
    "$(manifest_value ibge dtbUrl)" \
    "$(manifest_value ibge expectedSha256)"
  validate_cnes
  printf 'cnes     %s %s\n' \
    "$(manifest_value cnes workers)" \
    "$(manifest_value cnes checkpoint)"
}

validate_ibge() {
  local catalog_id reference_year dtb_url expected_sha
  catalog_id=$(manifest_value ibge catalogId)
  reference_year=$(manifest_value ibge referenceYear)
  dtb_url=$(manifest_value ibge dtbUrl)
  expected_sha=$(manifest_value ibge expectedSha256)
  [[ "$catalog_id" =~ ^[A-Za-z0-9_.-]+$ ]] ||
    die 'ibge.catalogId inválido no manifesto'
  [[ "$reference_year" =~ ^[0-9]{4}$ ]] ||
    die 'ibge.referenceYear deve ser um ano de quatro dígitos'
  [[ "$dtb_url" =~ ^https:// ]] ||
    die 'ibge.dtbUrl deve usar HTTPS'
  [[ "$expected_sha" =~ ^[0-9a-fA-F]{64}$ ]] ||
    die 'ibge.expectedSha256 deve ser um SHA-256 hexadecimal'
}

validate_cnes() {
  local workers checkpoint
  workers=$(manifest_value cnes workers)
  checkpoint=$(manifest_value cnes checkpoint)
  [[ "$workers" =~ ^[1-9][0-9]*$ ]] ||
    die 'cnes.workers deve ser um inteiro positivo no manifesto'
  ((workers <= 128)) ||
    die 'cnes.workers não pode exceder 128 no manifesto'
  [[ "$checkpoint" =~ ^[A-Za-z0-9_.-]+\.json$ ]] ||
    die 'cnes.checkpoint deve ser um nome de arquivo JSON simples no manifesto'
}

ibge_values() {
  validate_ibge
  printf '%s\t%s\t%s\t%s\n' \
    "$(manifest_value ibge catalogId)" \
    "$(manifest_value ibge referenceYear)" \
    "$(manifest_value ibge dtbUrl)" \
    "$(manifest_value ibge expectedSha256)"
}

cnes_values() {
  validate_cnes
  printf '%s\t%s\n' \
    "$(manifest_value cnes workers)" \
    "$(manifest_value cnes checkpoint)"
}

repo_path() {
  case "$1" in
    database) printf '%s\n' "${NSS_DATABASE_REPO:-${DEPLOY_ROOT}/../NSS-database}" ;;
    java) printf '%s\n' "${NSS_JAVA_REPO:-${DEPLOY_ROOT}/../Site-Sala-de-Situa-o-de-Saude-Java}" ;;
    frontend) printf '%s\n' "${NSS_FRONTEND_REPO:-${DEPLOY_ROOT}/../NSS-front-end}" ;;
    pipeline) printf '%s\n' "${NSS_PIPELINE_REPO:-${DEPLOY_ROOT}/../NSS-pipeline}" ;;
    *) die "componente desconhecido: $1" ;;
  esac
}

sync_repositories() {
  local component branch commit target
  validate_manifest >/dev/null
  for component in database java frontend pipeline; do
    target=$(repo_path "$component")
    [[ -d "$target/.git" ]] || die "repositório ${component} não encontrado: ${target}"
    git -C "$target" diff --quiet || die "${component} possui alterações não commitadas"
    git -C "$target" diff --cached --quiet || die "${component} possui alterações staged"
    branch=$(manifest_value "$component" branch)
    commit=$(manifest_value "$component" commit)
    git -C "$target" fetch --prune origin "$branch"
    git -C "$target" cat-file -e "${commit}^{commit}" ||
      die "${component}: commit ${commit} não está disponível após fetch"
    git -C "$target" checkout --detach "$commit"
    printf '%s sincronizado em %s\n' "$component" "$commit"
  done
}

case "${1:-validate}" in
  validate) validate_manifest ;;
  sync) sync_repositories ;;
  ibge-values) ibge_values ;;
  cnes-values) cnes_values ;;
  *) die "uso: $0 [validate|sync|ibge-values|cnes-values]" ;;
esac
