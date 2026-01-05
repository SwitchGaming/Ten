-- Migration: Add premium fields to users table
-- This allows other users to see someone's premium status and theme

-- Add premium_expires_at column
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMPTZ DEFAULT NULL;

-- Add selected_theme_id column
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS selected_theme_id TEXT DEFAULT NULL;

-- Create index for premium users lookup (simple index, filtering done at query time)
CREATE INDEX IF NOT EXISTS idx_users_premium_expires 
ON users(premium_expires_at) 
WHERE premium_expires_at IS NOT NULL;

-- Add comments
COMMENT ON COLUMN users.premium_expires_at IS 'When the user''s ten+ premium subscription expires. NULL means not premium.';
COMMENT ON COLUMN users.selected_theme_id IS 'The theme ID selected by the premium user. Options: default, ocean, forest, sunset, aurora, rose';
