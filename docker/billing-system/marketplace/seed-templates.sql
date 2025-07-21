-- Script para inserir templates predefinidos no marketplace
-- Execute este script no banco master após criar o schema do marketplace

-- Insert all predefined templates
INSERT INTO templates (
    name, slug, description, long_description, category_id,
    author_name, author_email, version, tags, features,
    thumbnail_url, demo_url, github_url, documentation_url,
    is_free, price_usd, status, is_featured,
    schema_sql, seed_data_sql, edge_functions, api_config
) VALUES 

-- Todo App Template
(
    'Todo App - Lista de Tarefas',
    'todo-app',
    'Aplicação completa de lista de tarefas com autenticação e sincronização em tempo real',
    'Uma aplicação moderna de lista de tarefas construída com as melhores práticas. Inclui autenticação de usuários, categorização de tarefas, filtros avançados, sincronização em tempo real e interface responsiva. Perfeita para aprender os conceitos básicos do Supabase ou como base para projetos mais complexos.',
    (SELECT id FROM template_categories WHERE name = 'Aplicações Web'),
    'Supabase Team',
    'templates@supabase.com',
    '1.0.0',
    '["todo", "tasks", "productivity", "real-time", "auth"]'::jsonb,
    '["Autenticação completa (signup/login/logout)", "CRUD de tarefas com RLS", "Categorias e tags personalizadas", "Filtros por status, categoria e data", "Sincronização em tempo real", "Interface responsiva", "Dark mode", "Notificações push", "Histórico de atividades"]'::jsonb,
    '/uploads/thumbnails/todo-app.png',
    'https://todo-demo.supabase.com',
    'https://github.com/supabase/supabase-todo-template',
    'https://docs.supabase.com/templates/todo-app',
    true,
    0.00,
    'published',
    true,
    
    -- Schema SQL content would be loaded from file
    '-- Todo App Schema will be loaded from schema.sql file',
    '-- Todo App Seed data will be loaded from seed.sql file',
    '[]'::jsonb,
    '{
        "auth": {
            "enabled": true,
            "providers": ["email", "google"],
            "email_confirm": false
        },
        "realtime": {
            "enabled": true,
            "tables": ["todos", "categories"]
        }
    }'::jsonb
),

-- Blog CMS Template  
(
    'Blog CMS - Sistema de Blog Completo',
    'blog-cms',
    'Sistema completo de blog com editor WYSIWYG, gestão de conteúdo e área administrativa',
    'Um sistema de blog moderno e completo com todas as funcionalidades que você precisa. Inclui editor de texto rico, gestão de posts e páginas, sistema de categorias e tags, comentários, SEO otimizado, painel administrativo intuitivo e área pública responsiva. Perfeito para blogs pessoais, corporativos ou sites de notícias.',
    (SELECT id FROM template_categories WHERE name = 'Blog & CMS'),
    'Supabase Team',
    'templates@supabase.com',
    '1.0.0',
    '["blog", "cms", "content", "posts", "seo", "editor"]'::jsonb,
    '["Editor WYSIWYG rico para posts", "Gestão completa de posts e páginas", "Sistema de categorias e tags", "Comentários com moderação", "SEO otimizado (meta tags, slugs)", "Upload e gestão de imagens", "Área administrativa completa", "Template público responsivo", "Sistema de rascunhos", "Agendamento de publicação", "Busca de conteúdo", "Estatísticas de visualização"]'::jsonb,
    '/uploads/thumbnails/blog-cms.png',
    'https://blog-cms-demo.supabase.com',
    'https://github.com/supabase/supabase-blog-template',
    'https://docs.supabase.com/templates/blog-cms',
    true,
    0.00,
    'published',
    true,
    
    '-- Blog CMS Schema will be loaded from schema.sql file',
    '-- Blog CMS Seed data will be loaded from seed.sql file',
    '["optimize-images", "generate-sitemap"]'::jsonb,
    '{
        "auth": {
            "enabled": true,
            "providers": ["email"],
            "email_confirm": true
        },
        "storage": {
            "enabled": true,
            "buckets": ["blog-images", "blog-files"]
        }
    }'::jsonb
),

