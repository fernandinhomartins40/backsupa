-- Todo App - Seed Data
-- Sample data for demonstration and testing

-- Note: This seed data will be inserted for demo purposes only
-- In production, users will create their own categories and todos

-- Insert sample categories (these would typically be created by the first user)
-- The auth.uid() will need to be replaced with actual user IDs after authentication

-- Sample user UUID for demonstration (this should be replaced with real user ID)
-- In a real app, this would be done via the application after user signup

INSERT INTO categories (id, user_id, name, color, icon, sort_order) VALUES
    (uuid_generate_v4(), auth.uid(), 'Trabalho', '#EF4444', 'work', 1),
    (uuid_generate_v4(), auth.uid(), 'Pessoal', '#3B82F6', 'person', 2),
    (uuid_generate_v4(), auth.uid(), 'Estudos', '#10B981', 'school', 3),
    (uuid_generate_v4(), auth.uid(), 'Casa', '#F59E0B', 'home', 4),
    (uuid_generate_v4(), auth.uid(), 'Saúde', '#EC4899', 'favorite', 5)
ON CONFLICT (user_id, name) DO NOTHING;

-- Function to create sample todos for a user
CREATE OR REPLACE FUNCTION create_sample_todos_for_user(user_uuid UUID)
RETURNS VOID AS $$
DECLARE
    work_category_id UUID;
    personal_category_id UUID;
    study_category_id UUID;
    home_category_id UUID;
    health_category_id UUID;
