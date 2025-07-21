-- ===============================================
-- Supabase Multi-Tenant BaaS - Master Database
-- ===============================================
-- Este script configura o banco master para controlar instâncias
-- NÃO modifica nada do Supabase Studio/UI existente

-- Criar database master (executar como superuser)
-- CREATE DATABASE supabase_master;
-- \c supabase_master;

-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===============================================
-- SCHEMA PRINCIPAL
-- ===============================================

-- Tabela de organizações
CREATE TABLE organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    domain VARCHAR(255), -- domínio personalizado opcional
    logo_url VARCHAR(500),
    settings JSONB DEFAULT '{}',
    billing_plan VARCHAR(50) DEFAULT 'free',
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de usuários
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    encrypted_password VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    avatar_url VARCHAR(500),
    email_confirmed BOOLEAN DEFAULT FALSE,
    email_confirmed_at TIMESTAMP WITH TIME ZONE,
    confirmation_token VARCHAR(255),
    reset_password_token VARCHAR(255),
    reset_password_sent_at TIMESTAMP WITH TIME ZONE,
    last_sign_in_at TIMESTAMP WITH TIME ZONE,
    settings JSONB DEFAULT '{}',
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Relacionamento usuário-organização
CREATE TABLE user_organizations (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'member', -- owner, admin, member, viewer
    permissions JSONB DEFAULT '{}',
    invited_at TIMESTAMP WITH TIME ZONE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    invited_by INTEGER REFERENCES users(id),
    status VARCHAR(50) DEFAULT 'active', -- active, pending, suspended
    PRIMARY KEY (user_id, organization_id)
);

-- Tabela de projetos/instâncias
CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    description TEXT,
    instance_id VARCHAR(255) UNIQUE NOT NULL,
    subdomain VARCHAR(255) UNIQUE NOT NULL,
    custom_domain VARCHAR(255), -- domínio personalizado opcional
    
    -- URLs de acesso
    database_url VARCHAR(500) NOT NULL,
    api_url VARCHAR(500) NOT NULL,
    studio_url VARCHAR(500) NOT NULL,
    
    -- Configuração técnica
    port INTEGER NOT NULL,
    postgres_port INTEGER NOT NULL,
    analytics_port INTEGER NOT NULL,
    
    -- Credenciais da instância
    postgres_password VARCHAR(255) NOT NULL,
    jwt_secret VARCHAR(255) NOT NULL,
    anon_key TEXT NOT NULL,
    service_role_key TEXT NOT NULL,
    dashboard_username VARCHAR(100) NOT NULL,
    dashboard_password VARCHAR(255) NOT NULL,
    
    -- Configurações específicas
    region VARCHAR(50) DEFAULT 'local',
    database_size VARCHAR(50) DEFAULT 'small',
    storage_limit_gb INTEGER DEFAULT 1,
    bandwidth_limit_gb INTEGER DEFAULT 5,
    
    -- Metadados
    config JSONB DEFAULT '{}',
    environment VARCHAR(50) DEFAULT 'production', -- production, staging, development
    status VARCHAR(50) DEFAULT 'creating', -- creating, active, paused, error, deleting
    health_status VARCHAR(50) DEFAULT 'unknown', -- healthy, unhealthy, unknown
    last_health_check TIMESTAMP WITH TIME ZONE,
    
    -- Auditoria
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(organization_id, slug)
);

