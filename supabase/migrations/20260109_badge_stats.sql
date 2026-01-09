-- Badge Statistics Table for Dynamic Rarity Percentiles
-- This table stores aggregated badge acquisition data for calculating actual rarity

-- Create badge_stats table
CREATE TABLE IF NOT EXISTS badge_stats (
    badge_id TEXT PRIMARY KEY,
    earned_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create a table to track total eligible users (users who have rated at least once)
CREATE TABLE IF NOT EXISTS app_stats (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1), -- Ensure only one row
    total_eligible_users INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert initial row for app_stats
INSERT INTO app_stats (id, total_eligible_users) VALUES (1, 0) ON CONFLICT DO NOTHING;

-- Function to refresh all badge statistics
CREATE OR REPLACE FUNCTION refresh_badge_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    badge_record RECORD;
    user_count INTEGER;
BEGIN
    -- Count total eligible users (users who have at least one rating/post)
    SELECT COUNT(DISTINCT user_id) INTO user_count
    FROM posts;
    
    -- Update app_stats
    UPDATE app_stats 
    SET total_eligible_users = user_count,
        updated_at = NOW()
    WHERE id = 1;
    
    -- Update or insert badge counts
    FOR badge_record IN 
        SELECT badge_id, COUNT(*) as count
        FROM user_badges
        GROUP BY badge_id
    LOOP
        INSERT INTO badge_stats (badge_id, earned_count, updated_at)
        VALUES (badge_record.badge_id, badge_record.count, NOW())
        ON CONFLICT (badge_id) 
        DO UPDATE SET 
            earned_count = badge_record.count,
            updated_at = NOW();
    END LOOP;
    
    -- Set count to 0 for badges no one has (in case badges were removed)
    UPDATE badge_stats 
    SET earned_count = 0, updated_at = NOW()
    WHERE badge_id NOT IN (SELECT DISTINCT badge_id FROM user_badges)
    AND earned_count > 0;
END;
$$;

-- Function to get all badge stats in one call
CREATE OR REPLACE FUNCTION get_all_badge_stats()
RETURNS TABLE (
    badge_id TEXT,
    earned_count INTEGER,
    total_users INTEGER,
    percentage NUMERIC(5,2)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    total_eligible INTEGER;
BEGIN
    -- Get total eligible users
    SELECT total_eligible_users INTO total_eligible
    FROM app_stats
    WHERE id = 1;
    
    -- Return badge stats with calculated percentages
    RETURN QUERY
    SELECT 
        bs.badge_id,
        bs.earned_count,
        total_eligible AS total_users,
        CASE 
            WHEN total_eligible > 0 THEN 
                ROUND((bs.earned_count::NUMERIC / total_eligible * 100), 2)
            ELSE 0
        END AS percentage
    FROM badge_stats bs;
END;
$$;

-- Trigger function to update badge stats when a badge is awarded
CREATE OR REPLACE FUNCTION update_badge_stats_on_award()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Increment the badge count
    INSERT INTO badge_stats (badge_id, earned_count, updated_at)
    VALUES (NEW.badge_id, 1, NOW())
    ON CONFLICT (badge_id) 
    DO UPDATE SET 
        earned_count = badge_stats.earned_count + 1,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$;

-- Create trigger on user_badges table
DROP TRIGGER IF EXISTS badge_awarded_trigger ON user_badges;
CREATE TRIGGER badge_awarded_trigger
    AFTER INSERT ON user_badges
    FOR EACH ROW
    EXECUTE FUNCTION update_badge_stats_on_award();

-- Trigger function to update total users when a new user posts their first rating
CREATE OR REPLACE FUNCTION update_total_users_on_first_post()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    existing_posts INTEGER;
BEGIN
    -- Check if this is the user's first post
    SELECT COUNT(*) INTO existing_posts
    FROM posts
    WHERE user_id = NEW.user_id
    AND id != NEW.id;
    
    IF existing_posts = 0 THEN
        -- This is their first post, increment total users
        UPDATE app_stats 
        SET total_eligible_users = total_eligible_users + 1,
            updated_at = NOW()
        WHERE id = 1;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create trigger on posts table
DROP TRIGGER IF EXISTS first_post_trigger ON posts;
CREATE TRIGGER first_post_trigger
    AFTER INSERT ON posts
    FOR EACH ROW
    EXECUTE FUNCTION update_total_users_on_first_post();

-- Run initial refresh to populate data
SELECT refresh_badge_stats();

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION refresh_badge_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_badge_stats() TO authenticated;
