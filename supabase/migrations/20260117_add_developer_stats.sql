-- Add is_developer column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_developer BOOLEAN DEFAULT FALSE;

-- Create optimized RPC function for app stats (avoids fetching all rows)
CREATE OR REPLACE FUNCTION get_app_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
    today_date DATE := CURRENT_DATE;
    today_timestamp TIMESTAMP := CURRENT_DATE::timestamp;
    week_ago DATE := CURRENT_DATE - INTERVAL '7 days';
    last_week_start DATE := CURRENT_DATE - INTERVAL '14 days';
    last_week_end DATE := CURRENT_DATE - INTERVAL '7 days';
BEGIN
    SELECT json_build_object(
        -- Core user stats
        'total_users', (SELECT COUNT(*) FROM users),
        'users_rated_today', (SELECT COUNT(DISTINCT user_id) FROM rating_history WHERE date = today_date),
        'new_users_this_week', (SELECT COUNT(*) FROM users WHERE created_at >= week_ago),
        'new_users_last_week', (SELECT COUNT(*) FROM users WHERE created_at >= last_week_start AND created_at < last_week_end),
        'premium_users', (SELECT COUNT(*) FROM users WHERE premium_expires_at > NOW()),
        
        -- Content stats (posts and post_replies use 'timestamp' column)
        'total_posts', (SELECT COUNT(*) FROM posts),
        'posts_today', (SELECT COUNT(*) FROM posts WHERE timestamp >= today_timestamp),
        'total_replies', (SELECT COUNT(*) FROM post_replies),
        'replies_today', (SELECT COUNT(*) FROM post_replies WHERE timestamp >= today_timestamp),
        'total_likes', (SELECT COUNT(*) FROM post_likes),
        
        -- Messaging stats (messages uses 'created_at' column)
        'total_messages', (SELECT COUNT(*) FROM messages),
        'messages_today', (SELECT COUNT(*) FROM messages WHERE created_at >= today_timestamp),
        'total_conversations', (SELECT COUNT(*) FROM conversations),
        
        -- Vibe stats
        'total_vibes', (SELECT COUNT(*) FROM vibes),
        'active_vibes', (SELECT COUNT(*) FROM vibes WHERE expires_at > NOW()),
        'total_vibe_responses', (SELECT COUNT(*) FROM vibe_responses),
        
        -- Rating stats
        'total_ratings', (SELECT COUNT(*) FROM rating_history),
        'average_rating_today', (SELECT COALESCE(AVG(rating)::numeric(3,1), 0) FROM rating_history WHERE date = today_date),
        'average_rating_all_time', (SELECT COALESCE(AVG(rating)::numeric(3,1), 0) FROM rating_history),
        
        -- Streak stats (top 5 longest current streaks, anonymized)
        'top_streaks', (
            SELECT COALESCE(json_agg(current_streak ORDER BY current_streak DESC), '[]'::json)
            FROM (SELECT current_streak FROM user_stats ORDER BY current_streak DESC LIMIT 5) s
        ),
        
        -- Badge stats (count per badge type)
        'badge_distribution', (
            SELECT COALESCE(json_object_agg(badge_id, count), '{}'::json)
            FROM (SELECT badge_id, COUNT(*) as count FROM user_badges GROUP BY badge_id) b
        ),
        
        -- Friendship stats
        'total_friendships', (SELECT COUNT(*) FROM friendships),
        'friend_requests_pending', (SELECT COUNT(*) FROM friend_requests WHERE status = 'pending'),
        
        -- Timezone distribution for map
        'timezone_distribution', (
            SELECT COALESCE(json_agg(json_build_object('timezone', timezone, 'count', user_count)), '[]'::json)
            FROM (
                SELECT timezone, COUNT(*) as user_count 
                FROM notification_preferences 
                WHERE timezone IS NOT NULL 
                GROUP BY timezone 
                ORDER BY user_count DESC
            ) tz
        ),
        
        -- Changelog stats
        'total_changelogs', (SELECT COUNT(*) FROM changelog_entries WHERE is_published = true),
        'total_changelog_views', (SELECT COUNT(*) FROM user_changelog_reads),
        'unique_changelog_viewers', (SELECT COUNT(DISTINCT user_id) FROM user_changelog_reads),
        'changelog_view_rate', (
            SELECT CASE 
                WHEN (SELECT COUNT(*) FROM users) > 0 
                THEN ROUND((SELECT COUNT(DISTINCT user_id)::numeric FROM user_changelog_reads) / (SELECT COUNT(*)::numeric FROM users) * 100, 1)
                ELSE 0 
            END
        ),
        'changelog_stats', (
            SELECT COALESCE(json_agg(json_build_object(
                'version', ce.version,
                'title', ce.title,
                'views', COALESCE(ucr.view_count, 0),
                'published_at', ce.published_at
            ) ORDER BY ce.published_at DESC), '[]'::json)
            FROM changelog_entries ce
            LEFT JOIN (
                SELECT version, COUNT(*) as view_count 
                FROM user_changelog_reads 
                GROUP BY version
            ) ucr ON ucr.version = ce.version
            WHERE ce.is_published = true
        )
    ) INTO result;
    
    RETURN result;
