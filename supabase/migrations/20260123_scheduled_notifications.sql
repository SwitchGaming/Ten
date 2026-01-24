-- Scheduled Notification Jobs
-- Created: January 23, 2026
-- Implements: Daily Reminders, Connection of the Week
-- ============================================

-- Enable pg_cron extension (if not already enabled)
-- Note: This needs to be enabled in Supabase Dashboard > Database > Extensions
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================
-- 0. HELPER FUNCTION: Get users for daily reminder
-- ============================================
-- This is called by the Edge Function

CREATE OR REPLACE FUNCTION get_users_for_daily_reminder()
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    timezone TEXT,
    daily_reminder_time TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.display_name,
        COALESCE(np.timezone, 'America/New_York') as timezone,
        COALESCE(np.daily_reminder_time, '19:00') as daily_reminder_time
    FROM users u
    JOIN notification_preferences np ON u.id = np.user_id
    WHERE np.daily_reminders_enabled = TRUE
    -- User hasn't rated today (in their timezone)
    AND (
        u.rating_timestamp IS NULL 
        OR u.rating_timestamp::DATE < (NOW() AT TIME ZONE COALESCE(np.timezone, 'America/New_York'))::DATE
    )
    -- Current time in user's timezone matches their reminder time (within 30 min window)
    AND (
        EXTRACT(HOUR FROM (NOW() AT TIME ZONE COALESCE(np.timezone, 'America/New_York'))) = 
        SPLIT_PART(COALESCE(np.daily_reminder_time, '19:00'), ':', 1)::INT
        AND EXTRACT(MINUTE FROM (NOW() AT TIME ZONE COALESCE(np.timezone, 'America/New_York'))) < 30
    )
    -- Haven't been sent a daily reminder today (in their timezone)
    AND NOT EXISTS (
        SELECT 1 FROM notification_logs nl
        WHERE nl.user_id = u.id
        AND nl.notification_type = 'daily_reminder'
        AND nl.created_at > (NOW() AT TIME ZONE COALESCE(np.timezone, 'America/New_York'))::DATE
    );
END;
$$;

-- ============================================
-- 1. DAILY REMINDERS
-- ============================================
-- This function finds users who:
-- - Have daily_reminders_enabled = true
-- - Haven't rated today
-- - Current time matches their daily_reminder_time (within 15 min window)
-- - Respects their timezone

CREATE OR REPLACE FUNCTION send_daily_reminders()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user RECORD;
    v_sent_count INT := 0;
    v_tokens RECORD;
BEGIN
    -- Find users who should receive a daily reminder right now
    FOR v_user IN
        SELECT 
            u.id,
            u.display_name,
            np.timezone,
            np.daily_reminder_time
        FROM users u
        JOIN notification_preferences np ON u.id = np.user_id
        WHERE np.daily_reminders_enabled = TRUE
        -- User hasn't rated today (in their timezone)
        AND (
            u.rating_timestamp IS NULL 
            OR u.rating_timestamp::DATE < (NOW() AT TIME ZONE COALESCE(np.timezone, 'America/New_York'))::DATE
        )
        -- Current time in user's timezone matches their reminder time (within 30 min window)
        AND (
            EXTRACT(HOUR FROM (NOW() AT TIME ZONE COALESCE(np.timezone, 'America/New_York'))) = 
            EXTRACT(HOUR FROM (np.daily_reminder_time || ':00')::TIME)
            AND EXTRACT(MINUTE FROM (NOW() AT TIME ZONE COALESCE(np.timezone, 'America/New_York'))) < 30
        )
        -- Haven't been sent a daily reminder today
        AND NOT EXISTS (
            SELECT 1 FROM notification_logs nl
            WHERE nl.user_id = u.id
            AND nl.notification_type = 'daily_reminder'
            AND nl.created_at::DATE = (NOW() AT TIME ZONE COALESCE(np.timezone, 'America/New_York'))::DATE
        )
    LOOP
        -- Queue the notification
        INSERT INTO notification_queue (user_id, type, data, deliver_after, processed)
        VALUES (
            v_user.id,
            'daily_reminder',
            json_build_object('userName', v_user.display_name),
            NOW(),
            FALSE
        );
        
        -- Log that we've queued this reminder
        INSERT INTO notification_logs (user_id, notification_type, status)
        VALUES (v_user.id, 'daily_reminder', 'queued');
        
        v_sent_count := v_sent_count + 1;
    END LOOP;
    
    RETURN json_build_object(
        'success', TRUE,
        'reminders_queued', v_sent_count,
        'timestamp', NOW()
    );
END;
$$;


-- ============================================
-- 2. CONNECTION OF THE WEEK
-- ============================================
-- This function:
-- - Runs weekly (Sunday evening)
-- - Generates random friend pairings for all users
-- - Notifies BOTH users in the pairing

CREATE OR REPLACE FUNCTION generate_weekly_connections()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user RECORD;
    v_matched_count INT := 0;
    v_friend_id UUID;
    v_friend_name TEXT;
