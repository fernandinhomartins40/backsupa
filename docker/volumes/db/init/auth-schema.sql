-- ===============================================
-- Supabase Multi-Tenant - Schema Auth Independente
-- ===============================================
-- Este script configura o schema auth para cada instância

-- Criar schema auth se não existir
CREATE SCHEMA IF NOT EXISTS auth;

-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===============================================
-- TABELAS DO SCHEMA AUTH
-- ===============================================

-- Tabela de usuários do auth
CREATE TABLE IF NOT EXISTS auth.users (
    instance_id uuid not null,
    id uuid not null,
    aud varchar(255),
    role varchar(255),
    email varchar(255) unique,
    encrypted_password varchar(255),
    email_confirmed_at timestamptz,
    invited_at timestamptz,
    confirmation_token varchar(255),
    confirmation_sent_at timestamptz,
    recovery_token varchar(255),
    recovery_sent_at timestamptz,
    email_change_token_new varchar(255),
    email_change varchar(255),
    email_change_sent_at timestamptz,
    last_sign_in_at timestamptz,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamptz,
    updated_at timestamptz,
    phone text unique default null,
    phone_confirmed_at timestamptz,
    phone_change text default null,
    phone_change_token varchar(255) default null,
    phone_change_sent_at timestamptz,
    confirmed_at timestamptz GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current varchar(255) default null,
    email_change_confirm_status smallint default 0,
    banned_until timestamptz,
    reauthentication_token varchar(255) default null,
    reauthentication_sent_at timestamptz,
    is_sso_user boolean not null default false,
    deleted_at timestamptz,
    is_anonymous boolean not null default false,

    CONSTRAINT users_pkey PRIMARY KEY (id)
);

-- Tabela de identidades 
CREATE TABLE IF NOT EXISTS auth.identities (
    provider_id text not null,
    user_id uuid not null,
    identity_data jsonb not null,
    provider text not null,
    last_sign_in_at timestamptz,
    created_at timestamptz,
    updated_at timestamptz,
    email text GENERATED ALWAYS AS (identity_data ->> 'email') STORED,

    CONSTRAINT identities_pkey PRIMARY KEY (provider, provider_id),
    CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Tabela de instâncias (para multi-tenant auth)
CREATE TABLE IF NOT EXISTS auth.instances (
    id uuid not null,
    uuid uuid,
    raw_base_config text,
    created_at timestamptz,
    updated_at timestamptz,

    CONSTRAINT instances_pkey PRIMARY KEY (id)
);

-- Tabela de sessões
CREATE TABLE IF NOT EXISTS auth.sessions (
    id uuid not null,
    user_id uuid not null,
    created_at timestamptz,
    updated_at timestamptz,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamptz,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,

    CONSTRAINT sessions_pkey PRIMARY KEY (id),
    CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Tabela de refresh tokens
CREATE TABLE IF NOT EXISTS auth.refresh_tokens (
    instance_id uuid,
    id bigserial,
    token varchar(255),
    user_id uuid,
    revoked boolean,
    created_at timestamptz,
    updated_at timestamptz,
    parent varchar(255),
    session_id uuid,

    CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id),
    CONSTRAINT refresh_tokens_token_unique UNIQUE (token),
    CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE
);

-- ===============================================
-- TIPOS DE DADOS
-- ===============================================

-- Criar tipos se não existirem
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'aal_level') THEN
        CREATE TYPE auth.aal_level AS ENUM ('aal1', 'aal2', 'aal3');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'code_challenge_method') THEN
        CREATE TYPE auth.code_challenge_method AS ENUM ('s256', 'plain');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_status') THEN
        CREATE TYPE auth.factor_status AS ENUM ('unverified', 'verified');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_type') THEN
        CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'one_time_token_type') THEN
        CREATE TYPE auth.one_time_token_type AS ENUM ('confirmation_token', 'reauthentication_token', 'recovery_token', 'email_change_token_new', 'email_change_token_current', 'phone_change_token');
    END IF;
END $$;

-- ===============================================
-- ÍNDICES PARA PERFORMANCE
-- ===============================================

-- Índices para auth.users
CREATE INDEX IF NOT EXISTS users_instance_id_email_idx ON auth.users(instance_id, email text_pattern_ops);
CREATE INDEX IF NOT EXISTS users_email_idx ON auth.users(email text_pattern_ops);
CREATE INDEX IF NOT EXISTS users_phone_idx ON auth.users(phone text_pattern_ops);
CREATE INDEX IF NOT EXISTS users_is_anonymous_idx ON auth.users(is_anonymous);

-- Índices para auth.identities
CREATE INDEX IF NOT EXISTS identities_email_idx ON auth.identities(email text_pattern_ops);
CREATE INDEX IF NOT EXISTS identities_user_id_idx ON auth.identities(user_id);

