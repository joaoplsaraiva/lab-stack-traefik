#!/usr/bin/env bash
# ==============================================================================
# Gera uma CA local ("Laboratorio Root CA") e um certificado de servidor
# wildcard *.DOMAIN com SANs explícitos para cada serviço.
#
# - Reaproveita a CA e a chave do servidor se já existirem (renovação segura:
#   clientes que já confiam na CA não precisam ser reconfigurados).
# - Para adicionar um novo serviço, inclua o nome em SERVICES e rode de novo.
# ==============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f .env ]] && set -a && source .env && set +a

DOMAIN="${DOMAIN:-domain.local}"
CERT_DIR="certs"
CA_DAYS=3650
CERT_DAYS=825
SERVICES=(traefik portainer whoami jaeger prometheus grafana)

mkdir -p "$CERT_DIR"

# ---------------- CA ----------------
if [[ ! -f "$CERT_DIR/ca.key" ]]; then
  echo ">> Criando CA local"
  openssl genrsa -out "$CERT_DIR/ca.key" 4096
  openssl req -x509 -new -nodes -key "$CERT_DIR/ca.key" -sha256 -days "$CA_DAYS" \
    -subj "/C=BR/O=Laboratorio/CN=Laboratorio Root CA" \
    -out "$CERT_DIR/ca.crt"
else
  echo ">> CA existente reaproveitada"
fi

# ---------------- Chave do servidor ----------------
if [[ ! -f "$CERT_DIR/server.key" ]]; then
  echo ">> Criando chave do servidor"
  openssl genrsa -out "$CERT_DIR/server.key" 2048
else
  echo ">> Chave do servidor existente reaproveitada"
fi

# ---------------- server.cnf ----------------
{
  cat <<CNF
[req]
distinguished_name = dn
req_extensions     = v3_req
prompt             = no

[dn]
C  = BR
O  = Laboratorio
CN = *.${DOMAIN}

[v3_req]
basicConstraints = CA:FALSE
keyUsage         = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName   = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
CNF
  i=3
  for s in "${SERVICES[@]}"; do
    echo "DNS.${i} = ${s}.${DOMAIN}"
    i=$((i + 1))
  done
} > "$CERT_DIR/server.cnf"

# ---------------- CSR + assinatura ----------------
echo ">> Gerando CSR e assinando com a CA"
openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" -config "$CERT_DIR/server.cnf"
openssl x509 -req -in "$CERT_DIR/server.csr" \
  -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
  -out "$CERT_DIR/server.crt" -days "$CERT_DAYS" -sha256 \
  -extfile "$CERT_DIR/server.cnf" -extensions v3_req

chmod 600 "$CERT_DIR"/*.key
chmod 644 "$CERT_DIR"/*.crt

echo ">> Validação"
openssl verify -CAfile "$CERT_DIR/ca.crt" "$CERT_DIR/server.crt"
openssl x509 -in "$CERT_DIR/server.crt" -noout -subject -issuer -dates -ext subjectAltName

cat <<MSG

Pronto. Próximos passos:
  1) Confiar na CA no cliente (Ubuntu/Debian):
       sudo cp $CERT_DIR/ca.crt /usr/local/share/ca-certificates/laboratorio-root-ca.crt
       sudo update-ca-certificates
     (Fedora/RHEL: /etc/pki/ca-trust/source/anchors/ + sudo update-ca-trust)
     No navegador, importe certs/ca.crt como Autoridade Certificadora.
  2) Recarregar o certificado no Traefik:
       docker compose restart traefik
MSG
