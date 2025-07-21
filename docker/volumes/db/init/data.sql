-- Supabase Multi-Tenant Instance Initialization
-- Este script é executado para cada nova instância

-- Carregar schema de autenticação
\i /docker-entrypoint-initdb.d/auth-schema.sql

-- Inicializar instância com usuário admin
-- O INSTANCE_ID será substituído pelo script de geração
SELECT auth.init_instance(
    '${INSTANCE_ID}'::uuid,
    'admin@${SUBDOMAIN}.${BASE_DOMAIN}',
    '${DASHBOARD_PASSWORD}'
);

-- Confirmar inicialização
SELECT 'Instância ${INSTANCE_ID} inicializada com sucesso' as status;