-- Histórico de alterações nos projetos
CREATE TABLE project_audit_log (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(100) NOT NULL, -- created, updated, deleted, started, stopped, etc
    details JSONB DEFAULT '{}',
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Estatísticas de uso dos projetos
CREATE TABLE project_usage_stats (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    
    -- Métricas de banco de dados
    db_connections_peak INTEGER DEFAULT 0,
    db_connections_avg INTEGER DEFAULT 0,
    db_size_mb BIGINT DEFAULT 0,
    db_queries_count BIGINT DEFAULT 0,
    
    -- Métricas de API
    api_requests_count BIGINT DEFAULT 0,
    api_requests_auth BIGINT DEFAULT 0,
    api_requests_storage BIGINT DEFAULT 0,
    api_requests_realtime BIGINT DEFAULT 0,
    
    -- Métricas de storage
    storage_size_mb BIGINT DEFAULT 0,
    storage_files_count INTEGER DEFAULT 0,
    storage_bandwidth_mb BIGINT DEFAULT 0,
    
    -- Métricas de edge functions
    functions_invocations BIGINT DEFAULT 0,
    functions_errors BIGINT DEFAULT 0,
    functions_duration_ms BIGINT DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(project_id, date)
);

-- Logs de sistema
CREATE TABLE system_logs (
    id SERIAL PRIMARY KEY,
    level VARCHAR(20) NOT NULL, -- info, warning, error, critical
    service VARCHAR(50) NOT NULL, -- api, nginx-manager, generate-script, etc
    message TEXT NOT NULL,
    details JSONB DEFAULT '{}',
    user_id INTEGER REFERENCES users(id),
    project_id INTEGER REFERENCES projects(id),
    organization_id INTEGER REFERENCES organizations(id),
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ===============================================
-- ÍNDICES PARA PERFORMANCE
-- ===============================================

-- Índices para organizações
CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_status ON organizations(status);

-- Índices para usuários
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_confirmation_token ON users(confirmation_token);
CREATE INDEX idx_users_reset_password_token ON users(reset_password_token);

-- Índices para user_organizations
CREATE INDEX idx_user_organizations_user_id ON user_organizations(user_id);
CREATE INDEX idx_user_organizations_organization_id ON user_organizations(organization_id);
CREATE INDEX idx_user_organizations_role ON user_organizations(role);

-- Índices para projetos
CREATE INDEX idx_projects_organization_id ON projects(organization_id);
CREATE INDEX idx_projects_instance_id ON projects(instance_id);
CREATE INDEX idx_projects_subdomain ON projects(subdomain);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_created_by ON projects(created_by);
CREATE INDEX idx_projects_slug ON projects(slug);

-- Índices para audit log
CREATE INDEX idx_project_audit_log_project_id ON project_audit_log(project_id);
CREATE INDEX idx_project_audit_log_user_id ON project_audit_log(user_id);
CREATE INDEX idx_project_audit_log_action ON project_audit_log(action);
CREATE INDEX idx_project_audit_log_created_at ON project_audit_log(created_at);

-- Índices para usage stats
CREATE INDEX idx_project_usage_stats_project_id ON project_usage_stats(project_id);
CREATE INDEX idx_project_usage_stats_date ON project_usage_stats(date);

-- Índices para system logs
CREATE INDEX idx_system_logs_level ON system_logs(level);
CREATE INDEX idx_system_logs_service ON system_logs(service);
CREATE INDEX idx_system_logs_created_at ON system_logs(created_at);
CREATE INDEX idx_system_logs_project_id ON system_logs(project_id);

-- ===============================================
-- TRIGGERS PARA UPDATED_AT
-- ===============================================

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para updated_at
CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===============================================
-- FUNÇÕES ESSENCIAIS
-- ===============================================

-- Função para criar slug único
CREATE OR REPLACE FUNCTION generate_unique_slug(base_text TEXT, table_name TEXT, column_name TEXT DEFAULT 'slug')
RETURNS TEXT AS $$
DECLARE
    slug TEXT;
    counter INTEGER := 0;
    query_text TEXT;
    exists_count INTEGER;
BEGIN
    -- Gerar slug base
    slug := lower(regexp_replace(base_text, '[^a-zA-Z0-9]+', '-', 'g'));
    slug := trim(both '-' from slug);
    
    -- Verificar se slug existe
    LOOP
        IF counter = 0 THEN
            query_text := format('SELECT COUNT(*) FROM %I WHERE %I = $1', table_name, column_name);
            EXECUTE query_text INTO exists_count USING slug;
        ELSE
            query_text := format('SELECT COUNT(*) FROM %I WHERE %I = $1', table_name, column_name);
            EXECUTE query_text INTO exists_count USING slug || '-' || counter;
        END IF;
        
        IF exists_count = 0 THEN
            IF counter = 0 THEN
                RETURN slug;
            ELSE
                RETURN slug || '-' || counter;
            END IF;
        END IF;
        
        counter := counter + 1;
        
        -- Evitar loop infinito
        IF counter > 999 THEN
            RETURN slug || '-' || extract(epoch from now())::integer;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Função para gerar subdomain único
CREATE OR REPLACE FUNCTION generate_unique_subdomain(project_name TEXT, org_slug TEXT)
RETURNS TEXT AS $$
DECLARE
    base_subdomain TEXT;
    subdomain TEXT;
    counter INTEGER := 0;
    exists_count INTEGER;
BEGIN
    -- Gerar subdomain base: projeto-org
    base_subdomain := lower(regexp_replace(project_name || '-' || org_slug, '[^a-zA-Z0-9]+', '-', 'g'));
    base_subdomain := trim(both '-' from base_subdomain);
    
    -- Verificar se subdomain existe
    LOOP
        IF counter = 0 THEN
            subdomain := base_subdomain;
        ELSE
            subdomain := base_subdomain || '-' || counter;
        END IF;
        
        SELECT COUNT(*) INTO exists_count FROM projects WHERE projects.subdomain = subdomain;
        
        IF exists_count = 0 THEN
            RETURN subdomain;
        END IF;
        
        counter := counter + 1;
        
        -- Evitar loop infinito
        IF counter > 999 THEN
            RETURN base_subdomain || '-' || extract(epoch from now())::integer;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Função para hash password
CREATE OR REPLACE FUNCTION hash_password(password TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN crypt(password, gen_salt('bf', 10));
END;
$$ LANGUAGE plpgsql;

-- Função para verificar password
CREATE OR REPLACE FUNCTION verify_password(password TEXT, hash TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN crypt(password, hash) = hash;
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- FUNÇÕES DE NEGÓCIO
-- ===============================================

-- Função para criar instância de projeto
CREATE OR REPLACE FUNCTION create_project_instance(
    p_org_id INTEGER,
    p_project_name TEXT,
    p_user_id INTEGER,
    p_description TEXT DEFAULT NULL,
    p_environment TEXT DEFAULT 'production'
)
RETURNS JSON AS $$
DECLARE
    org_record RECORD;
    project_record RECORD;
    project_slug TEXT;
    subdomain TEXT;
    instance_id TEXT;
    result JSON;
BEGIN
    -- Verificar se organização existe e usuário tem permissão
    SELECT o.*, uo.role INTO org_record
    FROM organizations o
    JOIN user_organizations uo ON uo.organization_id = o.id
    WHERE o.id = p_org_id 
      AND uo.user_id = p_user_id 
      AND o.status = 'active'
      AND uo.status = 'active'
      AND uo.role IN ('owner', 'admin');
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Organization not found or insufficient permissions'
        );
    END IF;
    
    -- Gerar identificadores únicos
    project_slug := generate_unique_slug(p_project_name, 'projects', 'slug');
    subdomain := generate_unique_subdomain(p_project_name, org_record.slug);
    instance_id := org_record.id || '_' || project_slug || '_' || extract(epoch from now())::integer;
    
    -- Inserir projeto
    INSERT INTO projects (
        organization_id,
        name,
        slug,
        description,
        instance_id,
        subdomain,
        database_url,
        api_url,
        studio_url,
        port,
        postgres_port,
        analytics_port,
        postgres_password,
        jwt_secret,
        anon_key,
        service_role_key,
        dashboard_username,
        dashboard_password,
        environment,
        created_by,
        status
    ) VALUES (
        p_org_id,
        p_project_name,
        project_slug,
        p_description,
        instance_id,
        subdomain,
        'postgresql://postgres:PLACEHOLDER@localhost:PORT/postgres', -- será atualizado
        'https://' || subdomain || '.yourdomain.com',
        'https://' || subdomain || '.yourdomain.com',
        0, -- será atualizado pelo script
        0, -- será atualizado pelo script
        0, -- será atualizado pelo script
        'PLACEHOLDER', -- será atualizado pelo script
        'PLACEHOLDER', -- será atualizado pelo script
        'PLACEHOLDER', -- será atualizado pelo script
        'PLACEHOLDER', -- será atualizado pelo script
        'admin',
        'PLACEHOLDER', -- será atualizado pelo script
        p_environment,
        p_user_id,
        'creating'
    ) RETURNING * INTO project_record;
    
    -- Log da criação
    INSERT INTO project_audit_log (project_id, user_id, action, details)
    VALUES (
        project_record.id,
        p_user_id,
        'created',
        json_build_object(
            'project_name', p_project_name,
            'instance_id', instance_id,
            'subdomain', subdomain
        )
    );
    
    -- Retornar resultado
    result := json_build_object(
        'success', true,
        'project', row_to_json(project_record)
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Função para obter projetos do usuário
CREATE OR REPLACE FUNCTION get_user_projects(p_user_id INTEGER)
RETURNS JSON AS $$
DECLARE
    projects_json JSON;
BEGIN
    SELECT json_agg(
        json_build_object(
            'id', p.id,
            'name', p.name,
            'slug', p.slug,
            'description', p.description,
            'subdomain', p.subdomain,
            'api_url', p.api_url,
            'studio_url', p.studio_url,
            'status', p.status,
            'health_status', p.health_status,
            'environment', p.environment,
            'created_at', p.created_at,
            'organization', json_build_object(
                'id', o.id,
                'name', o.name,
                'slug', o.slug
            ),
            'user_role', uo.role
        )
    ) INTO projects_json
    FROM projects p
    JOIN organizations o ON o.id = p.organization_id
    JOIN user_organizations uo ON uo.organization_id = o.id
    WHERE uo.user_id = p_user_id
      AND p.deleted_at IS NULL
      AND o.status = 'active'
      AND uo.status = 'active'
    ORDER BY p.created_at DESC;
    
    RETURN COALESCE(projects_json, '[]'::JSON);
END;
$$ LANGUAGE plpgsql;

-- Função para marcar projeto como deletado
CREATE OR REPLACE FUNCTION delete_project_instance(p_project_id INTEGER, p_user_id INTEGER)
RETURNS JSON AS $$
DECLARE
    project_record RECORD;
    org_role TEXT;
BEGIN
    -- Verificar se projeto existe e usuário tem permissão
    SELECT p.*, uo.role INTO project_record, org_role
    FROM projects p
    JOIN user_organizations uo ON uo.organization_id = p.organization_id
    WHERE p.id = p_project_id 
      AND uo.user_id = p_user_id 
      AND p.deleted_at IS NULL
      AND uo.status = 'active'
      AND uo.role IN ('owner', 'admin');
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Project not found or insufficient permissions'
        );
    END IF;
    
    -- Marcar como sendo deletado
    UPDATE projects 
    SET status = 'deleting', updated_at = NOW()
    WHERE id = p_project_id;
    
    -- Log da deleção
    INSERT INTO project_audit_log (project_id, user_id, action, details)
    VALUES (
        p_project_id,
        p_user_id,
        'deletion_started',
        json_build_object(
            'instance_id', project_record.instance_id,
            'subdomain', project_record.subdomain
        )
    );
    
    RETURN json_build_object(
        'success', true,
        'project', json_build_object(
            'id', project_record.id,
            'instance_id', project_record.instance_id,
            'subdomain', project_record.subdomain
        )
    );
END;
$$ LANGUAGE plpgsql;

-- Função para atualizar configurações do projeto após criação
CREATE OR REPLACE FUNCTION update_project_config(
    p_instance_id TEXT,
    p_port INTEGER,
    p_postgres_port INTEGER,
    p_analytics_port INTEGER,
    p_postgres_password TEXT,
    p_jwt_secret TEXT,
    p_anon_key TEXT,
    p_service_role_key TEXT,
    p_dashboard_password TEXT
)
RETURNS JSON AS $$
DECLARE
    project_record RECORD;
BEGIN
    -- Atualizar configurações do projeto
    UPDATE projects SET
        port = p_port,
        postgres_port = p_postgres_port,
        analytics_port = p_analytics_port,
        postgres_password = p_postgres_password,
        jwt_secret = p_jwt_secret,
        anon_key = p_anon_key,
        service_role_key = p_service_role_key,
        dashboard_password = p_dashboard_password,
        database_url = 'postgresql://postgres:' || p_postgres_password || '@localhost:' || p_postgres_port || '/postgres',
        status = 'active',
        updated_at = NOW()
    WHERE instance_id = p_instance_id
    RETURNING * INTO project_record;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Project not found'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'project', row_to_json(project_record)
    );
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- DADOS INICIAIS
-- ===============================================

-- Organização padrão para desenvolvimento
INSERT INTO organizations (name, slug, status) 
VALUES ('Default Organization', 'default', 'active')
ON CONFLICT (slug) DO NOTHING;

-- Usuário admin padrão (senha: admin123)
INSERT INTO users (email, encrypted_password, first_name, last_name, email_confirmed, status)
VALUES (
    'admin@localhost',
    hash_password('admin123'),
    'Admin',
    'User',
    true,
    'active'
) ON CONFLICT (email) DO NOTHING;

-- Associar admin à organização padrão
INSERT INTO user_organizations (user_id, organization_id, role, status)
SELECT u.id, o.id, 'owner', 'active'
FROM users u, organizations o
WHERE u.email = 'admin@localhost' 
  AND o.slug = 'default'
ON CONFLICT (user_id, organization_id) DO NOTHING;

-- ===============================================
-- COMENTÁRIOS FINAIS
-- ===============================================

-- Este schema foi projetado para:
-- 1. Suportar multi-tenancy completo
-- 2. Auditoria completa de ações
-- 3. Estatísticas de uso detalhadas
-- 4. Escalabilidade horizontal
-- 5. Integração com scripts existentes
-- 6. NÃO interferir com o Supabase Studio existente

COMMENT ON DATABASE supabase_master IS 'Banco master para controle de instâncias Supabase multi-tenant';
COMMENT ON TABLE organizations IS 'Organizações/empresas que usam o BaaS';
COMMENT ON TABLE users IS 'Usuários do sistema de controle';
COMMENT ON TABLE projects IS 'Projetos/instâncias Supabase criadas';
COMMENT ON TABLE project_audit_log IS 'Log de auditoria das ações nos projetos';
COMMENT ON TABLE project_usage_stats IS 'Estatísticas de uso dos projetos';
COMMENT ON TABLE system_logs IS 'Logs do sistema de controle';