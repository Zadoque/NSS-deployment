#!/bin/sh
set -eu
network="nss-proxy-test-$$"
caddy="${network}-caddy"
backend="${network}-backend"
tmp=$(mktemp -d)
trap 'docker rm -f "$caddy" "$backend" >/dev/null 2>&1 || true; docker network rm "$network" >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
cat > "$tmp/echo.py" <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        value = self.headers.get('X-Forwarded-For', '') + '|' + self.headers.get('X-Request-Id', '')
        self.wfile.write(value.encode())
HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
PY
docker network create "$network" >/dev/null
gateway=$(docker network inspect -f '{{(index .IPAM.Config 0).Gateway}}' "$network")
sed "s#172.30.254.1/32#${gateway}/32#" "$PWD/caddy/Caddyfile" > "$tmp/Caddyfile"
docker run -d --name "$backend" --network "$network" --network-alias java -v "$tmp/echo.py:/tmp/echo.py:ro" --entrypoint python "${PROXY_TEST_IMAGE:-python:3.12-alpine}" /tmp/echo.py >/dev/null
docker run -d --name "$caddy" --network "$network" -p 127.0.0.1::80 -v "$tmp/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2-alpine >/dev/null
port=$(docker port "$caddy" 80/tcp | sed 's/.*://')
result=''
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    result=$(curl -fsS -H 'X-Forwarded-For: 198.51.100.1, 203.0.113.42' -H 'X-Request-Id: proxy-test-42' "http://127.0.0.1:$port/api/test" 2>/dev/null) && break
    sleep 1
done
[ "$result" = '203.0.113.42|proxy-test-42' ] || { printf 'Headers incorretos: %s\n' "$result" >&2; exit 1; }
printf 'Proxy selecionou o último IP confiável e preservou X-Request-Id.\n'
