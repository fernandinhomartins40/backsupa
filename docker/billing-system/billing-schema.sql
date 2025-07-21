-- Schema de billing para adicionar ao master database
-- Execute este script no banco master para adicionar as tabelas de billing

-- Tabela de planos
CREATE TABLE IF NOT EXISTS plans (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    price_monthly DECIMAL(10,2) NOT NULL DEFAULT 0,
    price_yearly DECIMAL(10,2) NOT NULL DEFAULT 0,
    limits JSONB NOT NULL,
    features JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    stripe_price_id_monthly VARCHAR(255),
    stripe_price_id_yearly VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de subscriptions
CREATE TABLE IF NOT EXISTS subscriptions (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    plan_id INTEGER REFERENCES plans(id),
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'canceled', 'past_due', 'unpaid', 'trialing')),
    billing_cycle VARCHAR(20) DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'yearly')),
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    trial_end TIMESTAMP WITH TIME ZONE,
    cancel_at_period_end BOOLEAN DEFAULT false,
    stripe_customer_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255) UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(organization_id)
);

-- Tabela de métricas de uso
CREATE TABLE IF NOT EXISTS usage_metrics (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    metric_type VARCHAR(50) NOT NULL, -- 'api_requests', 'storage_bytes', 'bandwidth_bytes', 'db_connections'
    value BIGINT NOT NULL DEFAULT 0,
    period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    INDEX(project_id, metric_type, period_start),
    INDEX(organization_id, metric_type, period_start)
);

-- Tabela de invoices/faturas
CREATE TABLE IF NOT EXISTS invoices (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    subscription_id INTEGER REFERENCES subscriptions(id) ON DELETE CASCADE,
    stripe_invoice_id VARCHAR(255) UNIQUE,
    amount_total DECIMAL(10,2) NOT NULL,
    amount_paid DECIMAL(10,2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'open', 'paid', 'void', 'uncollectible')),
    invoice_url TEXT,
    invoice_pdf_url TEXT,
    period_start TIMESTAMP WITH TIME ZONE,
    period_end TIMESTAMP WITH TIME ZONE,
    due_date TIMESTAMP WITH TIME ZONE,
    paid_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de rate limiting por organização
CREATE TABLE IF NOT EXISTS rate_limits (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE UNIQUE,
    current_hour TIMESTAMP WITH TIME ZONE,
    api_requests_count BIGINT DEFAULT 0,
    reset_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_usage_metrics_project_type_period ON usage_metrics(project_id, metric_type, period_start DESC);
CREATE INDEX IF NOT EXISTS idx_usage_metrics_org_type_period ON usage_metrics(organization_id, metric_type, period_start DESC);
CREATE INDEX IF NOT EXISTS idx_subscriptions_org ON subscriptions(organization_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe ON subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_rate_limits_org_hour ON rate_limits(organization_id, current_hour);

-- Seed data: planos padrão
INSERT INTO plans (name, price_monthly, price_yearly, limits, features, stripe_price_id_monthly, stripe_price_id_yearly) VALUES
(
    'Free',
    0.00,
    0.00,
    '{
        "projects": 2,
        "storage_gb": 0.5,
        "bandwidth_gb": 1,
        "api_requests_hour": 1000,
        "db_connections": 20,
        "edge_functions": 10,
        "auth_users": 50000
    }',
    '[
        "2 projetos",
        "500MB de armazenamento",
        "1GB de transferência",
        "1K requests/hora",
        "Suporte da comunidade"
    ]',
    null,
    null
),
(
    'Starter',
    20.00,
    200.00,
    '{
        "projects": 10,
        "storage_gb": 8,
        "bandwidth_gb": 100,
        "api_requests_hour": 10000,
        "db_connections": 100,
        "edge_functions": 100,
        "auth_users": 100000
    }',
    '[
        "10 projetos",
        "8GB de armazenamento",
        "100GB de transferência",
        "10K requests/hora",
        "Backups automáticos",
        "Suporte por email"
    ]',
    'price_starter_monthly',
    'price_starter_yearly'
),
(
    'Pro',
    100.00,
    1000.00,
    '{
        "projects": 50,
        "storage_gb": 100,
        "bandwidth_gb": 500,
        "api_requests_hour": 100000,
        "db_connections": 500,
        "edge_functions": 500,
        "auth_users": 500000
    }',
    '[
        "50 projetos",
        "100GB de armazenamento",
        "500GB de transferência",
        "100K requests/hora",
        "Monitoramento avançado",
        "Suporte prioritário",
        "SLA 99.9%"
    ]',
    'price_pro_monthly',
    'price_pro_yearly'
),
(
    'Enterprise',
    500.00,
    5000.00,
    '{
        "projects": -1,
        "storage_gb": -1,
        "bandwidth_gb": -1,
        "api_requests_hour": -1,
        "db_connections": -1,
        "edge_functions": -1,
        "auth_users": -1
    }',
    '[
        "Projetos ilimitados",
        "Armazenamento ilimitado",
        "Transferência ilimitada",
        "Requests ilimitados",
        "Suporte dedicado",
        "SLA 99.95%",
        "Compliance SOC2",
        "On-premise disponível"
    ]',
    'price_enterprise_monthly',
    'price_enterprise_yearly'
)
ON CONFLICT (name) DO UPDATE SET
    price_monthly = EXCLUDED.price_monthly,
    price_yearly = EXCLUDED.price_yearly,
    limits = EXCLUDED.limits,
    features = EXCLUDED.features,
    updated_at = NOW();

