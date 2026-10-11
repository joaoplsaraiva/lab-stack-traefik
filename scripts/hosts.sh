#!/usr/bin/env bash
# Exibe as entradas para /etc/hosts da máquina cliente.
# Uso: ./scripts/hosts.sh | sudo tee -a /etc/hosts
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] && set -a && source .env && set +a
DOMAIN="${DOMAIN:-domain.local}"
HOST_IP="${HOST_IP:-192.168.56.6}"
for s in traefik portainer whoami jaeger prometheus grafana; do
  printf '%s\t%s.%s\n' "$HOST_IP" "$s" "$DOMAIN"
done
