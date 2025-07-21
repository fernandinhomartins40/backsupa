-- Template: E-commerce
-- Schema completo para loja online com produtos, pedidos e pagamentos

-- Tabela de perfis de cliente
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT,
    full_name TEXT,
    phone TEXT,
    avatar_url TEXT,
    birth_date DATE,
    gender TEXT CHECK (gender IN ('M', 'F', 'other')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de endereços
CREATE TABLE public.addresses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT DEFAULT 'shipping' CHECK (type IN ('shipping', 'billing')),
    is_default BOOLEAN DEFAULT FALSE,
    street TEXT NOT NULL,
    number TEXT,
    complement TEXT,
    neighborhood TEXT,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    zip_code TEXT NOT NULL,
    country TEXT DEFAULT 'BR',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de categorias de produtos
CREATE TABLE public.categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    description TEXT,
    image_url TEXT,
    parent_id UUID REFERENCES public.categories(id),
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de marcas
CREATE TABLE public.brands (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    slug TEXT UNIQUE NOT NULL,
    description TEXT,
    logo_url TEXT,
    website TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de produtos
CREATE TABLE public.products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    description TEXT,
    short_description TEXT,
    sku TEXT UNIQUE,
    barcode TEXT,
    price DECIMAL(10,2) NOT NULL,
    compare_price DECIMAL(10,2),
    cost_price DECIMAL(10,2),
    weight DECIMAL(8,3),
    dimensions JSONB, -- {width, height, depth}
    brand_id UUID REFERENCES public.brands(id),
    category_id UUID REFERENCES public.categories(id),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'draft')),
    featured BOOLEAN DEFAULT FALSE,
    digital BOOLEAN DEFAULT FALSE,
    requires_shipping BOOLEAN DEFAULT TRUE,
    track_inventory BOOLEAN DEFAULT TRUE,
    inventory_quantity INTEGER DEFAULT 0,
    low_stock_threshold INTEGER DEFAULT 10,
    allow_backorder BOOLEAN DEFAULT FALSE,
    seo_title TEXT,
    seo_description TEXT,
    tags TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de imagens de produtos
CREATE TABLE public.product_images (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    alt_text TEXT,
    is_primary BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de variantes de produtos
CREATE TABLE public.product_variants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    sku TEXT UNIQUE,
    barcode TEXT,
    price DECIMAL(10,2),
    compare_price DECIMAL(10,2),
    cost_price DECIMAL(10,2),
    inventory_quantity INTEGER DEFAULT 0,
    weight DECIMAL(8,3),
    requires_shipping BOOLEAN DEFAULT TRUE,
    image_url TEXT,
    options JSONB, -- {color: "red", size: "M"}
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de carrinho de compras
CREATE TABLE public.carts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_id TEXT,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '30 days'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de itens do carrinho
CREATE TABLE public.cart_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cart_id UUID REFERENCES public.carts(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    variant_id UUID REFERENCES public.product_variants(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(cart_id, product_id, variant_id)
);

-- Tabela de cupons de desconto
CREATE TABLE public.coupons (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    description TEXT,
    type TEXT NOT NULL CHECK (type IN ('percentage', 'fixed_amount', 'free_shipping')),
    value DECIMAL(10,2) NOT NULL,
    minimum_amount DECIMAL(10,2),
    usage_limit INTEGER,
    used_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de pedidos
CREATE TABLE public.orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_number TEXT UNIQUE NOT NULL,
    user_id UUID REFERENCES public.profiles(id),
    email TEXT NOT NULL,
    phone TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')),
    payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded', 'partially_refunded')),
    shipping_status TEXT DEFAULT 'pending' CHECK (shipping_status IN ('pending', 'processing', 'shipped', 'delivered', 'returned')),
    
    -- Totais
    subtotal DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    shipping_amount DECIMAL(10,2) DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) NOT NULL,
    
    -- Endereços
    shipping_address JSONB NOT NULL,
    billing_address JSONB,
    
    -- Cupom aplicado
    coupon_id UUID REFERENCES public.coupons(id),
    coupon_code TEXT,
    
    -- Observações
    notes TEXT,
    customer_notes TEXT,
    
    -- Timestamps importantes
    confirmed_at TIMESTAMP WITH TIME ZONE,
    shipped_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de itens do pedido
CREATE TABLE public.order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id),
    variant_id UUID REFERENCES public.product_variants(id),
    product_name TEXT NOT NULL,
    variant_title TEXT,
    sku TEXT,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de pagamentos
CREATE TABLE public.payments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('credit_card', 'debit_card', 'pix', 'boleto', 'paypal')),
    provider TEXT, -- stripe, mercadopago, etc
    provider_transaction_id TEXT,
    amount DECIMAL(10,2) NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded')),
    gateway_response JSONB,
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de avaliações
CREATE TABLE public.reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    order_id UUID REFERENCES public.orders(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title TEXT,
    content TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    is_approved BOOLEAN DEFAULT TRUE,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(product_id, user_id, order_id)
);

