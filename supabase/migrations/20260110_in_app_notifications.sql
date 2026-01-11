-- Migration: Create in_app_notifications table for check-in alerts and other in-app notifications
-- Date: 2026-01-10

CREATE TABLE IF NOT EXISTS in_app_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sender_name TEXT NOT NULL,
    type TEXT NOT NULL,  -- 'check_in_alert', 'check_in_response', etc.
    message TEXT,
    data JSONB,  -- Additional data if needed
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

-- Index for fast lookup by recipient
CREATE INDEX idx_in_app_notifications_recipient ON in_app_notifications(recipient_id, is_read, created_at DESC);

-- Index for cleanup of old notifications
CREATE INDEX idx_in_app_notifications_created ON in_app_notifications(created_at);

-- Enable RLS
ALTER TABLE in_app_notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own notifications
-- Join against users table to match auth.uid() with the users table's auth_id
CREATE POLICY "Users can view own notifications" ON in_app_notifications
    FOR SELECT USING (
        recipient_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
        OR sender_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
    );

-- Policy: Users can insert notifications for others (sender must match their user id via auth_id)
CREATE POLICY "Users can create notifications" ON in_app_notifications
    FOR INSERT WITH CHECK (
        sender_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
    );

-- Policy: Recipients can update their own notifications (mark as read)
CREATE POLICY "Recipients can update own notifications" ON in_app_notifications
    FOR UPDATE USING (
        recipient_id IN (SELECT id FROM users WHERE auth_id = auth.uid())
    );

-- Add column to notification_preferences if not exists
ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS check_in_alerts_enabled BOOLEAN DEFAULT TRUE;

COMMENT ON TABLE in_app_notifications IS 'Stores in-app notifications including check-in alerts between friends';
COMMENT ON COLUMN in_app_notifications.type IS 'Notification type: check_in_alert, check_in_response, etc.';