BEGIN
    -- Get category IDs for the user
    SELECT id INTO work_category_id FROM categories WHERE user_id = user_uuid AND name = 'Trabalho';
    SELECT id INTO personal_category_id FROM categories WHERE user_id = user_uuid AND name = 'Pessoal';
    SELECT id INTO study_category_id FROM categories WHERE user_id = user_uuid AND name = 'Estudos';
    SELECT id INTO home_category_id FROM categories WHERE user_id = user_uuid AND name = 'Casa';
    SELECT id INTO health_category_id FROM categories WHERE user_id = user_uuid AND name = 'Saúde';

    -- Create sample categories if they don't exist
    IF work_category_id IS NULL THEN
        INSERT INTO categories (user_id, name, color, icon, sort_order) 
        VALUES (user_uuid, 'Trabalho', '#EF4444', 'work', 1)
        RETURNING id INTO work_category_id;
    END IF;

    IF personal_category_id IS NULL THEN
        INSERT INTO categories (user_id, name, color, icon, sort_order) 
        VALUES (user_uuid, 'Pessoal', '#3B82F6', 'person', 2)
        RETURNING id INTO personal_category_id;
    END IF;

    IF study_category_id IS NULL THEN
        INSERT INTO categories (user_id, name, color, icon, sort_order) 
        VALUES (user_uuid, 'Estudos', '#10B981', 'school', 3)
        RETURNING id INTO study_category_id;
    END IF;

    IF home_category_id IS NULL THEN
        INSERT INTO categories (user_id, name, color, icon, sort_order) 
        VALUES (user_uuid, 'Casa', '#F59E0B', 'home', 4)
        RETURNING id INTO home_category_id;
    END IF;

    IF health_category_id IS NULL THEN
        INSERT INTO categories (user_id, name, color, icon, sort_order) 
        VALUES (user_uuid, 'Saúde', '#EC4899', 'favorite', 5)
        RETURNING id INTO health_category_id;
    END IF;

    -- Insert sample todos
    INSERT INTO todos (user_id, category_id, title, description, completed, priority, due_date, tags, position) VALUES
        -- Work todos
        (user_uuid, work_category_id, 'Finalizar relatório mensal', 'Completar o relatório de vendas do mês de Janeiro com todas as métricas necessárias', false, 4, NOW() + INTERVAL '2 days', ARRAY['relatório', 'vendas', 'urgente'], 1),
        (user_uuid, work_category_id, 'Reunião com equipe de produto', 'Discutir roadmap Q2 e priorizar features para próximo sprint', false, 3, NOW() + INTERVAL '1 day', ARRAY['reunião', 'produto', 'roadmap'], 2),
        (user_uuid, work_category_id, 'Code review PR #234', 'Revisar implementação do novo sistema de autenticação', false, 3, NOW() + INTERVAL '4 hours', ARRAY['code-review', 'auth'], 3),
        (user_uuid, work_category_id, 'Atualizar documentação API', 'Documentar novos endpoints da API v2', false, 2, NOW() + INTERVAL '1 week', ARRAY['documentação', 'api'], 4),
        (user_uuid, work_category_id, 'Backup semanal dos dados', 'Verificar se todos os backups estão funcionando corretamente', true, 1, NOW() - INTERVAL '1 day', ARRAY['backup', 'manutenção'], 5),

        -- Personal todos
        (user_uuid, personal_category_id, 'Comprar presente aniversário', 'Encontrar um presente especial para aniversário da Maria', false, 4, NOW() + INTERVAL '3 days', ARRAY['presente', 'aniversário'], 1),
        (user_uuid, personal_category_id, 'Renovar documentos', 'Renovar CNH e RG que vencem este mês', false, 3, NOW() + INTERVAL '2 weeks', ARRAY['documentos', 'renovação'], 2),
        (user_uuid, personal_category_id, 'Planejar viagem de férias', 'Pesquisar destinos e fazer orçamento para viagem de julho', false, 2, NOW() + INTERVAL '1 month', ARRAY['viagem', 'férias', 'planejamento'], 3),
        (user_uuid, personal_category_id, 'Ligar para dentista', 'Agendar consulta de limpeza semestral', false, 2, NOW() + INTERVAL '3 days', ARRAY['saúde', 'dentista'], 4),

        -- Study todos
        (user_uuid, study_category_id, 'Terminar curso React Avançado', 'Completar os últimos 3 módulos do curso online', false, 3, NOW() + INTERVAL '2 weeks', ARRAY['react', 'curso', 'frontend'], 1),
        (user_uuid, study_category_id, 'Ler livro Clean Architecture', 'Continuar leitura - estou no capítulo 8', false, 2, NOW() + INTERVAL '1 month', ARRAY['livro', 'arquitetura', 'software'], 2),
        (user_uuid, study_category_id, 'Praticar algoritmos', 'Resolver pelo menos 5 problemas de algoritmos por semana', false, 3, NOW() + INTERVAL '7 days', ARRAY['algoritmos', 'prática', 'código'], 3),
        (user_uuid, study_category_id, 'Assistir palestra sobre GraphQL', 'Palestra gravada da conferência sobre GraphQL e performance', true, 1, NOW() - INTERVAL '2 days', ARRAY['graphql', 'palestra'], 4),

        -- Home todos
        (user_uuid, home_category_id, 'Consertar torneira da cozinha', 'Torneira está vazando, precisa trocar o vedante', false, 4, NOW() + INTERVAL '1 day', ARRAY['reparo', 'cozinha', 'urgente'], 1),
        (user_uuid, home_category_id, 'Organizar escritório em casa', 'Organizar mesa e arquivos do home office', false, 2, NOW() + INTERVAL '1 week', ARRAY['organização', 'escritório'], 2),
        (user_uuid, home_category_id, 'Compras do mês', 'Lista de compras para supermercado: arroz, feijão, frutas, verduras', false, 3, NOW() + INTERVAL '2 days', ARRAY['compras', 'supermercado'], 3),
        (user_uuid, home_category_id, 'Limpar ar condicionado', 'Manutenção preventiva dos aparelhos de ar condicionado', false, 2, NOW() + INTERVAL '1 week', ARRAY['limpeza', 'manutenção'], 4),

        -- Health todos
        (user_uuid, health_category_id, 'Consulta médica anual', 'Check-up geral com exames de rotina', false, 3, NOW() + INTERVAL '2 weeks', ARRAY['médico', 'checkup', 'exames'], 1),
        (user_uuid, health_category_id, 'Academia - treino de pernas', 'Treino focado em pernas e glúteos', false, 2, NOW() + INTERVAL '1 day', ARRAY['academia', 'treino', 'pernas'], 2),
        (user_uuid, health_category_id, 'Tomar vitamina D', 'Lembrar de tomar suplemento de vitamina D diariamente', true, 1, NOW(), ARRAY['vitamina', 'suplemento'], 3),
        (user_uuid, health_category_id, 'Caminhada no parque', 'Caminhar pelo menos 30 minutos no parque', false, 2, NOW() + INTERVAL '1 day', ARRAY['caminhada', 'exercício', 'parque'], 4);

