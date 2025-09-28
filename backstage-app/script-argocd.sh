#!/bin/bash

# Script para ajudar alunos a encontrar nomes corretos das aplicações ArgoCD
# Uso: ./debug-argocd-names.sh

echo "🔍 Debug: Nomes das Aplicações ArgoCD"
echo "======================================"

# Configurações (ajuste conforme necessário)
ARGOCD_SERVER="argocd.cloududay.com.br:9092"
ARGOCD_USERNAME="admin"
ARGOCD_PASSWORD="XUa4fni1sqHOy6FP"

echo "📡 Conectando ao ArgoCD..."
echo "Servidor: $ARGOCD_SERVER"

# Método 1: Via API (mais confiável)
echo ""
echo "🔄 Método 1: Buscando via API..."

# Fazer login e obter token
TOKEN_RESPONSE=$(curl -s -k -X POST \
  "https://$ARGOCD_SERVER/api/v1/session" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ARGOCD_USERNAME\",\"password\":\"$ARGOCD_PASSWORD\"}")

if [[ $TOKEN_RESPONSE == *"token"* ]]; then
    TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    echo "✅ Login realizado com sucesso!"
    
    # Buscar aplicações
    echo ""
    echo "📋 Lista de Aplicações Encontradas:"
    echo "=================================="
    
    APPS_RESPONSE=$(curl -s -k -H "Authorization: Bearer $TOKEN" \
      "https://$ARGOCD_SERVER/api/v1/applications")
    
    # Extrair nomes das aplicações
    echo "$APPS_RESPONSE" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | while read app_name; do
        echo "   📱 $app_name"
    done
    
    echo ""
    echo "💡 Como usar no Backstage:"
    echo "========================="
    echo "Para cada aplicação acima, adicione no seu catalog-info.yaml:"
    echo ""
    echo "metadata:"
    echo "  annotations:"
    echo "    argocd/app-name: NOME_DA_APLICACAO"
    echo ""
    echo "Exemplo:"
    echo "metadata:"
    echo "  annotations:"
    echo "    argocd/app-name: $(echo "$APPS_RESPONSE" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -1)"
    
else
    echo "❌ Erro no login. Verifique:"
    echo "   - URL do servidor: $ARGOCD_SERVER"
    echo "   - Username: $ARGOCD_USERNAME" 
    echo "   - Password: [verificar se está correto]"
    echo "   - Certificado SSL (pode precisar de --insecure)"
fi

echo ""
echo "🔍 Método 2: Verificação Manual"
echo "==============================="
echo "1. Acesse: https://$ARGOCD_SERVER"
echo "2. Faça login com: $ARGOCD_USERNAME / [sua senha]"
echo "3. Na tela principal, veja os nomes das aplicações"
echo "4. Use EXATAMENTE o nome que aparece na interface"

echo ""
echo "📝 Troubleshooting:"
echo "=================="
echo "• Se não aparecer aplicações: verifique se existem apps no ArgoCD"
echo "• Se der erro de SSL: adicione 'skipTLSVerify: true' no backstage"
echo "• Se não conectar: verifique firewall e URL"
echo "• Se card ficar vazio: verifique se backend plugin está instalado"

echo ""
echo "✅ Script finalizado!"
