-- Add new notification preference columns for DMs and friend ratings
-- Date: 2026-01-17

-- Add direct_messages_enabled column (default true - users want DM notifications)
ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS direct_messages_enabled BOOLEAN DEFAULT TRUE;

-- Add friend_ratings_enabled column (default false - opt-in for rating notifications)
ALTER TABLE notification_preferences 
ADD COLUMN IF NOT EXISTS friend_ratings_enabled BOOLEAN DEFAULT FALSE;

-- Update any existing rows to have defaults
UPDATE notification_preferences 
SET direct_messages_enabled = TRUE 
WHERE direct_messages_enabled IS NULL;

UPDATE notification_preferences 
SET friend_ratings_enabled = FALSE 
WHERE friend_ratings_enabled IS NULL;