END;
$$ LANGUAGE plpgsql;

-- Function to be called after user registration
-- This can be triggered by the application or a database trigger
CREATE OR REPLACE FUNCTION setup_new_user_todos()
RETURNS TRIGGER AS $$
BEGIN
    -- Wait a bit to ensure user is properly created
    PERFORM pg_sleep(1);
    
    -- Create sample data for new user
    PERFORM create_sample_todos_for_user(NEW.id);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on auth.users to setup todos for new users
-- Note: This trigger will only work if this template has access to auth.users
-- Otherwise, the application should call create_sample_todos_for_user() after user registration

-- DROP TRIGGER IF EXISTS setup_new_user_todos_trigger ON auth.users;
-- CREATE TRIGGER setup_new_user_todos_trigger
--     AFTER INSERT ON auth.users
--     FOR EACH ROW
--     EXECUTE FUNCTION setup_new_user_todos();

-- Alternative: Create a function that can be called by the application
CREATE OR REPLACE FUNCTION initialize_user_todos(user_email TEXT DEFAULT NULL)
RETURNS TEXT AS $$
DECLARE
    target_user_id UUID;
    result_message TEXT;
BEGIN
    -- Get user ID
    IF user_email IS NOT NULL THEN
        SELECT id INTO target_user_id FROM auth.users WHERE email = user_email;
    ELSE
        target_user_id := auth.uid();
    END IF;

    IF target_user_id IS NULL THEN
        RETURN 'Usuário não encontrado';
    END IF;

    -- Check if user already has todos
    IF EXISTS (SELECT 1 FROM todos WHERE user_id = target_user_id LIMIT 1) THEN
        RETURN 'Usuário já possui tarefas criadas';
    END IF;

    -- Create sample data
    PERFORM create_sample_todos_for_user(target_user_id);
    
    RETURN 'Dados de exemplo criados com sucesso! Você pode agora explorar a aplicação com tarefas de demonstração.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create some helpful statistics views for the demo
CREATE OR REPLACE VIEW demo_statistics AS
SELECT 
    'Total de Categorias' as metric,
    COUNT(*)::TEXT as value,
    'Organize suas tarefas em categorias personalizadas' as description
FROM categories
UNION ALL
SELECT 
    'Total de Tarefas' as metric,
    COUNT(*)::TEXT as value,
    'Gerencie todas as suas atividades em um só lugar' as description
FROM todos
UNION ALL
SELECT 
    'Tarefas Concluídas' as metric,
    COUNT(*)::TEXT as value,
    'Acompanhe seu progresso e produtividade' as description
FROM todos WHERE completed = true
UNION ALL
SELECT 
    'Tarefas Pendentes' as metric,
    COUNT(*)::TEXT as value,
    'Mantenha o foco no que precisa ser feito' as description
FROM todos WHERE completed = false;

-- Instructions for users
COMMENT ON FUNCTION initialize_user_todos(TEXT) IS 'Cria dados de exemplo para um usuário. Chame esta função após criar sua conta para ter tarefas de demonstração.';
COMMENT ON FUNCTION create_sample_todos_for_user(UUID) IS 'Função interna para criar dados de exemplo';
COMMENT ON VIEW demo_statistics IS 'Estatísticas gerais da aplicação de tarefas';

-- Final note: 
-- Para ativar os dados de exemplo, execute: SELECT initialize_user_todos();
-- Isso criará categorias e tarefas de demonstração para o usuário logado.