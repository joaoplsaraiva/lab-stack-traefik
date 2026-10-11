# Evolução incremental do laboratório

O projeto foi construído **um componente por vez**, validando cada etapa antes da próxima. Assim, quando algo quebra, sabemos exatamente qual mudança introduziu o problema. Este documento registra essa trilha e pode ser seguido como roteiro de estudo.

| # | Etapa | O que foi validado | Status |
|---|-------|--------------------|--------|
| 1 | Traefik mínimo | Docker provider, `exposedByDefault=false`, docker.sock `:ro`, dashboard local | ✅ |
| 2 | Whoami atrás do Traefik | Labels → Router → Service, rede dedicada `proxy`, app **sem porta publicada** | ✅ |
| 3 | Roteamento por hostname | `Host()` rule com `*.domain.local` resolvido via `/etc/hosts` | ✅ |
| 4 | Dashboard pelo próprio Traefik | Router para `api@internal`, remoção da porta 8080 | ✅ |
| 5 | Portainer | Acesso apenas via Traefik (sem `9000:9000`), volume persistente | ✅ |
| 6 | Hardening do dashboard | `api.insecure=false`, BasicAuth com hash bcrypt | ✅ |
| 7 | Security Headers | `nosniff`, `X-Frame-Options: DENY`, Referrer/Permissions Policy, CSP | ✅ |
| 8 | Rate Limit | Middlewares independentes: whoami (10 r/s, burst 20), portainer (20 r/s, burst 40), dashboard | ✅ |
| 9 | HTTPS com CA local | CA própria, certificado wildcard com SANs, redirect HTTP → HTTPS | ✅ |
| 10 | HSTS | `max-age=31536000`, sem `includeSubDomains`/`preload` nesta fase | ✅ |
| 11 | TLS Hardening | TLS ≥ 1.2, cipher suites AEAD com Forward Secrecy, `sniStrict` | ✅ |
| 12 | Docker Socket Proxy | Traefik sem docker.sock; API exposta só com `CONTAINERS/EVENTS/PING/VERSION` | ✅ |
| 13 | Tracing | Traefik → OpenTelemetry (OTLP/HTTP) → Jaeger v2 | ✅ |
| 14 | Métricas | Traefik → Prometheus (entrypoint interno `:8082`) | ✅ |
| 15 | Logs | Docker → Socket Proxy → Alloy → Loki (labels `platform`, `service_name`) | ✅ |
| 16 | Grafana | Data sources provisionados (Prometheus, Loki, Jaeger) | ✅ |
| 17 | Dashboards v1 → v3 | Status, requisições, erros, latência, logs e traces no mesmo painel | ✅ |
| 18 | Let's Encrypt | DNS Challenge para ambientes internos / HTTP Challenge para públicos | ⏳ |
| 19 | Socket Proxy para o Portainer | Ou Portainer Agent, reduzindo o acesso RW ao docker.sock | ⏳ |
| 20 | Alertas | Alertmanager / Grafana Alerting para erro 5xx, latência e serviços DOWN | ⏳ |

## Testes usados em cada etapa

```bash
# Antes de qualquer `up`
docker compose config

# Roteamento sem DNS (forçando o header Host)
curl -H "Host: whoami.domain.local" http://192.168.56.6

# Rate Limit — devem aparecer respostas 429
for i in {1..100}; do
  curl -s -o /dev/null -w "Request $i -> HTTP %{http_code}\n" https://whoami.domain.local
done

# Porta 8080 não deve estar escutando
sudo ss -lntp | grep -E ':80|:443|:8080'

# Montagens do Traefik — não deve aparecer /var/run/docker.sock
docker inspect traefik --format '{{range .Mounts}}{{println .Source " -> " .Destination " RW=" .RW}}{{end}}'

# Quem está em cada rede
docker network inspect socket-proxy --format '{{range .Containers}}{{println .Name}}{{end}}'
```
