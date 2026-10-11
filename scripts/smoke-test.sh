#!/usr/bin/env bash
# ==============================================================================
# Testes rápidos de fumaça da stack. Requer a CA confiável no cliente e
# entradas no /etc/hosts. Uso: ./scripts/smoke-test.sh
# ==============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] && set -a && source .env && set +a
DOMAIN="${DOMAIN:-domain.local}"

ok()   { printf '  \e[32m✔\e[0m %s\n' "$1"; }
fail() { printf '  \e[31m✘\e[0m %s\n' "$1"; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

echo "== Redirect HTTP -> HTTPS"
c=$(code "http://whoami.${DOMAIN}")
[[ "$c" == "301" || "$c" == "308" ]] && ok "whoami HTTP -> $c" || fail "whoami HTTP -> $c"

echo "== Rotas HTTPS públicas"
c=$(code "https://whoami.${DOMAIN}");    [[ "$c" == "200" ]] && ok "whoami -> $c"    || fail "whoami -> $c"
c=$(code "https://portainer.${DOMAIN}"); [[ "$c" == "200" ]] && ok "portainer -> $c" || fail "portainer -> $c"

echo "== Rotas protegidas por BasicAuth (esperado 401 sem credencial)"
for s in traefik jaeger prometheus grafana; do
  path=""; [[ "$s" == "traefik" ]] && path="/dashboard/"
  c=$(code "https://${s}.${DOMAIN}${path}")
  [[ "$c" == "401" ]] && ok "$s -> $c" || fail "$s -> $c"
done

echo "== Security headers"
h=$(curl -sI "https://whoami.${DOMAIN}")
for hdr in strict-transport-security x-content-type-options x-frame-options referrer-policy permissions-policy content-security-policy; do
  grep -qi "^${hdr}:" <<<"$h" && ok "$hdr" || fail "$hdr ausente"
done

echo "== TLS: TLS 1.1 deve ser recusado"
if openssl s_client -connect "whoami.${DOMAIN}:443" -servername "whoami.${DOMAIN}" -tls1_1 </dev/null >/dev/null 2>&1; then
  fail "TLS 1.1 aceito"
else
  ok "TLS 1.1 recusado"
fi

echo "== Portas publicadas no host (esperado somente 80 e 443)"
docker compose ps --format '{{.Name}}\t{{.Ports}}' | grep -E '0\.0\.0\.0|\[::\]' || true
