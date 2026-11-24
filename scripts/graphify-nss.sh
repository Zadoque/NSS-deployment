#!/usr/bin/env bash
set -Eeuo pipefail

graphify_version="0.9.114"
workspace_root="${NSS_GRAPHIFY_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
central_dir="$workspace_root/.graphify-central"
central_graph="$central_dir/graph.json"

repo_names=(
  NSS-database
  Site-Sala-de-Situa-o-de-Saude-Java
  nss-front-end
  nss-pipeline
  nss-deployment
  nss-NixOS-Configuration
)

run_graphify() {
  if command -v graphify >/dev/null 2>&1; then
    graphify "$@"
  else
    uvx --from "graphifyy[mcp,sql]==$graphify_version" graphify "$@"
  fi
}

run_graphify_mcp() {
  if command -v graphify-mcp >/dev/null 2>&1; then
    graphify-mcp "$@"
  else
    uvx --from "graphifyy[mcp,sql]==$graphify_version" graphify-mcp "$@"
  fi
}

repo_graphs=()
for repo_name in "${repo_names[@]}"; do
  repo_path="$workspace_root/$repo_name"
  if [[ ! -d "$repo_path/.git" ]]; then
    printf 'Repositório NSS ausente: %s\n' "$repo_path" >&2
    exit 1
  fi
  repo_graphs+=("$repo_path/graphify-out/graph.json")
done

build_graphs() {
  local semantic="$1"
  for repo_name in "${repo_names[@]}"; do
    repo_path="$workspace_root/$repo_name"
    printf '\n==> Graphify %s\n' "$repo_name"
    if [[ "$semantic" == "1" ]]; then
      run_graphify extract "$repo_path"
    else
      run_graphify extract "$repo_path" --code-only
    fi
  done
}

merge_graphs() {
  mkdir -p "$central_dir"
  run_graphify merge-graphs "${repo_graphs[@]}" --out "$central_graph"
  test -s "$central_graph"
  printf 'Grafo central: %s\n' "$central_graph"
}

stats() {
  for graph_path in "${repo_graphs[@]}" "$central_graph"; do
    test -s "$graph_path"
    printf '%s: ' "$graph_path"
    wc -c < "$graph_path"
  done
}

case "${1:-build}" in
  build)
    build_graphs "${2:-0}"
    merge_graphs
    stats
    ;;
  semantic)
    build_graphs 1
    merge_graphs
    stats
    ;;
  merge)
    merge_graphs
    stats
    ;;
  stats)
    stats
    ;;
  serve)
    test -s "$central_graph"
    run_graphify_mcp "$central_graph"
    ;;
  *)
    printf 'Uso: %s {build|semantic|merge|stats|serve}\n' "$0" >&2
    exit 2
    ;;
esac
