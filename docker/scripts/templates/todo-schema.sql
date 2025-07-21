-- Template: Todo App
-- Schema para aplicação de lista de tarefas com autenticação

-- Tabela de perfis de usuário
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    username TEXT UNIQUE,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de listas de tarefas
CREATE TABLE public.todo_lists (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    color TEXT DEFAULT '#3B82F6',
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de tarefas
CREATE TABLE public.todos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
    due_date TIMESTAMP WITH TIME ZONE,
    list_id UUID REFERENCES public.todo_lists(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de tags
CREATE TABLE public.tags (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    color TEXT DEFAULT '#6B7280',
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(name, user_id)
);

-- Tabela de relacionamento tarefas e tags
CREATE TABLE public.todo_tags (
    todo_id UUID REFERENCES public.todos(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES public.tags(id) ON DELETE CASCADE,
    PRIMARY KEY (todo_id, tag_id)
);

-- RLS (Row Level Security)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.todo_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.todo_tags ENABLE ROW LEVEL SECURITY;

-- Políticas de segurança para profiles
CREATE POLICY "Usuários podem ver seu próprio perfil" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Usuários podem atualizar seu próprio perfil" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Usuários podem inserir seu próprio perfil" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Políticas para todo_lists
CREATE POLICY "Usuários podem ver suas próprias listas" ON public.todo_lists
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem criar suas próprias listas" ON public.todo_lists
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuários podem atualizar suas próprias listas" ON public.todo_lists
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem deletar suas próprias listas" ON public.todo_lists
    FOR DELETE USING (auth.uid() = user_id);

-- Políticas para todos
CREATE POLICY "Usuários podem ver suas próprias tarefas" ON public.todos
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem criar suas próprias tarefas" ON public.todos
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuários podem atualizar suas próprias tarefas" ON public.todos
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem deletar suas próprias tarefas" ON public.todos
    FOR DELETE USING (auth.uid() = user_id);

-- Políticas para tags
CREATE POLICY "Usuários podem ver suas próprias tags" ON public.tags
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem criar suas próprias tags" ON public.tags
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Usuários podem atualizar suas próprias tags" ON public.tags
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem deletar suas próprias tags" ON public.tags
    FOR DELETE USING (auth.uid() = user_id);

-- Políticas para todo_tags
CREATE POLICY "Usuários podem ver tags de suas tarefas" ON public.todo_tags
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.todos 
            WHERE todos.id = todo_tags.todo_id 
            AND todos.user_id = auth.uid()
        )
    );

CREATE POLICY "Usuários podem gerenciar tags de suas tarefas" ON public.todo_tags
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.todos 
            WHERE todos.id = todo_tags.todo_id 
            AND todos.user_id = auth.uid()
        )
    );

-- Função para criar perfil automaticamente
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para criar perfil automaticamente
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Função para atualizar timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para atualizar timestamp automaticamente
CREATE TRIGGER handle_updated_at_profiles
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at_todo_lists
    BEFORE UPDATE ON public.todo_lists
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at_todos
    BEFORE UPDATE ON public.todos
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Views úteis
CREATE OR REPLACE VIEW public.todos_with_tags AS
SELECT 
    t.*,
    COALESCE(
        JSON_AGG(
            JSON_BUILD_OBJECT('id', tag.id, 'name', tag.name, 'color', tag.color)
        ) FILTER (WHERE tag.id IS NOT NULL),
        '[]'::json
    ) AS tags
FROM public.todos t
LEFT JOIN public.todo_tags tt ON t.id = tt.todo_id
LEFT JOIN public.tags tag ON tt.tag_id = tag.id
GROUP BY t.id, t.title, t.description, t.completed, t.priority, t.due_date, t.list_id, t.user_id, t.created_at, t.updated_at;

-- Dados de exemplo
INSERT INTO public.tags (name, color, user_id) VALUES 
('Urgente', '#EF4444', (SELECT id FROM auth.users LIMIT 1)),
('Trabalho', '#3B82F6', (SELECT id FROM auth.users LIMIT 1)),
('Pessoal', '#10B981', (SELECT id FROM auth.users LIMIT 1));

INSERT INTO public.todo_lists (title, description, user_id) VALUES 
('Tarefas Pessoais', 'Minhas tarefas do dia a dia', (SELECT id FROM auth.users LIMIT 1)),
('Trabalho', 'Tarefas relacionadas ao trabalho', (SELECT id FROM auth.users LIMIT 1));

-- Comentários para documentação
COMMENT ON TABLE public.profiles IS 'Perfis de usuário estendidos';
COMMENT ON TABLE public.todo_lists IS 'Listas de organização de tarefas';
COMMENT ON TABLE public.todos IS 'Tarefas individuais';
COMMENT ON TABLE public.tags IS 'Tags para categorização';
COMMENT ON TABLE public.todo_tags IS 'Relacionamento muitos-para-muitos entre tarefas e tags';