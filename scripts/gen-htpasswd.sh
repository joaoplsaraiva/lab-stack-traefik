#!/usr/bin/env bash
# ==============================================================================
# Gera traefik/auth/htpasswd (bcrypt) usado pelo middleware traefik-auth.
# Usar um arquivo evita o escape de "$" -> "$$" exigido em labels do Compose.
# ==============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f .env ]] && set -a && source .env && set +a

USER_NAME="${1:-${BASIC_AUTH_USER:-admin}}"
OUT="traefik/auth/htpasswd"

if command -v htpasswd >/dev/null 2>&1; then
  htpasswd -B -c "$OUT" "$USER_NAME"
else
  echo ">> htpasswd não encontrado localmente; usando container httpd:alpine"
  read -rsp "Senha para ${USER_NAME}: " PASS; echo
  docker run --rm httpd:2.4-alpine htpasswd -nbB "$USER_NAME" "$PASS" > "$OUT"
fi

chmod 640 "$OUT"
echo ">> Arquivo gerado: $OUT"