-- Índices para auth.sessions
CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON auth.sessions(user_id);
CREATE INDEX IF NOT EXISTS sessions_not_after_idx ON auth.sessions(not_after DESC);

-- Índices para auth.refresh_tokens
CREATE INDEX IF NOT EXISTS refresh_tokens_instance_id_idx ON auth.refresh_tokens(instance_id);
CREATE INDEX IF NOT EXISTS refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens(instance_id, user_id);
CREATE INDEX IF NOT EXISTS refresh_tokens_parent_idx ON auth.refresh_tokens(parent);
CREATE INDEX IF NOT EXISTS refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens(session_id, revoked);
CREATE INDEX IF NOT EXISTS refresh_tokens_updated_at_idx ON auth.refresh_tokens(updated_at DESC);

-- ===============================================
-- POLÍTICAS RLS (Row Level Security)
-- ===============================================

-- Habilitar RLS nas tabelas
ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

-- Política para auth.users
CREATE POLICY IF NOT EXISTS "Users can view own user data only" ON auth.users
FOR SELECT USING (auth.uid() = id);

CREATE POLICY IF NOT EXISTS "Users can update own user data only" ON auth.users
FOR UPDATE USING (auth.uid() = id);

-- Política para auth.identities
CREATE POLICY IF NOT EXISTS "Users can view own identities only" ON auth.identities
FOR SELECT USING (auth.uid() = user_id);

-- ===============================================
-- FUNÇÕES AUXILIARES
-- ===============================================

-- Função para criar usuário admin da instância
CREATE OR REPLACE FUNCTION auth.create_instance_admin_user(
    p_instance_id uuid,
    p_email text,
    p_password text,
    p_user_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid AS $$
DECLARE
    v_user_id uuid;
    v_encrypted_password text;
BEGIN
    -- Gerar ID único para o usuário
    v_user_id := gen_random_uuid();
    
    -- Criptografar senha
    v_encrypted_password := crypt(p_password, gen_salt('bf'));
    
    -- Inserir usuário
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        is_super_admin,
        created_at,
        updated_at
    ) VALUES (
        p_instance_id,
        v_user_id,
        'authenticated',
        'authenticated',
        p_email,
        v_encrypted_password,
        now(),
        '{"provider": "email", "providers": ["email"]}',
        p_user_metadata,
        true,
        now(),
        now()
    );
    
    -- Criar identidade de email
    INSERT INTO auth.identities (
        provider_id,
        user_id,
        identity_data,
        provider,
        created_at,
        updated_at
    ) VALUES (
        v_user_id::text,
        v_user_id,
        json_build_object(
            'sub', v_user_id::text,
            'email', p_email,
            'email_verified', true,
            'provider', 'email'
        ),
        'email',
        now(),
        now()
    );
    
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para inicializar instância
CREATE OR REPLACE FUNCTION auth.init_instance(
    p_instance_id uuid,
    p_admin_email text DEFAULT 'admin@localhost',
    p_admin_password text DEFAULT 'admin123'
)
RETURNS json AS $$
DECLARE
    v_admin_user_id uuid;
    v_result json;
BEGIN
    -- Inserir registro da instância
    INSERT INTO auth.instances (id, uuid, created_at, updated_at)
    VALUES (p_instance_id, p_instance_id, now(), now())
    ON CONFLICT (id) DO NOTHING;
    
    -- Criar usuário admin se não existir
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE instance_id = p_instance_id AND email = p_admin_email) THEN
        v_admin_user_id := auth.create_instance_admin_user(
            p_instance_id,
            p_admin_email,
            p_admin_password,
            '{"name": "Admin User", "role": "admin"}'::jsonb
        );
    ELSE
        SELECT id INTO v_admin_user_id 
        FROM auth.users 
        WHERE instance_id = p_instance_id AND email = p_admin_email;
    END IF;
    
    v_result := json_build_object(
        'success', true,
        'instance_id', p_instance_id,
        'admin_user_id', v_admin_user_id,
        'admin_email', p_admin_email
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===============================================
-- COMENTÁRIOS E DOCUMENTAÇÃO
-- ===============================================

COMMENT ON SCHEMA auth IS 'Schema de autenticação multi-tenant do Supabase';
COMMENT ON TABLE auth.users IS 'Tabela de usuários com suporte multi-tenant';
COMMENT ON TABLE auth.identities IS 'Identidades dos usuários (email, OAuth, etc)';
COMMENT ON TABLE auth.instances IS 'Registro das instâncias para multi-tenancy';
COMMENT ON FUNCTION auth.create_instance_admin_user IS 'Cria usuário administrador para uma instância específica';
COMMENT ON FUNCTION auth.init_instance IS 'Inicializa uma nova instância com usuário admin';