-- Tabela de lista de desejos
CREATE TABLE public.wishlists (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

-- Habilitar RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlists ENABLE ROW LEVEL SECURITY;

-- Políticas de segurança
CREATE POLICY "Usuários podem ver próprio perfil" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Usuários podem atualizar próprio perfil" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Usuários podem gerenciar próprios endereços" ON public.addresses
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem gerenciar próprio carrinho" ON public.carts
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem gerenciar itens do próprio carrinho" ON public.cart_items
    FOR ALL USING (
        cart_id IN (SELECT id FROM public.carts WHERE user_id = auth.uid())
    );

CREATE POLICY "Usuários podem ver próprios pedidos" ON public.orders
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem gerenciar próprias avaliações" ON public.reviews
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Usuários podem gerenciar própria wishlist" ON public.wishlists
    FOR ALL USING (auth.uid() = user_id);

-- Políticas para dados públicos
CREATE POLICY "Categorias são públicas" ON public.categories
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Marcas são públicas" ON public.brands
    FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Produtos ativos são públicos" ON public.products
    FOR SELECT USING (status = 'active');

CREATE POLICY "Imagens de produtos são públicas" ON public.product_images
    FOR SELECT USING (TRUE);

CREATE POLICY "Variantes são públicas" ON public.product_variants
    FOR SELECT USING (TRUE);

CREATE POLICY "Avaliações aprovadas são públicas" ON public.reviews
    FOR SELECT USING (is_approved = TRUE);

-- Funções auxiliares
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Função para gerar número do pedido
CREATE OR REPLACE FUNCTION public.generate_order_number()
RETURNS TEXT AS $$
DECLARE
    new_number TEXT;
BEGIN
    SELECT 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD((COUNT(*) + 1)::TEXT, 4, '0')
    INTO new_number
    FROM public.orders
    WHERE DATE(created_at) = DATE(NOW());
    
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Função para calcular média de avaliações
CREATE OR REPLACE FUNCTION public.calculate_product_rating(product_uuid UUID)
RETURNS DECIMAL AS $$
DECLARE
    avg_rating DECIMAL;
BEGIN
    SELECT ROUND(AVG(rating), 1)
    INTO avg_rating
    FROM public.reviews
    WHERE product_id = product_uuid AND is_approved = TRUE;
    
    RETURN COALESCE(avg_rating, 0);
END;
$$ LANGUAGE plpgsql;

-- Views úteis
CREATE OR REPLACE VIEW public.products_with_stats AS
SELECT 
    p.*,
    b.name AS brand_name,
    c.name AS category_name,
    (SELECT url FROM public.product_images pi WHERE pi.product_id = p.id AND pi.is_primary = TRUE LIMIT 1) AS primary_image,
    public.calculate_product_rating(p.id) AS average_rating,
    (SELECT COUNT(*) FROM public.reviews r WHERE r.product_id = p.id AND r.is_approved = TRUE) AS review_count,
    (SELECT COUNT(*) FROM public.wishlists w WHERE w.product_id = p.id) AS wishlist_count
FROM public.products p
LEFT JOIN public.brands b ON p.brand_id = b.id
LEFT JOIN public.categories c ON p.category_id = c.id;

-- Índices para performance
CREATE INDEX idx_products_category_id ON public.products(category_id);
CREATE INDEX idx_products_brand_id ON public.products(brand_id);
CREATE INDEX idx_products_status ON public.products(status);
CREATE INDEX idx_products_featured ON public.products(featured);
CREATE INDEX idx_orders_user_id ON public.orders(user_id);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_created_at ON public.orders(created_at);
CREATE INDEX idx_reviews_product_id ON public.reviews(product_id);
CREATE INDEX idx_cart_items_cart_id ON public.cart_items(cart_id);

-- Dados de exemplo
INSERT INTO public.brands (name, slug, description) VALUES 
('Apple', 'apple', 'Produtos eletrônicos premium'),
('Samsung', 'samsung', 'Tecnologia inovadora'),
('Nike', 'nike', 'Artigos esportivos');

INSERT INTO public.categories (name, slug, description) VALUES 
('Eletrônicos', 'eletronicos', 'Produtos eletrônicos em geral'),
('Smartphones', 'smartphones', 'Telefones móveis'),
('Roupas', 'roupas', 'Vestuário em geral');

INSERT INTO public.coupons (code, description, type, value, minimum_amount) VALUES 
('WELCOME10', 'Desconto de boas-vindas', 'percentage', 10.00, 100.00),
('FRETEGRATIS', 'Frete grátis', 'free_shipping', 0.00, 50.00);

-- Comentários
COMMENT ON TABLE public.products IS 'Catálogo de produtos da loja';
COMMENT ON TABLE public.orders IS 'Pedidos realizados pelos clientes';
COMMENT ON TABLE public.carts IS 'Carrinhos de compra dos usuários';
COMMENT ON TABLE public.reviews IS 'Avaliações de produtos pelos clientes';