BEGIN
    -- Find all users who have connection_match_enabled
    FOR v_user IN
        SELECT 
            u.id,
            u.display_name
        FROM users u
        JOIN notification_preferences np ON u.id = np.user_id
        WHERE np.connection_match_enabled = TRUE
        -- User has at least one friend
        AND EXISTS (
            SELECT 1 FROM friendships f 
            WHERE f.user_id = u.id OR f.friend_id = u.id
        )
    LOOP
        -- Find a random friend for this user
        SELECT 
            CASE 
                WHEN f.user_id = v_user.id THEN f.friend_id 
                ELSE f.user_id 
            END,
            u2.display_name
        INTO v_friend_id, v_friend_name
        FROM friendships f
        JOIN users u2 ON u2.id = CASE 
            WHEN f.user_id = v_user.id THEN f.friend_id 
            ELSE f.user_id 
        END
        WHERE f.user_id = v_user.id OR f.friend_id = v_user.id
        ORDER BY RANDOM()
        LIMIT 1;
        
        IF v_friend_id IS NOT NULL THEN
            -- Update or insert the connection match for this user
            INSERT INTO connection_of_week (user_id, matched_user_id, week_start, created_at)
            VALUES (
                v_user.id,
                v_friend_id,
                DATE_TRUNC('week', NOW()),
                NOW()
            )
            ON CONFLICT (user_id, week_start) 
            DO UPDATE SET matched_user_id = EXCLUDED.matched_user_id, created_at = NOW();
            
            -- Queue notification for this user
            INSERT INTO notification_queue (user_id, type, data, deliver_after, processed)
            VALUES (
                v_user.id,
                'connection_match',
                json_build_object(
                    'matchedUserName', v_friend_name,
                    'matchedUserId', v_friend_id::TEXT
                ),
                NOW(),
                FALSE
            );
            
            v_matched_count := v_matched_count + 1;
        END IF;
    END LOOP;
    
    RETURN json_build_object(
        'success', TRUE,
        'connections_generated', v_matched_count,
        'timestamp', NOW()
    );
END;
$$;


-- ============================================
-- 3. PROCESS NOTIFICATION QUEUE
-- ============================================
-- Enhanced function to process queued notifications via Edge Function

CREATE OR REPLACE FUNCTION process_queued_notifications()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_queued RECORD;
    v_processed_count INT := 0;
    v_tokens TEXT[];
BEGIN
    -- Get all unprocessed notifications that are ready
    FOR v_queued IN
        SELECT nq.*, u.display_name as sender_name
        FROM notification_queue nq
        JOIN users u ON u.id = nq.user_id
        WHERE nq.processed = FALSE
        AND nq.deliver_after <= NOW()
        ORDER BY nq.deliver_after ASC
        LIMIT 100 -- Process in batches
    LOOP
        -- Get user's device tokens
        SELECT ARRAY_AGG(token) INTO v_tokens
        FROM device_tokens
        WHERE user_id = v_queued.user_id
        AND token IS NOT NULL;
        
        IF v_tokens IS NOT NULL AND array_length(v_tokens, 1) > 0 THEN
            -- Mark as processed (Edge Function will be called separately)
            UPDATE notification_queue
            SET processed = TRUE
            WHERE id = v_queued.id;
            
            -- Log the notification
            INSERT INTO notification_logs (user_id, notification_type, status)
            VALUES (v_queued.user_id, v_queued.type, 'processed');
            
            v_processed_count := v_processed_count + 1;
        ELSE
            -- No tokens, mark as processed anyway
            UPDATE notification_queue
            SET processed = TRUE
            WHERE id = v_queued.id;
        END IF;
    END LOOP;
    
    RETURN json_build_object(
        'success', TRUE,
        'processed', v_processed_count,
        'timestamp', NOW()
    );
END;
$$;


-- ============================================
-- 4. CREATE CONNECTION_OF_WEEK TABLE IF NOT EXISTS
-- ============================================

CREATE TABLE IF NOT EXISTS connection_of_week (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    matched_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_connection_of_week_user ON connection_of_week(user_id);
CREATE INDEX IF NOT EXISTS idx_connection_of_week_week ON connection_of_week(week_start);


-- ============================================
-- 5. GRANT PERMISSIONS
-- ============================================

GRANT EXECUTE ON FUNCTION get_users_for_daily_reminder() TO authenticated;
GRANT EXECUTE ON FUNCTION send_daily_reminders() TO authenticated;
GRANT EXECUTE ON FUNCTION generate_weekly_connections() TO authenticated;
GRANT EXECUTE ON FUNCTION process_queued_notifications() TO authenticated;


-- ============================================
-- 6. SCHEDULE CRON JOBS (Run in Supabase Dashboard)
-- ============================================
-- These commands need to be run manually in the Supabase SQL Editor
-- after enabling the pg_cron extension in Dashboard > Database > Extensions

-- Daily reminders: Run every 30 minutes to catch users at their preferred time
-- SELECT cron.schedule(
--     'send-daily-reminders',
--     '*/30 * * * *',  -- Every 30 minutes
--     $$SELECT send_daily_reminders()$$
-- );

-- Weekly connections: Run every Sunday at 6 PM UTC
-- SELECT cron.schedule(
--     'generate-weekly-connections',
--     '0 18 * * 0',  -- Sunday at 6 PM UTC
--     $$SELECT generate_weekly_connections()$$
-- );

-- Process notification queue: Run every 5 minutes
-- SELECT cron.schedule(
--     'process-notification-queue',
--     '*/5 * * * *',  -- Every 5 minutes
--     $$SELECT process_queued_notifications()$$
-- );