END;
$$;

-- Grant execute permission to authenticated users (will check is_developer in app)
GRANT EXECUTE ON FUNCTION get_app_stats() TO authenticated;

-- Create index for faster rating history date queries
CREATE INDEX IF NOT EXISTS idx_rating_history_date ON rating_history(date);
CREATE INDEX IF NOT EXISTS idx_posts_timestamp ON posts(timestamp);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

-- Create function for hourly activity analysis
CREATE OR REPLACE FUNCTION get_hourly_activity(user_timezone TEXT DEFAULT 'UTC')
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    SELECT json_build_object(
        'timezone', user_timezone,
        'total_by_hour', COALESCE((
            SELECT json_object_agg(hour, count)
            FROM (
                SELECT EXTRACT(HOUR FROM (date + created_at::time) AT TIME ZONE user_timezone)::INT as hour,
                       COUNT(*) as count
                FROM rating_history
                WHERE date > CURRENT_DATE - INTERVAL '30 days'
                GROUP BY hour
                ORDER BY hour
            ) hourly
        ), '{}'::json),
        'peak_hour', (
            SELECT EXTRACT(HOUR FROM (date + created_at::time) AT TIME ZONE user_timezone)::INT
            FROM rating_history
            WHERE date > CURRENT_DATE - INTERVAL '30 days'
            GROUP BY EXTRACT(HOUR FROM (date + created_at::time) AT TIME ZONE user_timezone)::INT
            ORDER BY COUNT(*) DESC
            LIMIT 1
        ),
        'activity_by_day', COALESCE((
            SELECT json_object_agg(dow, count)
            FROM (
                SELECT EXTRACT(DOW FROM date)::INT as dow,
                       COUNT(*) as count
                FROM rating_history
                WHERE date > CURRENT_DATE - INTERVAL '30 days'
                GROUP BY dow
                ORDER BY dow
            ) daily
        ), '{}'::json)
    ) INTO result;
    
    RETURN result;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_hourly_activity(TEXT) TO authenticated;

-- ============================================
-- FEEDBACK SYSTEM
-- ============================================

-- Create feedback table
CREATE TABLE IF NOT EXISTS user_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    username TEXT,
    email TEXT,
    message TEXT NOT NULL,
    tag TEXT NOT NULL CHECK (tag IN ('bug', 'enhancement', 'general')),
    is_anonymous BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'deleted')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for feedback queries
CREATE INDEX IF NOT EXISTS idx_feedback_status ON user_feedback(status);
CREATE INDEX IF NOT EXISTS idx_feedback_tag ON user_feedback(tag);
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON user_feedback(created_at DESC);

-- RLS policies for feedback
ALTER TABLE user_feedback ENABLE ROW LEVEL SECURITY;