-- E-commerce Template
(
    'E-commerce Store - Loja Virtual Completa',
    'ecommerce-store',
    'Loja virtual completa com carrinho, pagamentos, gestão de produtos e painel administrativo',
    'Uma solução completa de e-commerce pronta para uso. Inclui catálogo de produtos, carrinho de compras, sistema de pagamentos integrado, gestão de pedidos, controle de estoque, área do cliente, painel administrativo completo e muito mais. Ideal para quem quer vender online rapidamente ou como base para projetos personalizados.',
    (SELECT id FROM template_categories WHERE name = 'E-commerce'),
    'Supabase Team',
    'templates@supabase.com',
    '1.0.0',
    '["ecommerce", "loja", "vendas", "pagamentos", "produtos", "carrinho"]'::jsonb,
    '["Catálogo de produtos completo", "Carrinho de compras persistente", "Sistema de pagamentos (Stripe)", "Gestão de pedidos e status", "Controle de estoque automatizado", "Área do cliente com histórico", "Painel admin para vendedores", "Sistema de cupons e descontos", "Avaliações e comentários", "Busca e filtros avançados", "Gestão de categorias", "Relatórios de vendas", "Notificações por email", "Checkout em múltiplas etapas"]'::jsonb,
    '/uploads/thumbnails/ecommerce-store.png',
    'https://ecommerce-demo.supabase.com',
    'https://github.com/supabase/supabase-ecommerce-template',
    'https://docs.supabase.com/templates/ecommerce-store',
    false,
    49.99,
    'published',
    true,
    
    '-- E-commerce Schema will be loaded from schema.sql file',
    '-- E-commerce Seed data will be loaded from seed.sql file',
    '["process-payment", "send-order-confirmation", "update-inventory"]'::jsonb,
    '{
        "auth": {
            "enabled": true,
            "providers": ["email", "google"],
            "email_confirm": true
        },
        "storage": {
            "enabled": true,
            "buckets": ["product-images", "store-assets"]
        },
        "realtime": {
            "enabled": true,
            "tables": ["orders", "inventory"]
        }
    }'::jsonb
),

-- Chat App Template
(
    'Chat App - Aplicativo de Mensagens',
    'chat-app',
    'Aplicativo de chat em tempo real com salas, mensagens privadas e compartilhamento de mídia',
    'Um aplicativo de chat moderno e completo com todas as funcionalidades essenciais. Oferece mensagens em tempo real, criação de salas/grupos, chat privado, compartilhamento de arquivos e imagens, notificações push, status online/offline, histórico de mensagens e interface intuitiva. Perfeito para comunidades, equipes ou aplicações que precisam de comunicação em tempo real.',
    (SELECT id FROM template_categories WHERE name = 'Chat & Social'),
    'Supabase Team',
    'templates@supabase.com',
    '1.0.0',
    '["chat", "real-time", "messaging", "social", "websocket", "notifications"]'::jsonb,
    '["Mensagens em tempo real", "Salas/grupos de chat", "Mensagens privadas (DM)", "Compartilhamento de imagens", "Compartilhamento de arquivos", "Status online/offline", "Notificações push", "Histórico de mensagens", "Busca em conversas", "Emojis e reações", "Typing indicators", "Mensagens não lidas", "Perfis de usuário", "Moderação de salas"]'::jsonb,
    '/uploads/thumbnails/chat-app.png',
    'https://chat-demo.supabase.com',
    'https://github.com/supabase/supabase-chat-template',
    'https://docs.supabase.com/templates/chat-app',
    true,
    0.00,
    'published',
    true,
    
    '-- Chat App Schema will be loaded from schema.sql file',
    '-- Chat App Seed data will be loaded from seed.sql file',
    '["send-push-notification", "moderate-message", "process-media-upload"]'::jsonb,
    '{
        "auth": {
            "enabled": true,
            "providers": ["email", "google", "github"],
            "email_confirm": false
        },
        "storage": {
            "enabled": true,
            "buckets": ["chat-media", "user-avatars"]
        },
        "realtime": {
            "enabled": true,
            "tables": ["messages", "rooms", "user_presence"]
        }
    }'::jsonb
),

