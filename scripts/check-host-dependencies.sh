#!/usr/bin/env bash
set -Eeuo pipefail

required_commands=(
  bash
  base64
  curl
  date
  docker
  git
  awk
  grep
  mktemp
  sed
  ss
  stat
  tr
)

missing=()
for command_name in "${required_commands[@]}"; do
  command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done

if ((${#missing[@]} > 0)); then
  printf 'Dependências ausentes no host: %s\n' "${missing[*]}" >&2
  exit 1
fi

docker compose version >/dev/null || {
  printf 'Docker Compose v2 não está disponível no host.\n' >&2
  exit 1
}

printf 'Dependências do host disponíveis; Docker Compose: '
docker compose version