-- Users can insert their own feedback
CREATE POLICY "Users can insert feedback"
    ON user_feedback FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Users can view their own non-anonymous feedback
CREATE POLICY "Users can view own feedback"
    ON user_feedback FOR SELECT
    TO authenticated
    USING (user_id = auth.uid() AND is_anonymous = false);

-- Developers can view all feedback (checked in app layer)
CREATE POLICY "Developers can view all feedback"
    ON user_feedback FOR SELECT
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_developer = true)
    );

-- Developers can update feedback status
CREATE POLICY "Developers can update feedback"
    ON user_feedback FOR UPDATE
    TO authenticated
    USING (
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_developer = true)
    );

-- Function to submit feedback
CREATE OR REPLACE FUNCTION submit_feedback(
    p_message TEXT,
    p_tag TEXT,
    p_is_anonymous BOOLEAN DEFAULT FALSE
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_username TEXT;
    v_feedback_id UUID;
BEGIN
    -- Get user id from auth_id
    IF NOT p_is_anonymous THEN
        SELECT id, username INTO v_user_id, v_username
        FROM users
        WHERE auth_id = auth.uid();
    END IF;
    
    -- Insert feedback
    INSERT INTO user_feedback (user_id, username, message, tag, is_anonymous)
    VALUES (
        v_user_id,
        v_username,
        p_message,
        p_tag,
        p_is_anonymous
    )
    RETURNING id INTO v_feedback_id;
    
    RETURN json_build_object(
        'success', true,
        'feedback_id', v_feedback_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION submit_feedback(TEXT, TEXT, BOOLEAN) TO authenticated;

-- Function to get feedback for developers
DROP FUNCTION IF EXISTS get_all_feedback(TEXT, TEXT);

CREATE OR REPLACE FUNCTION get_all_feedback(
    p_tag TEXT DEFAULT NULL,
    p_status TEXT DEFAULT 'pending'
)
RETURNS SETOF user_feedback
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is developer (using auth_id)
    IF NOT EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND is_developer = true) THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT *
    FROM user_feedback
    WHERE (p_tag IS NULL OR tag = p_tag)
      AND status = p_status
    ORDER BY created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_all_feedback(TEXT, TEXT) TO authenticated;

-- Function to update feedback status
DROP FUNCTION IF EXISTS update_feedback_status(UUID, TEXT);

CREATE OR REPLACE FUNCTION update_feedback_status(
    p_feedback_id UUID,
    p_status TEXT
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is developer (using auth_id)
    IF NOT EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND is_developer = true) THEN
        RETURN json_build_object('error', 'Unauthorized');
    END IF;
    
    UPDATE user_feedback
    SET status = p_status
    WHERE id = p_feedback_id;
    
    RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION update_feedback_status(UUID, TEXT) TO authenticated;

-- ============================================
-- CHANGELOG SYSTEM
-- ============================================

-- Changelog entries table
CREATE TABLE IF NOT EXISTS changelog_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    version TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    entries JSONB NOT NULL DEFAULT '[]',
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    published_at TIMESTAMP WITH TIME ZONE
);

-- Track which users have read which changelog versions
CREATE TABLE IF NOT EXISTS user_changelog_reads (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    version TEXT NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, version)
);

-- Enable RLS
ALTER TABLE changelog_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_changelog_reads ENABLE ROW LEVEL SECURITY;

-- Everyone can read published changelogs
CREATE POLICY "Anyone can read published changelogs" ON changelog_entries
    FOR SELECT USING (is_published = true);

