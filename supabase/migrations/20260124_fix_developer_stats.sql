-- Fix developer stats to use rolling 24-hour window and improve timezone accuracy
-- This addresses:
-- 1. "Today" stats now use rolling 24 hours (UTC-based) instead of server midnight
-- 2. Timezone distribution now shows ALL users (with default fallback for missing prefs)
-- 3. Better handling of rating_history which stores client-local dates

-- Drop and recreate the function with fixes
CREATE OR REPLACE FUNCTION get_app_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
    -- Use UTC-based timestamps for consistency
    now_utc TIMESTAMP WITH TIME ZONE := NOW();
    twenty_four_hours_ago TIMESTAMP WITH TIME ZONE := NOW() - INTERVAL '24 hours';
    week_ago TIMESTAMP WITH TIME ZONE := NOW() - INTERVAL '7 days';
    last_week_start TIMESTAMP WITH TIME ZONE := NOW() - INTERVAL '14 days';
    last_week_end TIMESTAMP WITH TIME ZONE := NOW() - INTERVAL '7 days';
BEGIN
    SELECT json_build_object(
        -- Core user stats
        'total_users', (SELECT COUNT(*) FROM users),
        -- Users who rated in last 24 hours (using created_at timestamp, not date)
        'users_rated_today', (
            SELECT COUNT(DISTINCT user_id) 
            FROM rating_history 
            WHERE created_at >= twenty_four_hours_ago
        ),
        'new_users_this_week', (SELECT COUNT(*) FROM users WHERE created_at >= week_ago),
        'new_users_last_week', (SELECT COUNT(*) FROM users WHERE created_at >= last_week_start AND created_at < last_week_end),
        'premium_users', (SELECT COUNT(*) FROM users WHERE premium_expires_at > now_utc),
        
        -- Content stats - use rolling 24 hours
        'total_posts', (SELECT COUNT(*) FROM posts),
        'posts_today', (SELECT COUNT(*) FROM posts WHERE timestamp >= twenty_four_hours_ago),
        'total_replies', (SELECT COUNT(*) FROM post_replies),
        'replies_today', (SELECT COUNT(*) FROM post_replies WHERE timestamp >= twenty_four_hours_ago),
        'total_likes', (SELECT COUNT(*) FROM post_likes),
        
        -- Messaging stats - use rolling 24 hours
        'total_messages', (SELECT COUNT(*) FROM messages),
        'messages_today', (SELECT COUNT(*) FROM messages WHERE created_at >= twenty_four_hours_ago),
        'total_conversations', (SELECT COUNT(*) FROM conversations),
        
        -- Vibe stats
        'total_vibes', (SELECT COUNT(*) FROM vibes),
        'active_vibes', (SELECT COUNT(*) FROM vibes WHERE expires_at > now_utc),
        'total_vibe_responses', (SELECT COUNT(*) FROM vibe_responses),
        
        -- Rating stats - use rolling 24 hours for "today"
        'total_ratings', (SELECT COUNT(*) FROM rating_history),
        'average_rating_today', (
            SELECT COALESCE(AVG(rating)::numeric(3,1), 0) 
            FROM rating_history 
            WHERE created_at >= twenty_four_hours_ago
        ),
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
        
        -- Timezone distribution - now includes ALL users with fallback for missing prefs
        'timezone_distribution', (
            SELECT COALESCE(json_agg(json_build_object('timezone', tz, 'count', user_count) ORDER BY user_count DESC), '[]'::json)
            FROM (
                SELECT 
                    COALESCE(np.timezone, 'Unknown') as tz,
                    COUNT(*) as user_count 
                FROM users u
                LEFT JOIN notification_preferences np ON np.user_id = u.id
                GROUP BY COALESCE(np.timezone, 'Unknown')
                ORDER BY user_count DESC
            ) tz_data
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

-- Fix hourly activity to be more accurate
-- Uses created_at timestamp (UTC) and shows activity in UTC for consistency
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
        -- Activity by hour of day (using created_at timestamp converted to user timezone)
        'total_by_hour', COALESCE((
            SELECT json_object_agg(hour, count)
            FROM (
                SELECT 
                    EXTRACT(HOUR FROM created_at AT TIME ZONE user_timezone)::INT as hour,
                    COUNT(*) as count
                FROM rating_history
                WHERE created_at > NOW() - INTERVAL '30 days'
                GROUP BY hour
                ORDER BY hour
            ) hourly
        ), '{}'::json),
        -- Peak hour calculation
        'peak_hour', (
            SELECT EXTRACT(HOUR FROM created_at AT TIME ZONE user_timezone)::INT
            FROM rating_history
            WHERE created_at > NOW() - INTERVAL '30 days'
            GROUP BY EXTRACT(HOUR FROM created_at AT TIME ZONE user_timezone)::INT
            ORDER BY COUNT(*) DESC
            LIMIT 1
        ),
        -- Activity by day of week
        'activity_by_day', COALESCE((
            SELECT json_object_agg(dow, count)
            FROM (
                SELECT 
                    EXTRACT(DOW FROM created_at AT TIME ZONE user_timezone)::INT as dow,
                    COUNT(*) as count
                FROM rating_history
                WHERE created_at > NOW() - INTERVAL '30 days'
                GROUP BY dow
                ORDER BY dow
            ) daily
        ), '{}'::json)
    ) INTO result;
    
    RETURN result;
END;
$$;

-- Add index on rating_history.created_at for faster "last 24 hours" queries
CREATE INDEX IF NOT EXISTS idx_rating_history_created_at ON rating_history(created_at);

-- Ensure created_at column exists and has a default (may already exist)
-- If rating_history doesn't have created_at, add it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'rating_history' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE rating_history ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        
        -- Backfill created_at from date column for existing records
        UPDATE rating_history 
        SET created_at = date::timestamp with time zone + TIME '12:00:00'
        WHERE created_at IS NULL;
    END IF;
END $$;

-- Add comment explaining the stats
COMMENT ON FUNCTION get_app_stats() IS 
'Returns comprehensive app statistics. 
- "today" metrics use a rolling 24-hour window (UTC-based)
- Timezone distribution includes ALL users (unknown for those without preferences)
- All timestamps compared in UTC for consistency across timezones';
