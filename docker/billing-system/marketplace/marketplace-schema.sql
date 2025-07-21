-- Schema do Marketplace de Templates para BaaS Supabase
-- Execute este script no banco master para adicionar as tabelas do marketplace

-- Tabela de categorias de templates
CREATE TABLE IF NOT EXISTS template_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(50), -- Material Icons ou similar
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de templates
CREATE TABLE IF NOT EXISTS templates (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(200) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    long_description TEXT,
    category_id INTEGER REFERENCES template_categories(id),
    author_name VARCHAR(100),
    author_email VARCHAR(255),
    version VARCHAR(20) DEFAULT '1.0.0',
    
    -- Metadata
    tags JSONB DEFAULT '[]',
    features JSONB DEFAULT '[]',
    requirements JSONB DEFAULT '{}',
    
    -- Assets
    thumbnail_url TEXT,
    demo_url TEXT,
    github_url TEXT,
    documentation_url TEXT,
    
    -- Pricing
    is_free BOOLEAN DEFAULT true,
    price_usd DECIMAL(10,2) DEFAULT 0,
    
    -- Stats
    downloads_count INTEGER DEFAULT 0,
    rating_average DECIMAL(3,2) DEFAULT 0,
    rating_count INTEGER DEFAULT 0,
    
    -- Status
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived', 'deprecated')),
    is_featured BOOLEAN DEFAULT false,
    
    -- Content
    schema_sql TEXT, -- SQL para criar tabelas
    seed_data_sql TEXT, -- SQL para dados iniciais
    edge_functions JSONB DEFAULT '[]', -- Array de edge functions
    api_config JSONB DEFAULT '{}', -- Configurações específicas da API
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de arquivos do template (schemas, functions, assets)
CREATE TABLE IF NOT EXISTS template_files (
    id SERIAL PRIMARY KEY,
    template_id INTEGER REFERENCES templates(id) ON DELETE CASCADE,
    file_path VARCHAR(500) NOT NULL, -- Caminho relativo dentro do template
    file_type VARCHAR(50) NOT NULL, -- 'sql', 'js', 'ts', 'json', 'md', 'image'
    content TEXT, -- Conteúdo do arquivo (para arquivos de texto)
    file_url TEXT, -- URL para arquivos binários
    file_size BIGINT, -- Tamanho em bytes
    checksum VARCHAR(64), -- SHA256 do arquivo
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de reviews/avaliações
CREATE TABLE IF NOT EXISTS template_reviews (
    id SERIAL PRIMARY KEY,
    template_id INTEGER REFERENCES templates(id) ON DELETE CASCADE,
    user_email VARCHAR(255) NOT NULL,
    user_name VARCHAR(100),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    is_verified BOOLEAN DEFAULT false, -- Se o usuário realmente baixou/usou
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(template_id, user_email)
);

-- Tabela de downloads/instalações
CREATE TABLE IF NOT EXISTS template_installations (
    id SERIAL PRIMARY KEY,
    template_id INTEGER REFERENCES templates(id) ON DELETE CASCADE,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    installed_version VARCHAR(20),
    installation_status VARCHAR(50) DEFAULT 'completed' CHECK (installation_status IN ('pending', 'completed', 'failed', 'rolled_back')),
    error_message TEXT,
    installed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(template_id, project_id)
);

-- Tabela de favoritos
CREATE TABLE IF NOT EXISTS template_favorites (
    id SERIAL PRIMARY KEY,
    template_id INTEGER REFERENCES templates(id) ON DELETE CASCADE,
    user_email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(template_id, user_email)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_templates_category ON templates(category_id);
CREATE INDEX IF NOT EXISTS idx_templates_status ON templates(status);
CREATE INDEX IF NOT EXISTS idx_templates_featured ON templates(is_featured);
CREATE INDEX IF NOT EXISTS idx_templates_free ON templates(is_free);
CREATE INDEX IF NOT EXISTS idx_templates_rating ON templates(rating_average DESC);
CREATE INDEX IF NOT EXISTS idx_templates_downloads ON templates(downloads_count DESC);
CREATE INDEX IF NOT EXISTS idx_template_files_template_type ON template_files(template_id, file_type);
CREATE INDEX IF NOT EXISTS idx_template_reviews_template ON template_reviews(template_id);
CREATE INDEX IF NOT EXISTS idx_template_installations_project ON template_installations(project_id);
CREATE INDEX IF NOT EXISTS idx_template_installations_org ON template_installations(organization_id);

-- Dados iniciais: categorias
INSERT INTO template_categories (name, description, icon, sort_order) VALUES
('Aplicações Web', 'Templates para aplicações web completas', 'web', 1),
('E-commerce', 'Lojas virtuais e sistemas de vendas', 'store', 2),
('Blog & CMS', 'Blogs, portfolios e sistemas de conteúdo', 'article', 3),
('SaaS & Dashboards', 'Aplicações SaaS e painéis administrativos', 'dashboard', 4),
('APIs & Backend', 'APIs REST, GraphQL e microserviços', 'api', 5),
('Chat & Social', 'Aplicações de chat, redes sociais', 'chat', 6),
('Educação', 'Plataformas educacionais e LMS', 'school', 7),
('Jogos', 'Jogos e aplicações de entretenimento', 'games', 8),
('IoT & Sensores', 'Internet das coisas e dados de sensores', 'sensors', 9),
('Ferramentas', 'Utilitários e ferramentas de produtividade', 'build', 10)
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    sort_order = EXCLUDED.sort_order,
    updated_at = NOW();

-- Funções úteis

-- Função para obter templates por categoria
CREATE OR REPLACE FUNCTION get_templates_by_category(category_slug VARCHAR(200) DEFAULT NULL, limit_count INTEGER DEFAULT 20, offset_count INTEGER DEFAULT 0)
RETURNS TABLE(
    id INTEGER,
    name VARCHAR(200),
    slug VARCHAR(200),
    description TEXT,
    category_name VARCHAR(100),
    thumbnail_url TEXT,
    is_free BOOLEAN,
    price_usd DECIMAL(10,2),
    downloads_count INTEGER,
    rating_average DECIMAL(3,2),
    rating_count INTEGER,
    tags JSONB,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.name,
        t.slug,
        t.description,
        tc.name as category_name,
        t.thumbnail_url,
        t.is_free,
        t.price_usd,
        t.downloads_count,
        t.rating_average,
        t.rating_count,
        t.tags,
        t.created_at
    FROM templates t
    JOIN template_categories tc ON t.category_id = tc.id
    WHERE t.status = 'published'
    AND (category_slug IS NULL OR tc.name = category_slug)
    ORDER BY t.is_featured DESC, t.downloads_count DESC, t.rating_average DESC
    LIMIT limit_count OFFSET offset_count;
END;
$$ LANGUAGE plpgsql;

-- Função para buscar templates
CREATE OR REPLACE FUNCTION search_templates(search_term VARCHAR(500), limit_count INTEGER DEFAULT 20)
RETURNS TABLE(
    id INTEGER,
    name VARCHAR(200),
    slug VARCHAR(200),
    description TEXT,
    category_name VARCHAR(100),
    thumbnail_url TEXT,
    is_free BOOLEAN,
    price_usd DECIMAL(10,2),
    downloads_count INTEGER,
    rating_average DECIMAL(3,2),
    match_rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.name,
        t.slug,
        t.description,
        tc.name as category_name,
        t.thumbnail_url,
        t.is_free,
        t.price_usd,
        t.downloads_count,
        t.rating_average,
        ts_rank(
            to_tsvector('portuguese', t.name || ' ' || t.description || ' ' || COALESCE(array_to_string(array(SELECT jsonb_array_elements_text(t.tags)), ' '), '')),
            plainto_tsquery('portuguese', search_term)
        ) as match_rank
    FROM templates t
    JOIN template_categories tc ON t.category_id = tc.id
    WHERE t.status = 'published'
    AND (
        to_tsvector('portuguese', t.name || ' ' || t.description || ' ' || COALESCE(array_to_string(array(SELECT jsonb_array_elements_text(t.tags)), ' '), '')) 
        @@ plainto_tsquery('portuguese', search_term)
    )
    ORDER BY match_rank DESC, t.downloads_count DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Função para incrementar download count
CREATE OR REPLACE FUNCTION increment_template_downloads(template_id INTEGER)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE templates SET downloads_count = downloads_count + 1 WHERE id = template_id;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Função para calcular rating médio
CREATE OR REPLACE FUNCTION update_template_rating(template_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    avg_rating DECIMAL(3,2);
    total_ratings INTEGER;
BEGIN
    SELECT 
        ROUND(AVG(rating), 2),
        COUNT(*)
    INTO avg_rating, total_ratings
    FROM template_reviews 
    WHERE template_id = update_template_rating.template_id;
    
    UPDATE templates 
    SET 
        rating_average = COALESCE(avg_rating, 0),
        rating_count = total_ratings,
        updated_at = NOW()
    WHERE id = template_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar rating automaticamente
CREATE OR REPLACE FUNCTION trigger_update_template_rating()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        PERFORM update_template_rating(NEW.template_id);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM update_template_rating(OLD.template_id);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER template_review_rating_update
    AFTER INSERT OR UPDATE OR DELETE ON template_reviews
    FOR EACH ROW EXECUTE FUNCTION trigger_update_template_rating();

-- Trigger para atualizar updated_at
CREATE TRIGGER update_template_categories_updated_at BEFORE UPDATE ON template_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_templates_updated_at BEFORE UPDATE ON templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_template_reviews_updated_at BEFORE UPDATE ON template_reviews
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- View para templates populares
CREATE OR REPLACE VIEW popular_templates AS
SELECT 
    t.*,
    tc.name as category_name,
    tc.icon as category_icon
FROM templates t
JOIN template_categories tc ON t.category_id = tc.id
WHERE t.status = 'published'
AND t.downloads_count > 0
ORDER BY t.downloads_count DESC, t.rating_average DESC
LIMIT 50;

-- View para templates em destaque
CREATE OR REPLACE VIEW featured_templates AS
SELECT 
    t.*,
    tc.name as category_name,
    tc.icon as category_icon
FROM templates t
JOIN template_categories tc ON t.category_id = tc.id
WHERE t.status = 'published'
AND t.is_featured = true
ORDER BY t.created_at DESC;

-- Comentários para documentação
COMMENT ON TABLE template_categories IS 'Categorias de templates do marketplace';
COMMENT ON TABLE templates IS 'Templates disponíveis no marketplace';
COMMENT ON TABLE template_files IS 'Arquivos que compõem cada template';
COMMENT ON TABLE template_reviews IS 'Avaliações e reviews dos templates';
COMMENT ON TABLE template_installations IS 'Histórico de instalações de templates';
COMMENT ON TABLE template_favorites IS 'Templates favoritados pelos usuários';

COMMENT ON FUNCTION get_templates_by_category(VARCHAR(200), INTEGER, INTEGER) IS 'Busca templates por categoria com paginação';
COMMENT ON FUNCTION search_templates(VARCHAR(500), INTEGER) IS 'Busca textual em templates com ranking de relevância';
COMMENT ON FUNCTION increment_template_downloads(INTEGER) IS 'Incrementa contador de downloads de um template';
COMMENT ON FUNCTION update_template_rating(INTEGER) IS 'Recalcula rating médio de um template';