-- Users can read/write their own changelog read status
CREATE POLICY "Users can manage their changelog reads" ON user_changelog_reads
    FOR ALL USING (user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Function to get changelogs (with read status for current user)
CREATE OR REPLACE FUNCTION get_changelogs()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Get current user's id
    SELECT id INTO v_user_id FROM users WHERE auth_id = auth.uid();
    
    RETURN (
        SELECT COALESCE(json_agg(
            json_build_object(
                'id', c.id,
                'version', c.version,
                'title', c.title,
                'entries', c.entries,
                'published_at', c.published_at,
                'is_read', (ucr.user_id IS NOT NULL)
            ) ORDER BY c.published_at DESC
        ), '[]'::json)
        FROM changelog_entries c
        LEFT JOIN user_changelog_reads ucr ON ucr.version = c.version AND ucr.user_id = v_user_id
        WHERE c.is_published = true
    );
END;
$$;

GRANT EXECUTE ON FUNCTION get_changelogs() TO authenticated;

-- Function to mark changelog as read
CREATE OR REPLACE FUNCTION mark_changelog_read(p_version TEXT)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    SELECT id INTO v_user_id FROM users WHERE auth_id = auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object('error', 'User not found');
    END IF;
    
    INSERT INTO user_changelog_reads (user_id, version)
    VALUES (v_user_id, p_version)
    ON CONFLICT (user_id, version) DO NOTHING;
    
    RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION mark_changelog_read(TEXT) TO authenticated;

-- Function to get unread changelog count
CREATE OR REPLACE FUNCTION get_unread_changelog_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_count INTEGER;
BEGIN
    SELECT id INTO v_user_id FROM users WHERE auth_id = auth.uid();
    
    SELECT COUNT(*) INTO v_count
    FROM changelog_entries c
    WHERE c.is_published = true
    AND NOT EXISTS (
        SELECT 1 FROM user_changelog_reads ucr 
        WHERE ucr.version = c.version AND ucr.user_id = v_user_id
    );
    
    RETURN COALESCE(v_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION get_unread_changelog_count() TO authenticated;

-- Function to create changelog (developers only)
CREATE OR REPLACE FUNCTION create_changelog(
    p_version TEXT,
    p_title TEXT,
    p_entries JSONB,
    p_publish BOOLEAN DEFAULT FALSE
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_changelog_id UUID;
BEGIN
    -- Check if user is developer
    IF NOT EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND is_developer = true) THEN
        RETURN json_build_object('error', 'Unauthorized');
    END IF;
    
    INSERT INTO changelog_entries (version, title, entries, is_published, published_at)
    VALUES (
        p_version, 
        p_title, 
        p_entries, 
        p_publish,
        CASE WHEN p_publish THEN NOW() ELSE NULL END
    )
    RETURNING id INTO v_changelog_id;
    
    RETURN json_build_object('success', true, 'id', v_changelog_id);
END;
$$;

GRANT EXECUTE ON FUNCTION create_changelog(TEXT, TEXT, JSONB, BOOLEAN) TO authenticated;

-- Function to update/publish changelog (developers only)
CREATE OR REPLACE FUNCTION update_changelog(
    p_id UUID,
    p_version TEXT,
    p_title TEXT,
    p_entries JSONB,
    p_publish BOOLEAN
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is developer
    IF NOT EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND is_developer = true) THEN
        RETURN json_build_object('error', 'Unauthorized');
    END IF;
    
    UPDATE changelog_entries
    SET 
        version = p_version,
        title = p_title,
        entries = p_entries,
        is_published = p_publish,
        published_at = CASE 
            WHEN p_publish AND published_at IS NULL THEN NOW() 
            ELSE published_at 
        END
    WHERE id = p_id;
    
    RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION update_changelog(UUID, TEXT, TEXT, JSONB, BOOLEAN) TO authenticated;

-- Function to delete changelog (developers only)
CREATE OR REPLACE FUNCTION delete_changelog(p_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is developer
    IF NOT EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND is_developer = true) THEN
        RETURN json_build_object('error', 'Unauthorized');
    END IF;
    
    DELETE FROM changelog_entries WHERE id = p_id;
    
    RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION delete_changelog(UUID) TO authenticated;

-- Function to get all changelogs for developers (including unpublished)
CREATE OR REPLACE FUNCTION get_all_changelogs()
RETURNS SETOF changelog_entries
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is developer
    IF NOT EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND is_developer = true) THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT * FROM changelog_entries
    ORDER BY created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_all_changelogs() TO authenticated;