-- SaaS Dashboard Template
(
    'SaaS Dashboard - Painel Administrativo',
    'saas-dashboard',
    'Dashboard completo para aplicações SaaS com analytics, usuários e configurações',
    'Um painel administrativo profissional para aplicações SaaS. Inclui dashboard com métricas em tempo real, gestão de usuários, sistema de organizações, configurações avançadas, relatórios customizáveis, integração com APIs externas e muito mais. Ideal para quem está construindo uma aplicação SaaS e precisa de uma base sólida.',
    (SELECT id FROM template_categories WHERE name = 'SaaS & Dashboards'),
    'Supabase Team',
    'templates@supabase.com',
    '1.0.0',
    '["saas", "dashboard", "analytics", "admin", "users", "organizations"]'::jsonb,
    '["Dashboard com métricas em tempo real", "Gestão completa de usuários", "Sistema de organizações/times", "Controle de permissões (RBAC)", "Relatórios customizáveis", "Gráficos e charts interativos", "Configurações do sistema", "Audit log de ações", "Notificações internas", "API externa integrations", "Tema claro/escuro", "Responsivo para mobile"]'::jsonb,
    '/uploads/thumbnails/saas-dashboard.png',
    'https://saas-dashboard-demo.supabase.com',
    'https://github.com/supabase/supabase-saas-template',
    'https://docs.supabase.com/templates/saas-dashboard',
    false,
    79.99,
    'published',
    false,
    
    '-- SaaS Dashboard Schema will be loaded from schema.sql file',
    '-- SaaS Dashboard Seed data will be loaded from seed.sql file',
    '["generate-report", "send-email-notification", "sync-external-data"]'::jsonb,
    '{
        "auth": {
            "enabled": true,
            "providers": ["email", "google", "github"],
            "email_confirm": true
        },
        "storage": {
            "enabled": true,
            "buckets": ["reports", "user-uploads"]
        },
        "realtime": {
            "enabled": true,
            "tables": ["notifications", "activities"]
        }
    }'::jsonb
),

-- Simple API Template
(
    'REST API - API Completa com Documentação',
    'rest-api-complete',
    'API REST completa com autenticação, documentação automática e rate limiting',
    'Uma API REST profissional e bem estruturada com todas as funcionalidades essenciais. Inclui endpoints CRUD organizados, autenticação JWT, documentação automática via OpenAPI, rate limiting, validação de dados, logs de auditoria e monitoramento. Perfeita para backends de aplicações ou como microserviço independente.',
    (SELECT id FROM template_categories WHERE name = 'APIs & Backend'),
    'Supabase Team',
    'templates@supabase.com',
    '1.0.0',
    '["api", "rest", "backend", "auth", "documentation", "microservice"]'::jsonb,
    '["Endpoints CRUD organizados", "Autenticação JWT completa", "Documentação OpenAPI automática", "Rate limiting por usuário", "Validação de dados robusta", "Logs de auditoria", "Monitoramento de performance", "Versionamento de API", "Filtros e paginação", "Testes automatizados", "Docker ready", "CI/CD configurado"]'::jsonb,
    '/uploads/thumbnails/rest-api.png',
    'https://api-demo.supabase.com/docs',
    'https://github.com/supabase/supabase-api-template',
    'https://docs.supabase.com/templates/rest-api',
    true,
    0.00,
    'published',
    false,
    
    '-- REST API Schema will be loaded from schema.sql file',
    '-- REST API Seed data will be loaded from seed.sql file',
    '["validate-request", "rate-limiter", "audit-logger"]'::jsonb,
    '{
        "auth": {
            "enabled": true,
            "providers": ["email"],
            "email_confirm": true
        }
    }'::jsonb
)

ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    long_description = EXCLUDED.long_description,
    tags = EXCLUDED.tags,
    features = EXCLUDED.features,
    updated_at = NOW();

