-- Notification Queue table for quiet hours and batching
CREATE TABLE IF NOT EXISTS notification_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deliver_after TIMESTAMPTZ NOT NULL,
    processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMPTZ
);

-- Enable RLS on notification_queue
ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;

-- Users can only view their own queued notifications
CREATE POLICY "Users can view own queued notifications"
ON notification_queue FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Only service role can insert (edge function uses service role)
CREATE POLICY "Service role can insert notifications"
ON notification_queue FOR INSERT
TO service_role
WITH CHECK (true);

-- Only service role can update (for processing)
CREATE POLICY "Service role can update notifications"
ON notification_queue FOR UPDATE
TO service_role
USING (true);

-- Only service role can delete (for cleanup)
CREATE POLICY "Service role can delete notifications"
ON notification_queue FOR DELETE
TO service_role
USING (true);

-- Index for efficient queue processing
CREATE INDEX IF NOT EXISTS idx_notification_queue_deliver 
ON notification_queue(deliver_after, processed) 
WHERE processed = FALSE;

CREATE INDEX IF NOT EXISTS idx_notification_queue_user 
ON notification_queue(user_id, type, created_at) 
WHERE processed = FALSE;

-- Add new columns to notification_preferences
ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS quiet_hours_enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS vibe_responses_enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS connection_match_enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS daily_reminder_enabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS daily_reminder_time TEXT DEFAULT '19:00',
ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'America/New_York';

-- Add rate limiting tracking to notification_logs
ALTER TABLE notification_logs
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Index for rate limiting checks
CREATE INDEX IF NOT EXISTS idx_notification_logs_rate_limit 
ON notification_logs(user_id, notification_type, created_at);

-- Function to process notification queue (called by pg_cron)
CREATE OR REPLACE FUNCTION process_notification_queue()
RETURNS void AS $$
DECLARE
    queued_notification RECORD;
    notification_count INTEGER;
BEGIN
    -- Process notifications that are due
    FOR queued_notification IN 
        SELECT * FROM notification_queue 
        WHERE processed = FALSE 
        AND deliver_after <= NOW()
        ORDER BY deliver_after ASC
        LIMIT 100
    LOOP
        -- Call the edge function via pg_net or mark for external processing
        -- For now, just mark as needing processing
        -- The edge function will be called from the cron job
        
        UPDATE notification_queue 
        SET processed = TRUE, processed_at = NOW()
        WHERE id = queued_notification.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Clean up old processed notifications (older than 7 days)
CREATE OR REPLACE FUNCTION cleanup_notification_queue()
RETURNS void AS $$
BEGIN
    DELETE FROM notification_queue 
    WHERE processed = TRUE 
    AND processed_at < NOW() - INTERVAL '7 days';
    
    -- Also delete unprocessed notifications older than 24 hours (stale)
    DELETE FROM notification_queue 
    WHERE processed = FALSE 
    AND created_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

-- Note: Set up pg_cron jobs in Supabase dashboard:
-- SELECT cron.schedule('process-notification-queue', '*/5 * * * *', 'SELECT process_notification_queue()');
-- SELECT cron.schedule('cleanup-notification-queue', '0 3 * * *', 'SELECT cleanup_notification_queue()');
