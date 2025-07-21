#!/bin/bash
# Script para testar a estrutura do build antes do deploy

echo "🔍 Testando estrutura do Docker Compose..."

# Navegar para diretório docker
cd docker || exit 1

# Verificar se docker-compose.production.yml existe
if [ ! -f "docker-compose.production.yml" ]; then
    echo "❌ docker-compose.production.yml não encontrado"
    exit 1
fi

# Verificar contextos de build
echo "📁 Verificando contextos de build..."

contexts=("./control-api" "./billing-system/billing-api" "./billing-system/marketplace")
for context in "${contexts[@]}"; do
    if [ ! -d "$context" ]; then
        echo "❌ Contexto $context não encontrado"
        exit 1
    fi
    
    if [ ! -f "$context/Dockerfile" ]; then
        echo "❌ Dockerfile não encontrado em $context"
        exit 1
    fi
    
    if [ ! -f "$context/package.json" ]; then
        echo "❌ package.json não encontrado em $context"
        exit 1
    fi
    
    echo "✅ Contexto $context válido"
done

# Verificar volumes necessários
echo "💾 Verificando arquivos de volume..."

volumes=("./master-db-setup.sql" "./billing-system/billing-schema.sql" "./nginx-config/nginx.conf")
for volume in "${volumes[@]}"; do
    if [ ! -f "$volume" ]; then
        echo "❌ Volume $volume não encontrado"
        exit 1
    fi
    echo "✅ Volume $volume encontrado"
done

# Verificar se todas as portas são diferentes
echo "🔌 Verificando portas..."
ports=$(grep -o '[0-9]\+:[0-9]\+' docker-compose.production.yml | cut -d':' -f1 | sort)
unique_ports=$(echo "$ports" | uniq)

if [ "$(echo "$ports" | wc -l)" != "$(echo "$unique_ports" | wc -l)" ]; then
    echo "❌ Conflito de portas detectado"
    exit 1
fi

echo "✅ Todas as portas são únicas"

echo "🎉 Estrutura do build válida! Pronto para deploy."