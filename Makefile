# Makefile para Backstage Kubernetes

.PHONY: help lint validate install upgrade uninstall status logs port-forward clean

NAMESPACE ?= backstage
RELEASE_NAME ?= backstage
CHART_PATH ?= helm-chart

help: ## Mostra este help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint: ## Executa lint no Helm Chart
	helm lint $(CHART_PATH)

validate: ## Valida templates do Helm Chart
	helm template $(RELEASE_NAME) $(CHART_PATH) --debug --dry-run

dependency-update: ## Atualiza dependências do chart
	helm dependency update $(CHART_PATH)

install: ## Instala o Backstage
	helm install $(RELEASE_NAME) $(CHART_PATH) -n $(NAMESPACE) --create-namespace

upgrade: ## Faz upgrade do Backstage
	helm upgrade $(RELEASE_NAME) $(CHART_PATH) -n $(NAMESPACE)

uninstall: ## Desinstala o Backstage
	helm uninstall $(RELEASE_NAME) -n $(NAMESPACE)

status: ## Mostra status da instalação
	@echo "=== Helm Status ==="
	helm status $(RELEASE_NAME) -n $(NAMESPACE)
	@echo "\n=== Pods Status ==="
	kubectl get pods -n $(NAMESPACE)
	@echo "\n=== Services ==="
	kubectl get svc -n $(NAMESPACE)
	@echo "\n=== Ingress/Gateway ==="
	kubectl get gateway,httproute -n $(NAMESPACE)

logs: ## Mostra logs do Backstage
	kubectl logs -f deployment/$(RELEASE_NAME) -n $(NAMESPACE)

logs-postgres: ## Mostra logs do PostgreSQL
	kubectl logs -f statefulset/postgres-backstage -n $(NAMESPACE)

port-forward: ## Port forward para acesso local
	kubectl port-forward svc/$(RELEASE_NAME)-service 7007:7007 -n $(NAMESPACE)

shell: ## Acessa shell do pod Backstage
	kubectl exec -it deployment/$(RELEASE_NAME) -n $(NAMESPACE) -- /bin/bash

shell-postgres: ## Acessa shell do PostgreSQL
	kubectl exec -it statefulset/postgres-backstage -n $(NAMESPACE) -- /bin/bash

events: ## Mostra eventos do namespace
	kubectl get events -n $(NAMESPACE) --sort-by=.metadata.creationTimestamp

describe-pods: ## Descreve todos os pods
	kubectl describe pods -n $(NAMESPACE)

secrets: ## Lista secrets
	kubectl get secrets -n $(NAMESPACE)

describe-secret: ## Descreve secret do Backstage
	kubectl describe secret backstage-secrets -n $(NAMESPACE)

clean: ## Remove namespace completo
	kubectl delete namespace $(NAMESPACE)

# ArgoCD Commands
argocd-sync: ## Sincroniza aplicação no ArgoCD
	argocd app sync backstage

argocd-status: ## Status da aplicação no ArgoCD
	argocd app get backstage

argocd-diff: ## Diferenças no ArgoCD
	argocd app diff backstage

argocd-logs: ## Logs do ArgoCD
	argocd app logs backstage

# Development Commands
dev-setup: ## Setup ambiente de desenvolvimento
	@echo "Setting up development environment..."
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm dependency update $(CHART_PATH)

dev-install: dev-setup install ## Setup + Install para desenvolvimento

dev-upgrade: lint validate upgrade ## Lint + Validate + Upgrade para desenvolvimento

dev-reset: uninstall clean dev-install ## Reset completo para desenvolvimento

# Backup Commands
backup-postgres: ## Backup do PostgreSQL
	kubectl exec statefulset/postgres-backstage -n $(NAMESPACE) -- pg_dump -U backstage_user backstage_db > backup-$(shell date +%Y%m%d-%H%M%S).sql

# Monitoring Commands
watch-pods: ## Watch pods em tempo real
	watch kubectl get pods -n $(NAMESPACE)

watch-all: ## Watch todos recursos
	watch kubectl get all -n $(NAMESPACE)

top-pods: ## Resource usage dos pods
	kubectl top pods -n $(NAMESPACE)

# Security Commands
security-scan: ## Executa scan de segurança com Trivy
	trivy fs helm-chart/

# Utility Commands
generate-secrets: ## Gera exemplos de secrets em base64
	@echo "=== Gerando secrets de exemplo ==="
	@echo "POSTGRES_USER: $$(echo -n 'backstage_user' | base64)"
	@echo "POSTGRES_DB: $$(echo -n 'backstage_db' | base64)"
	@echo "POSTGRES_PASSWORD: $$(echo -n 'password' | base64)"
	@echo "GITHUB_TOKEN: $$(echo -n 'ghp_your_token_here' | base64)"
	@echo "ARGOCD_USERNAME: $$(echo -n 'admin' | base64)"

values-diff: ## Compara values com defaults
	helm template $(RELEASE_NAME) $(CHART_PATH) --show-only templates/backstage-deployment.yaml > /tmp/current-deploy.yaml
	helm template $(RELEASE_NAME) $(CHART_PATH) --show-only templates/backstage-deployment.yaml --set backstage.replicas=2 > /tmp/new-deploy.yaml
	diff /tmp/current-deploy.yaml /tmp/new-deploy.yaml || true

test-connection: ## Testa conectividade
	@echo "Testing PostgreSQL connection..."
	kubectl exec deployment/$(RELEASE_NAME) -n $(NAMESPACE) -- pg_isready -h postgres -p 5432 -U backstage_user
	@echo "Testing Backstage health..."
	kubectl exec deployment/$(RELEASE_NAME) -n $(NAMESPACE) -- curl -f http://localhost:7007/api/healthcheck

# Documentation
docs-serve: ## Serve documentação local
	@echo "Serving documentation at http://localhost:8000"
	@python3 -m http.server 8000 2>/dev/null || python -m SimpleHTTPServer 8000