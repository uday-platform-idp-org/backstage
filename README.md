# Backstage on Kubernetes with ArgoCD and Helm

Este projeto configura o Backstage no Kubernetes usando Helm Charts, ArgoCD e GitHub Actions.

## Estrutura do Projeto

```
.
├── helm-chart/                 # Helm Chart do Backstage
│   ├── Chart.yaml             
│   ├── values.yaml            # Valores padrão
│   └── templates/             # Templates Kubernetes
├── argocd/                    # Configurações ArgoCD
│   └── application.yaml       # Application ArgoCD
├── .github/workflows/         # GitHub Actions
│   └── deploy.yml            # Pipeline CI/CD
├── kustomization.yaml         # Kustomize (opcional)
└── README.md
```

## Pré-requisitos

1. **Cluster Kubernetes** com:
   - ArgoCD instalado
   - Istio Gateway API
   - Longhorn Storage (ou outro storage class)

2. **Secrets necessários no GitHub**:
   - `KUBECONFIG_STAGING`: Config do cluster staging
   - `KUBECONFIG_PRODUCTION`: Config do cluster produção
   - `SLACK_WEBHOOK_URL`: Webhook do Slack (opcional)

3. **Certificado TLS**:
   - Secret `backstage-tls-cert` no namespace backstage

## Instalação Manual

### 1. Clone o repositório
```bash
git clone https://github.com/your-username/backstage-k8s.git
cd backstage-k8s
```

### 2. Instale via Helm
```bash
# Instalar chart
helm install backstage helm-chart/ -n backstage --create-namespace

# Ou upgrade
helm upgrade backstage helm-chart/ -n backstage
```

### 3. Configure ArgoCD Application
```bash
kubectl apply -f argocd/application.yaml
```

## Configuração

### Valores Principais (values.yaml)

- **`backstage.image.tag`**: Tag da imagem do Backstage
- **`gateway.hostname`**: Hostname para acesso
- **`postgresql.storage.size`**: Tamanho do storage PostgreSQL
- **`secrets.*`**: Configurações base64 dos secrets

### Secrets

Os secrets são configurados em base64 no `values.yaml`:

```yaml
secrets:
  backstage:
    github:
      clientId: "base64_encoded_client_id"
      clientSecret: "base64_encoded_client_secret"
      token: "base64_encoded_github_token"
    argocd:
      token: "base64_encoded_argocd_token"
      username: "base64_encoded_username"
      password: "base64_encoded_password"
```

**Para gerar secrets em base64:**
```bash
echo -n "seu_valor" | base64
```

## Pipeline CI/CD

O GitHub Actions pipeline inclui:

1. **Lint e Validação**: Valida sintaxe do Helm Chart
2. **Security Scan**: Executa Trivy para vulnerabilidades
3. **Deploy Staging**: Deploy automático em PRs
4. **Deploy Production**: Deploy automático na branch main
5. **Notificações**: Notifica status no Slack

### Ambientes

- **Staging**: `backstage-staging.cloududay.com.br`
- **Production**: `backstage.cloududay.com.br`

## Comandos Úteis

### Helm Commands
```bash
# Validar templates
helm template backstage helm-chart/ --debug --dry-run

# Instalar/upgrade
helm upgrade --install backstage helm-chart/ -n backstage --create-namespace

# Ver valores renderizados
helm get values backstage -n backstage

# História de releases
helm history backstage -n backstage

# Rollback
helm rollback backstage 1 -n backstage
```

### ArgoCD Commands
```bash
# Sincronizar aplicação
argocd app sync backstage

# Ver status
argocd app get backstage

# Ver diferenças
argocd app diff backstage

# Logs da aplicação
argocd app logs backstage
```

### Kubernetes Commands
```bash
# Ver pods
kubectl get pods -n backstage

# Logs do Backstage
kubectl logs -f deployment/backstage -n backstage

# Port forward para testes locais
kubectl port-forward svc/backstage-service 7007:7007 -n backstage

# Ver eventos
kubectl get events -n backstage --sort-by=.metadata.creationTimestamp

# Verificar secrets
kubectl get secrets -n backstage
kubectl describe secret backstage-secrets -n backstage
```

## Troubleshooting

### PostgreSQL não inicia
```bash
# Verificar PVC
kubectl get pvc -n backstage

# Verificar logs
kubectl logs -f statefulset/postgres-backstage -n backstage

# Verificar storage class
kubectl get storageclass
```

### Backstage não conecta no PostgreSQL
```bash
# Verificar init container
kubectl describe pod backstage-xxx -n backstage

# Testar conectividade
kubectl exec -it deployment/backstage -n backstage -- /bin/bash
pg_isready -h postgres -p 5432 -U backstage_user
```

### Gateway/Ingress não funciona
```bash
# Verificar gateway
kubectl get gateway -n backstage
kubectl describe gateway backstage-gateway -n backstage

# Verificar HTTPRoute
kubectl get httproute -n backstage
kubectl describe httproute backstage-route -n backstage

# Verificar certificado TLS
kubectl get secret backstage-tls-cert -n backstage
```

### ArgoCD não sincroniza
```bash
# Verificar aplicação
kubectl get application backstage -n argocd
kubectl describe application backstage -n argocd

# Forçar sincronização
kubectl patch application backstage -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

## Customização

### Adicionar novos ambientes
1. Crie um novo arquivo `values-{ambiente}.yaml`
2. Adicione o ambiente no GitHub Actions workflow
3. Configure secrets específicos do ambiente

### Modificar recursos
Edite o `values.yaml`:
```yaml
backstage:
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
```

### Adicionar volumes extras
```yaml
backstage:
  extraVolumes:
    - name: config-volume
      configMap:
        name: backstage-config
  
  extraVolumeMounts:
    - name: config-volume
      mountPath: /app/config
```

## Monitoramento

### Metrics e Logs
- Logs: `kubectl logs -f deployment/backstage -n backstage`
- Metrics: Configure Prometheus/Grafana
- Health checks: `https://backstage.cloududay.com.br/api/healthcheck`

### Alertas recomendados
- Pod restart loops
- High memory/CPU usage
- Database connection failures
- SSL certificate expiration

## Segurança

### Recomendações
1. **Secrets**: Use External Secrets Operator ou Vault
2. **RBAC**: Configure roles mínimos necessários
3. **Network Policies**: Limite comunicação entre pods
4. **Pod Security Standards**: Aplique políticas de segurança
5. **Image Scanning**: Mantenha pipeline de security scan

### Network Policies exemplo
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backstage-netpol
  namespace: backstage
spec:
  podSelector:
    matchLabels:
      app: backstage
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: istio-system
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
```

## Contribuição

1. Fork o repositório
2. Crie uma branch para sua feature
3. Faça commit das mudanças
4. Abra um Pull Request
5. O pipeline rodará automaticamente

## Suporte

- **Issues**: Use o GitHub Issues
- **Documentação**: [Backstage.io](https://backstage.io)
- **ArgoCD**: [ArgoCD Docs](https://argo-cd.readthedocs.io)