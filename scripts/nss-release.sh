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
  *) die "uso: $0 [validate|sync]" ;;
esac