-- Função para obter plano atual de uma organização
CREATE OR REPLACE FUNCTION get_organization_plan(org_id INTEGER)
RETURNS TABLE(
    plan_name VARCHAR(50),
    limits JSONB,
    subscription_status VARCHAR(50),
    period_end TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.name,
        p.limits,
        COALESCE(s.status, 'free'::VARCHAR(50)),
        s.current_period_end
    FROM organizations o
    LEFT JOIN subscriptions s ON o.id = s.organization_id AND s.status = 'active'
    LEFT JOIN plans p ON COALESCE(s.plan_id, 1) = p.id  -- Default to Free plan (id=1)
    WHERE o.id = org_id;
END;
$$ LANGUAGE plpgsql;

-- Função para verificar se organização está dentro dos limites
CREATE OR REPLACE FUNCTION check_organization_limits(org_id INTEGER, limit_type VARCHAR(50), current_value BIGINT DEFAULT 0)
RETURNS BOOLEAN AS $$
DECLARE
    plan_limits JSONB;
    limit_value BIGINT;
BEGIN
    SELECT limits INTO plan_limits
    FROM get_organization_plan(org_id);
    
    limit_value := (plan_limits->>limit_type)::BIGINT;
    
    -- -1 significa ilimitado (plano Enterprise)
    IF limit_value = -1 THEN
        RETURN TRUE;
    END IF;
    
    RETURN current_value < limit_value;
END;
$$ LANGUAGE plpgsql;

-- Função para incrementar uso de API e verificar rate limit
CREATE OR REPLACE FUNCTION increment_api_usage(org_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    current_hour_start TIMESTAMP WITH TIME ZONE;
    current_count BIGINT;
    hour_limit BIGINT;
    plan_limits JSONB;
BEGIN
    -- Calcular início da hora atual
    current_hour_start := date_trunc('hour', NOW());
    
    -- Obter limites do plano
    SELECT limits INTO plan_limits FROM get_organization_plan(org_id);
    hour_limit := (plan_limits->>'api_requests_hour')::BIGINT;
    
    -- -1 significa ilimitado
    IF hour_limit = -1 THEN
        RETURN TRUE;
    END IF;
    
    -- Inserir ou atualizar contador da hora atual
    INSERT INTO rate_limits (organization_id, current_hour, api_requests_count, reset_at)
    VALUES (org_id, current_hour_start, 1, current_hour_start + INTERVAL '1 hour')
    ON CONFLICT (organization_id) DO UPDATE SET
        api_requests_count = CASE 
            WHEN rate_limits.current_hour = current_hour_start THEN rate_limits.api_requests_count + 1
            ELSE 1
        END,
        current_hour = current_hour_start,
        reset_at = current_hour_start + INTERVAL '1 hour',
        updated_at = NOW()
    RETURNING api_requests_count INTO current_count;
    
    RETURN current_count <= hour_limit;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_plans_updated_at BEFORE UPDATE ON plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rate_limits_updated_at BEFORE UPDATE ON rate_limits
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comentários para documentação
COMMENT ON TABLE plans IS 'Planos de assinatura disponíveis';
COMMENT ON TABLE subscriptions IS 'Assinaturas ativas das organizações';
COMMENT ON TABLE usage_metrics IS 'Métricas de uso por projeto e organização';
COMMENT ON TABLE invoices IS 'Faturas geradas pelo Stripe';
COMMENT ON TABLE rate_limits IS 'Controle de rate limiting por organização';
COMMENT ON FUNCTION get_organization_plan(INTEGER) IS 'Retorna o plano atual de uma organização';
COMMENT ON FUNCTION check_organization_limits(INTEGER, VARCHAR(50), BIGINT) IS 'Verifica se organização está dentro dos limites do plano';
COMMENT ON FUNCTION increment_api_usage(INTEGER) IS 'Incrementa uso de API e verifica rate limit';

-- Views úteis
CREATE OR REPLACE VIEW organization_usage_summary AS
SELECT 
    o.id as organization_id,
    o.name as organization_name,
    p.name as plan_name,
    s.status as subscription_status,
    s.current_period_end,
    COUNT(pr.id) as projects_count,
    COALESCE(SUM((pr.limits->>'storage_gb')::BIGINT), 0) as total_storage_gb,
    rl.api_requests_count as current_hour_requests,
    rl.reset_at as rate_limit_reset
FROM organizations o
LEFT JOIN subscriptions s ON o.id = s.organization_id AND s.status = 'active'
LEFT JOIN plans p ON COALESCE(s.plan_id, 1) = p.id
LEFT JOIN projects pr ON o.id = pr.organization_id AND pr.deleted_at IS NULL
LEFT JOIN rate_limits rl ON o.id = rl.organization_id
GROUP BY o.id, o.name, p.name, s.status, s.current_period_end, rl.api_requests_count, rl.reset_at;

COMMENT ON VIEW organization_usage_summary IS 'Resumo de uso e limites por organização';