-- Template: Aplicação Web
-- Schema para aplicação web com autenticação, perfis e notificações

-- Tabela de perfis de usuário
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    username TEXT UNIQUE,
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    website TEXT,
    location TEXT,
    birth_date DATE,
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de posts/conteúdo
CREATE TABLE public.posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    content TEXT,
    excerpt TEXT,
    featured_image TEXT,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    type TEXT DEFAULT 'post' CHECK (type IN ('post', 'page', 'article')),
    author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de categorias
CREATE TABLE public.categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    color TEXT DEFAULT '#6B7280',
    icon TEXT,
    parent_id UUID REFERENCES public.categories(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de tags
CREATE TABLE public.tags (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    color TEXT DEFAULT '#6B7280',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Relacionamento posts e categorias
CREATE TABLE public.post_categories (
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, category_id)
);

-- Relacionamento posts e tags
CREATE TABLE public.post_tags (
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES public.tags(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, tag_id)
);

-- Tabela de comentários
CREATE TABLE public.comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    content TEXT NOT NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    author_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.comments(id),
    is_approved BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de likes/reações
CREATE TABLE public.reactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    type TEXT NOT NULL CHECK (type IN ('like', 'dislike', 'love', 'laugh', 'angry', 'sad')),
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

-- Tabela de seguidores
CREATE TABLE public.follows (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    follower_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    following_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK (follower_id != following_id)
);

-- Tabela de notificações
CREATE TABLE public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow', 'mention', 'system')),
    title TEXT NOT NULL,
    message TEXT,
    data JSONB DEFAULT '{}',
    recipient_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Políticas para profiles
CREATE POLICY "Perfis públicos visíveis" ON public.profiles
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Usuários podem atualizar próprio perfil" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Políticas para posts
CREATE POLICY "Posts publicados são visíveis" ON public.posts
    FOR SELECT USING (status = 'published');

CREATE POLICY "Autores podem gerenciar próprios posts" ON public.posts
    FOR ALL USING (auth.uid() = author_id);

-- Políticas para comentários
CREATE POLICY "Comentários aprovados são visíveis" ON public.comments
    FOR SELECT USING (is_approved = TRUE);

CREATE POLICY "Usuários podem criar comentários" ON public.comments
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Autores podem atualizar próprios comentários" ON public.comments
    FOR UPDATE USING (auth.uid() = author_id);

-- Políticas para reações
CREATE POLICY "Reações são visíveis" ON public.reactions
    FOR SELECT USING (TRUE);

CREATE POLICY "Usuários podem gerenciar próprias reações" ON public.reactions
    FOR ALL USING (auth.uid() = user_id);

-- Políticas para follows
CREATE POLICY "Seguidores são visíveis" ON public.follows
    FOR SELECT USING (TRUE);

CREATE POLICY "Usuários podem gerenciar próprios follows" ON public.follows
    FOR ALL USING (auth.uid() = follower_id);

-- Políticas para notificações
CREATE POLICY "Usuários veem próprias notificações" ON public.notifications
    FOR SELECT USING (auth.uid() = recipient_id);

CREATE POLICY "Usuários podem atualizar próprias notificações" ON public.notifications
    FOR UPDATE USING (auth.uid() = recipient_id);

-- Funções e triggers
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, email, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'username',
        NEW.email,
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Função para gerar slug
CREATE OR REPLACE FUNCTION public.generate_slug(title TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN LOWER(
        REGEXP_REPLACE(
            REGEXP_REPLACE(title, '[^a-zA-Z0-9\s-]', '', 'g'),
            '\s+', '-', 'g'
        )
    );
END;
$$ LANGUAGE plpgsql;

-- Função para atualizar timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para timestamps
CREATE TRIGGER handle_updated_at_profiles
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at_posts
    BEFORE UPDATE ON public.posts
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at_comments
    BEFORE UPDATE ON public.comments
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Função para criar notificação
CREATE OR REPLACE FUNCTION public.create_notification(
    p_type TEXT,
    p_title TEXT,
    p_message TEXT,
    p_recipient_id UUID,
    p_sender_id UUID DEFAULT NULL,
    p_data JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO public.notifications (type, title, message, recipient_id, sender_id, data)
    VALUES (p_type, p_title, p_message, p_recipient_id, p_sender_id, p_data)
    RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Views úteis
CREATE OR REPLACE VIEW public.posts_with_stats AS
SELECT 
    p.*,
    u.username AS author_username,
    u.full_name AS author_name,
    u.avatar_url AS author_avatar,
    (SELECT COUNT(*) FROM public.reactions r WHERE r.post_id = p.id) AS total_reactions,
    (SELECT COUNT(*) FROM public.comments c WHERE c.post_id = p.id AND c.is_approved = TRUE) AS total_comments,
    COALESCE(
        JSON_AGG(
            JSON_BUILD_OBJECT('id', c.id, 'name', c.name, 'slug', c.slug)
        ) FILTER (WHERE c.id IS NOT NULL),
        '[]'::json
    ) AS categories,
    COALESCE(
        JSON_AGG(
            JSON_BUILD_OBJECT('id', t.id, 'name', t.name, 'slug', t.slug)
        ) FILTER (WHERE t.id IS NOT NULL),
        '[]'::json
    ) AS tags
FROM public.posts p
LEFT JOIN public.profiles u ON p.author_id = u.id
LEFT JOIN public.post_categories pc ON p.id = pc.post_id
LEFT JOIN public.categories c ON pc.category_id = c.id
LEFT JOIN public.post_tags pt ON p.id = pt.post_id
LEFT JOIN public.tags t ON pt.tag_id = t.id
GROUP BY p.id, u.username, u.full_name, u.avatar_url;

-- Índices para performance
CREATE INDEX idx_posts_author_id ON public.posts(author_id);
CREATE INDEX idx_posts_status ON public.posts(status);
CREATE INDEX idx_posts_published_at ON public.posts(published_at);
CREATE INDEX idx_comments_post_id ON public.comments(post_id);
CREATE INDEX idx_reactions_post_id ON public.reactions(post_id);
CREATE INDEX idx_reactions_user_id ON public.reactions(user_id);
CREATE INDEX idx_notifications_recipient_id ON public.notifications(recipient_id);
CREATE INDEX idx_notifications_read_at ON public.notifications(read_at);

-- Dados de exemplo
INSERT INTO public.categories (name, slug, description, color) VALUES 
('Tecnologia', 'tecnologia', 'Posts sobre tecnologia e desenvolvimento', '#3B82F6'),
('Lifestyle', 'lifestyle', 'Posts sobre estilo de vida', '#10B981'),
('Negócios', 'negocios', 'Conteúdo sobre empreendedorismo e negócios', '#F59E0B');

INSERT INTO public.tags (name, slug, description) VALUES 
('React', 'react', 'Framework JavaScript'),
('JavaScript', 'javascript', 'Linguagem de programação'),
('Tutorial', 'tutorial', 'Conteúdo educativo'),
('Dicas', 'dicas', 'Dicas úteis');

-- Comentários
COMMENT ON TABLE public.profiles IS 'Perfis de usuário com informações estendidas';
COMMENT ON TABLE public.posts IS 'Posts/artigos do sistema';
COMMENT ON TABLE public.comments IS 'Sistema de comentários';
COMMENT ON TABLE public.reactions IS 'Sistema de reações/likes';
COMMENT ON TABLE public.follows IS 'Sistema de seguidores';
COMMENT ON TABLE public.notifications IS 'Sistema de notificações';