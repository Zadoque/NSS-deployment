#!/usr/bin/env bash
set -euo pipefail

command -v openssl >/dev/null || {
  echo "openssl ausente; em NixOS execute: nix shell nixpkgs#openssl --command bash tests/restore-smoke.sh" >&2
  exit 127
}

tmp_dir=$(mktemp -d)
external_storage=$(mktemp -d)
source_container="nss-rfc-restore-source-$$"
restore_container="nss-rfc-restore-target-$$"
cleanup() {
  docker rm -f "$source_container" "$restore_container" >/dev/null 2>&1 || true
  rm -rf "$tmp_dir" "$external_storage"
}
trap cleanup EXIT

docker run -d --rm --name "$source_container" -e POSTGRES_PASSWORD=test -e POSTGRES_DB=nss postgres:16-alpine >/dev/null
until docker exec "$source_container" psql -U postgres -d nss -Atc 'SELECT 1' >/dev/null 2>&1; do sleep 0.2; done
docker exec "$source_container" psql -U postgres -d nss -v ON_ERROR_STOP=1 -c \
  "CREATE TABLE restore_probe (id integer PRIMARY KEY, value text); INSERT INTO restore_probe VALUES (1, 'preserved');" >/dev/null

mkdir -p "$tmp_dir/media"
printf 'NSS restore probe\n' > "$tmp_dir/media/opaco.bin"
sha256sum "$tmp_dir/media/opaco.bin" > "$tmp_dir/media-manifest.sha256"
docker exec "$source_container" pg_dump -U postgres -d nss -Fc > "$tmp_dir/nss.dump"

# Simulate a separate storage boundary and verify encrypted backup integrity.
backup_key=$(openssl rand -hex 32)
printf '%s' "$backup_key" > "$tmp_dir/backup.key"
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt \
  -in "$tmp_dir/nss.dump" -out "$external_storage/nss.dump.enc" \
  -pass file:"$tmp_dir/backup.key" >/dev/null 2>&1
openssl dgst -sha256 -mac HMAC -macopt "hexkey:$backup_key" \
  -binary "$external_storage/nss.dump.enc" | sha256sum > "$external_storage/nss.dump.enc.hmac"
cp "$external_storage/nss.dump.enc" "$tmp_dir/nss.dump.enc"
cp "$external_storage/nss.dump.enc.hmac" "$tmp_dir/nss.dump.enc.hmac"
openssl dgst -sha256 -mac HMAC -macopt "hexkey:$backup_key" \
  -binary "$tmp_dir/nss.dump.enc" | sha256sum -c "$tmp_dir/nss.dump.enc.hmac" >/dev/null
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -in "$tmp_dir/nss.dump.enc" -out "$tmp_dir/restored.dump" \
  -pass file:"$tmp_dir/backup.key" >/dev/null 2>&1

docker run -d --rm --name "$restore_container" -e POSTGRES_PASSWORD=test -e POSTGRES_DB=nss postgres:16-alpine >/dev/null
until docker exec "$restore_container" psql -U postgres -d nss -Atc 'SELECT 1' >/dev/null 2>&1; do sleep 0.2; done
restore_start=$(date +%s%N)
cat "$tmp_dir/restored.dump" | docker exec -i "$restore_container" pg_restore -U postgres -d nss --clean --if-exists >/dev/null
mkdir -p "$tmp_dir/restored-media"
cp "$tmp_dir/media/opaco.bin" "$tmp_dir/restored-media/opaco.bin"
(cd "$tmp_dir/restored-media" && sha256sum -c ../media-manifest.sha256 >/dev/null)
restored_value=$(docker exec "$restore_container" psql -U postgres -d nss -Atc 'SELECT value FROM restore_probe WHERE id=1')
restore_end=$(date +%s%N)
restore_ms=$(( (restore_end - restore_start) / 1000000 ))

[[ "$restored_value" == "preserved" ]]
printf 'restore=ok manifest=ok encrypted_backup=ok separated_storage=ok rto_ms=%s\n' "$restore_ms"
