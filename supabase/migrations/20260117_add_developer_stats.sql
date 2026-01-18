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
