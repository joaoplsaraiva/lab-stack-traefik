# Atalhos do projeto. Execute `make help` para listar.
.DEFAULT_GOAL := help
COMPOSE := docker compose

.PHONY: help init certs htpasswd hosts config up down restart ps logs pull test

help: ## Lista os comandos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

init: ## Cria o .env a partir do exemplo
	@test -f .env || (cp .env.example .env && chmod 600 .env && echo ".env criado — edite as senhas")

certs: ## Gera/renova CA local e certificado wildcard
	./scripts/gen-certs.sh

htpasswd: ## Gera o arquivo de BasicAuth
	./scripts/gen-htpasswd.sh

hosts: ## Mostra as entradas para /etc/hosts
	./scripts/hosts.sh

config: ## Valida o docker-compose.yml
	$(COMPOSE) config --quiet && echo "Compose OK"

pull: ## Baixa as imagens
	$(COMPOSE) pull

up: config ## Sobe a stack
	$(COMPOSE) up -d

down: ## Derruba a stack (mantém volumes)
	$(COMPOSE) down

restart: ## Reinicia a stack
	$(COMPOSE) restart

ps: ## Status dos containers
	$(COMPOSE) ps

logs: ## Logs (ex.: make logs s=traefik)
	$(COMPOSE) logs -f --tail=100 $(s)

test: ## Executa os testes de fumaça
	./scripts/smoke-test.sh