-- Update download counts for some templates to simulate usage
UPDATE templates SET downloads_count = 1247 WHERE slug = 'todo-app';
UPDATE templates SET downloads_count = 892 WHERE slug = 'blog-cms';  
UPDATE templates SET downloads_count = 634 WHERE slug = 'chat-app';
UPDATE templates SET downloads_count = 423 WHERE slug = 'ecommerce-store';
UPDATE templates SET downloads_count = 312 WHERE slug = 'saas-dashboard';
UPDATE templates SET downloads_count = 156 WHERE slug = 'rest-api-complete';

-- Add some sample reviews
INSERT INTO template_reviews (template_id, user_email, user_name, rating, review_text, is_verified) VALUES
    ((SELECT id FROM templates WHERE slug = 'todo-app'), 'user1@example.com', 'João Silva', 5, 'Excelente template! Muito bem documentado e fácil de usar. Consegui adaptar para minhas necessidades rapidamente.', true),
    ((SELECT id FROM templates WHERE slug = 'todo-app'), 'user2@example.com', 'Maria Santos', 4, 'Ótimo ponto de partida para aplicações de produtividade. O código está bem organizado.', true),
    ((SELECT id FROM templates WHERE slug = 'blog-cms'), 'user3@example.com', 'Pedro Costa', 5, 'Sistema de blog muito completo! Incluí tudo que precisava para o site da empresa.', true),
    ((SELECT id FROM templates WHERE slug = 'chat-app'), 'user4@example.com', 'Ana Oliveira', 4, 'Aplicativo de chat funcional e moderno. As mensagens em tempo real funcionam perfeitamente.', true),
    ((SELECT id FROM templates WHERE slug = 'ecommerce-store'), 'user5@example.com', 'Carlos Lima', 5, 'Valeu cada centavo! Economizou meses de desenvolvimento. Já estou vendendo online.', true)
ON CONFLICT (template_id, user_email) DO NOTHING;

-- Create some sample template files (this would normally be done when uploading the actual template packages)
INSERT INTO template_files (template_id, file_path, file_type, content, file_size, checksum) VALUES
    ((SELECT id FROM templates WHERE slug = 'todo-app'), 'schema.sql', 'sql', '-- Todo App Schema\n-- Complete schema for todo application', 2048, 'abc123'),
    ((SELECT id FROM templates WHERE slug = 'todo-app'), 'seed.sql', 'sql', '-- Todo App Seed Data\n-- Sample data for testing', 1024, 'def456'),
    ((SELECT id FROM templates WHERE slug = 'todo-app'), 'README.md', 'text', '# Todo App Template\nComplete todo application template', 512, 'ghi789'),
    
    ((SELECT id FROM templates WHERE slug = 'blog-cms'), 'schema.sql', 'sql', '-- Blog CMS Schema\n-- Complete schema for blog/cms', 4096, 'jkl012'),
    ((SELECT id FROM templates WHERE slug = 'blog-cms'), 'seed.sql', 'sql', '-- Blog CMS Seed Data\n-- Sample posts and pages', 2048, 'mno345'),
    
    ((SELECT id FROM templates WHERE slug = 'chat-app'), 'schema.sql', 'sql', '-- Chat App Schema\n-- Real-time messaging schema', 3072, 'pqr678'),
    ((SELECT id FROM templates WHERE slug = 'chat-app'), 'seed.sql', 'sql', '-- Chat App Seed Data\n-- Sample rooms and messages', 1536, 'stu901')
ON CONFLICT DO NOTHING;

-- Log that templates were seeded
INSERT INTO usage_metrics (project_id, organization_id, metric_type, value, period_start, period_end) VALUES
    (1, 1, 'templates_seeded', 6, NOW() - INTERVAL '1 hour', NOW());

-- Print summary
SELECT 
    'Templates inseridos com sucesso!' as status,
    COUNT(*) as total_templates,
    COUNT(*) FILTER (WHERE is_free = true) as free_templates,
    COUNT(*) FILTER (WHERE is_free = false) as paid_templates,
    COUNT(*) FILTER (WHERE is_featured = true) as featured_templates
FROM templates;