-- Todo App - Schema SQL
-- Complete task management system with categories and real-time sync

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Categories table
CREATE TABLE categories (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    color VARCHAR(7) DEFAULT '#3B82F6', -- Hex color
    icon VARCHAR(50) DEFAULT 'folder',
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- Todos table
CREATE TABLE todos (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    priority INTEGER DEFAULT 1 CHECK (priority >= 1 AND priority <= 5), -- 1=low, 5=urgent
    due_date TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    position INTEGER DEFAULT 0, -- For manual ordering
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Activity log for tracking changes
CREATE TABLE todo_activities (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    todo_id UUID REFERENCES todos(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- 'created', 'updated', 'completed', 'deleted'
    old_values JSONB,
    new_values JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_todos_user_id ON todos(user_id);
CREATE INDEX idx_todos_category_id ON todos(category_id);
CREATE INDEX idx_todos_completed ON todos(completed);
CREATE INDEX idx_todos_due_date ON todos(due_date) WHERE due_date IS NOT NULL;
CREATE INDEX idx_todos_priority ON todos(priority);
CREATE INDEX idx_todos_tags ON todos USING GIN(tags);
CREATE INDEX idx_categories_user_id ON categories(user_id);
CREATE INDEX idx_todo_activities_todo_id ON todo_activities(todo_id);
CREATE INDEX idx_todo_activities_user_id ON todo_activities(user_id);

-- Row Level Security (RLS) policies

-- Enable RLS
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;
ALTER TABLE todo_activities ENABLE ROW LEVEL SECURITY;

-- Categories policies
CREATE POLICY "Users can view their own categories" ON categories
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own categories" ON categories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own categories" ON categories
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own categories" ON categories
    FOR DELETE USING (auth.uid() = user_id);

-- Todos policies
CREATE POLICY "Users can view their own todos" ON todos
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own todos" ON todos
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own todos" ON todos
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own todos" ON todos
    FOR DELETE USING (auth.uid() = user_id);

-- Activities policies
CREATE POLICY "Users can view their own todo activities" ON todo_activities
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create todo activities" ON todo_activities
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Functions

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_todos_updated_at
    BEFORE UPDATE ON todos
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to log todo activities
CREATE OR REPLACE FUNCTION log_todo_activity()
RETURNS TRIGGER AS $$
DECLARE
    action_type VARCHAR(50);
    old_data JSONB;
    new_data JSONB;
BEGIN
    -- Determine action type
    IF TG_OP = 'INSERT' THEN
        action_type = 'created';
        old_data = NULL;
        new_data = row_to_json(NEW)::jsonb;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Check if completed status changed
        IF OLD.completed = FALSE AND NEW.completed = TRUE THEN
            action_type = 'completed';
            NEW.completed_at = NOW();
        ELSE
            action_type = 'updated';
        END IF;
        old_data = row_to_json(OLD)::jsonb;
        new_data = row_to_json(NEW)::jsonb;
    ELSIF TG_OP = 'DELETE' THEN
        action_type = 'deleted';
        old_data = row_to_json(OLD)::jsonb;
        new_data = NULL;
    END IF;

    -- Insert activity log
    INSERT INTO todo_activities (todo_id, user_id, action, old_values, new_values)
    VALUES (
        COALESCE(NEW.id, OLD.id),
        COALESCE(NEW.user_id, OLD.user_id),
        action_type,
        old_data,
        new_data
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger for activity logging
CREATE TRIGGER log_todo_activity_trigger
    AFTER INSERT OR UPDATE OR DELETE ON todos
    FOR EACH ROW
    EXECUTE FUNCTION log_todo_activity();

-- Views

-- View for todo statistics
CREATE OR REPLACE VIEW todo_stats AS
SELECT 
    user_id,
    COUNT(*) as total_todos,
    COUNT(*) FILTER (WHERE completed = true) as completed_todos,
    COUNT(*) FILTER (WHERE completed = false) as pending_todos,
    COUNT(*) FILTER (WHERE due_date < NOW() AND completed = false) as overdue_todos,
    COUNT(*) FILTER (WHERE due_date >= NOW() AND due_date <= NOW() + INTERVAL '1 day' AND completed = false) as due_today,
    COUNT(*) FILTER (WHERE priority >= 4) as high_priority_todos
FROM todos
GROUP BY user_id;

-- View for recent activities
CREATE OR REPLACE VIEW recent_activities AS
SELECT 
    ta.*,
    t.title as todo_title
FROM todo_activities ta
LEFT JOIN todos t ON ta.todo_id = t.id
ORDER BY ta.created_at DESC;

-- Utility functions

-- Function to get user's todo statistics
CREATE OR REPLACE FUNCTION get_user_todo_stats(user_uuid UUID)
RETURNS TABLE(
    total_todos BIGINT,
    completed_todos BIGINT,
    pending_todos BIGINT,
    overdue_todos BIGINT,
    due_today BIGINT,
    high_priority_todos BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ts.total_todos,
        ts.completed_todos,
        ts.pending_todos,
        ts.overdue_todos,
        ts.due_today,
        ts.high_priority_todos
    FROM todo_stats ts
    WHERE ts.user_id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search todos
CREATE OR REPLACE FUNCTION search_todos(user_uuid UUID, search_term TEXT, limit_count INTEGER DEFAULT 20)
RETURNS TABLE(
    id UUID,
    title VARCHAR(500),
    description TEXT,
    completed BOOLEAN,
    priority INTEGER,
    due_date TIMESTAMP WITH TIME ZONE,
    category_name VARCHAR(100),
    category_color VARCHAR(7),
    created_at TIMESTAMP WITH TIME ZONE,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.title,
        t.description,
        t.completed,
        t.priority,
        t.due_date,
        c.name as category_name,
        c.color as category_color,
        t.created_at,
        ts_rank(
            to_tsvector('portuguese', t.title || ' ' || COALESCE(t.description, '') || ' ' || array_to_string(t.tags, ' ')),
            plainto_tsquery('portuguese', search_term)
        ) as rank
    FROM todos t
    LEFT JOIN categories c ON t.category_id = c.id
    WHERE t.user_id = user_uuid
    AND (
        to_tsvector('portuguese', t.title || ' ' || COALESCE(t.description, '') || ' ' || array_to_string(t.tags, ' '))
        @@ plainto_tsquery('portuguese', search_term)
        OR t.title ILIKE '%' || search_term || '%'
        OR t.description ILIKE '%' || search_term || '%'
        OR search_term = ANY(t.tags)
    )
    ORDER BY rank DESC, t.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments for documentation
COMMENT ON TABLE categories IS 'User-defined categories for organizing todos';
COMMENT ON TABLE todos IS 'Main todos table with full task management features';
COMMENT ON TABLE todo_activities IS 'Activity log for tracking all changes to todos';
COMMENT ON VIEW todo_stats IS 'Real-time statistics for user todos';
COMMENT ON FUNCTION get_user_todo_stats(UUID) IS 'Get comprehensive todo statistics for a user';
COMMENT ON FUNCTION search_todos(UUID, TEXT, INTEGER) IS 'Full-text search across user todos with ranking';