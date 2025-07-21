#!/bin/bash
# apply_template.sh - Aplicar templates de projeto específicos
# Uso: ./apply_template.sh <template> <instance_dir> <db_password>

TEMPLATE=$1
INSTANCE_DIR=$2
DB_PASSWORD=$3

if [ -z "$TEMPLATE" ] || [ -z "$INSTANCE_DIR" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Uso: $0 <template> <instance_dir> <db_password>"
    exit 1
fi

TEMPLATES_DIR="$(dirname "$0")/templates"
DB_URL="postgresql://postgres:$DB_PASSWORD@localhost:5432/postgres"

echo "📋 Aplicando template: $TEMPLATE"

case $TEMPLATE in
    "blank")
        echo "   Projeto em branco - sem dados iniciais"
        ;;
        
    "todo")
        echo "   Aplicando schema de Todo App..."
        if [ -f "$TEMPLATES_DIR/todo-schema.sql" ]; then
            # Aguardar DB estar pronto
            sleep 10
            docker exec "${INSTANCE_ID}_db" psql -U postgres -d postgres -f "/tmp/todo-schema.sql"
        fi
        ;;
        
    "blog")
        echo "   Aplicando schema de Blog/CMS..."
        if [ -f "$TEMPLATES_DIR/blog-schema.sql" ]; then
            sleep 10
            docker exec "${INSTANCE_ID}_db" psql -U postgres -d postgres -f "/tmp/blog-schema.sql"
        fi
        ;;
        
    "ecommerce")
        echo "   Aplicando schema de E-commerce..."
        if [ -f "$TEMPLATES_DIR/ecommerce-schema.sql" ]; then
            sleep 10
            docker exec "${INSTANCE_ID}_db" psql -U postgres -d postgres -f "/tmp/ecommerce-schema.sql"
        fi
        ;;
        
    "saas")
        echo "   Aplicando schema de SaaS Platform..."
        if [ -f "$TEMPLATES_DIR/saas-schema.sql" ]; then
            sleep 10
            docker exec "${INSTANCE_ID}_db" psql -U postgres -d postgres -f "/tmp/saas-schema.sql"
        fi
        ;;
        
    "mobile-app")
        echo "   Aplicando schema para App Mobile..."
        if [ -f "$TEMPLATES_DIR/mobile-schema.sql" ]; then
            sleep 10
            docker exec "${INSTANCE_ID}_db" psql -U postgres -d postgres -f "/tmp/mobile-schema.sql"
        fi
        ;;
        
    "web-app")
        echo "   Aplicando schema para Aplicação Web..."
        if [ -f "$TEMPLATES_DIR/webapp-schema.sql" ]; then
            sleep 10
            docker exec "${INSTANCE_ID}_db" psql -U postgres -d postgres -f "/tmp/webapp-schema.sql"
        fi
        ;;
        
    *)
        echo "⚠️  Template '$TEMPLATE' não reconhecido, usando projeto em branco"
        ;;
esac

echo "✅ Template aplicado com sucesso!"