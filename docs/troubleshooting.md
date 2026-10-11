# Troubleshooting

Problemas reais encontrados durante a construção do laboratório e como foram resolvidos.

## `curl: (6) Could not resolve host: jaeger.domain.local`

É **resolução de nome**, não certificado. Adicione o hostname ao `/etc/hosts` da máquina cliente (e da VM, se testar de dentro dela):

```bash
./scripts/hosts.sh | sudo tee -a /etc/hosts
getent hosts jaeger.domain.local
```

## Certificado não confiável / erro de SAN

- O que o cliente precisa confiar é a **CA** (`certs/ca.crt`), não o certificado do servidor.
- Ao adicionar um serviço novo, inclua-o em `SERVICES` no `scripts/gen-certs.sh` e rode novamente. A CA e a chave são reaproveitadas, então os clientes não precisam ser reconfigurados.
- Depois, `docker compose restart traefik` e confira o certificado servido:

```bash
openssl s_client -connect grafana.domain.local:443 -servername grafana.domain.local </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

## BasicAuth não funciona com hash em label

Em labels do Docker Compose, cada `$` do hash bcrypt precisa ser escrito como `$$`. Este projeto evita o problema usando `basicauth.usersfile` com o arquivo `traefik/auth/htpasswd` (gerado por `make htpasswd`).

## `HTTP 405 Method Not Allowed` em `http://jaeger:4318/v1/traces`

É **esperado**. O endpoint OTLP aceita apenas `POST`; um `GET` de teste retornando 405 prova que o Jaeger está acessível pela rede do Traefik.

## Grafana mostra "No logs found" com o data source OK

Siga o caminho dos dados de trás para frente:

```bash
# 1. O Loki está pronto? (503 = ingester com problema)
docker run --rm --network monitoring busybox wget -S -O- http://loki:3100/ready

# 2. O Alloy enxerga os containers via socket-proxy?
docker run --rm --network socket-proxy busybox wget -qO- http://socket-proxy:2375/containers/json

# 3. Gere um log controlado e consulte direto no Loki
docker run -d --name loki-test --network monitoring busybox \
  sh -c 'while true; do echo "LOKI-TEST $(date -Iseconds)"; sleep 5; done'
sleep 15
docker run --rm --network monitoring busybox wget -qO- \
  'http://loki:3100/loki/api/v1/query_range?query=%7Bservice_name%3D%22loki-test%22%7D&limit=20&direction=backward'
docker rm -f loki-test
```

### Caso real: Loki com `/ready` 503, `push` 500 e "Ingester is shutting down"

O container aparecia como `Up`, mas o ingester interno estava parado — o Loki depende do filesystem para chunks, TSDB e compactor. A causa foi **falta de espaço em disco** na VM. Resolvido removendo imagens não utilizadas:

```bash
df -h
docker system df
docker image prune -a
docker compose restart loki
```

Dica: monitore `df -h` e mantenha a retenção do Loki (`retention_period`) e do Prometheus (`PROMETHEUS_RETENTION`) adequadas ao disco disponível.

## Traefik não descobre containers após migrar para o Socket Proxy

```bash
docker logs traefik --since 2m | grep -iE 'docker|socket-proxy|refused'
```

Confirme que o Traefik está na rede `socket-proxy` e que o endpoint é `tcp://socket-proxy:2375`.
