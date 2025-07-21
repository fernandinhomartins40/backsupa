#!/bin/bash
# Script para configurar o repositório na VPS

# Diretório do projeto
PROJECT_DIR="/opt/backsupa"

# Criar diretório se não existir
mkdir -p $PROJECT_DIR

# Entrar no diretório
cd $PROJECT_DIR

# Clonar repositório se não existir
if [ ! -d ".git" ]; then
    git clone https://github.com/fernandinhomartins40/backsupa.git .
fi

# Configurar git para pull automático
git config --global --add safe.directory $PROJECT_DIR

# Verificar se docker-compose.yml existe
if [ ! -f "docker-compose.yml" ]; then
    echo "docker-compose.yml não encontrado!"
    exit 1
fi

# Dar permissão ao script
chmod +x scripts/setup-vps-repo.sh

echo "Setup concluído! Diretório: $PROJECT_DIR"
