-- Supabase Multi-Tenant Instance Initialization
-- Este script � executado para cada nova inst�ncia

-- Carregar schema de autentica��o
\i /docker-entrypoint-initdb.d/auth-schema.sql

-- Inicializar inst�ncia com usu�rio admin
-- O INSTANCE_ID ser� substitu�do pelo script de gera��o
SELECT auth.init_instance(
    '${INSTANCE_ID}'::uuid,
    'admin@${SUBDOMAIN}.${BASE_DOMAIN}',
    '${DASHBOARD_PASSWORD}'
);

-- Confirmar inicializa��o
SELECT 'Inst�ncia ${INSTANCE_ID} inicializada com sucesso' as status;