-- Block and Report System
-- Created: January 23, 2026
-- ============================================

-- 1. Create blocked_users table
-- ============================================
CREATE TABLE IF NOT EXISTS blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_blocked_blocker ON blocked_users(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocked_blocked ON blocked_users(blocked_id);

-- RLS policies
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;

-- Users can view their own blocks
CREATE POLICY "Users can view own blocks"
    ON blocked_users FOR SELECT
    TO authenticated
    USING (blocker_id = auth.uid());

-- Users can insert their own blocks
CREATE POLICY "Users can block users"
    ON blocked_users FOR INSERT
    TO authenticated
    WITH CHECK (blocker_id = auth.uid());

-- Users can delete their own blocks (unblock)
CREATE POLICY "Users can unblock users"
    ON blocked_users FOR DELETE
    TO authenticated
    USING (blocker_id = auth.uid());


-- 2. Add 'report' to feedback tag options
-- ============================================
-- First, drop the existing constraint
ALTER TABLE user_feedback DROP CONSTRAINT IF EXISTS user_feedback_tag_check;

-- Add new constraint with 'report' included
ALTER TABLE user_feedback ADD CONSTRAINT user_feedback_tag_check 
    CHECK (tag IN ('bug', 'enhancement', 'general', 'report'));

-- Add reported_user_id column to user_feedback for reports
ALTER TABLE user_feedback ADD COLUMN IF NOT EXISTS reported_user_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- Create index for reported user lookups
CREATE INDEX IF NOT EXISTS idx_feedback_reported_user ON user_feedback(reported_user_id) WHERE reported_user_id IS NOT NULL;


-- 3. Block User RPC
-- ============================================
CREATE OR REPLACE FUNCTION block_user(
    p_user_id TEXT,      -- The auth_id of the user doing the blocking
    p_blocked_id TEXT    -- The internal user id of the person being blocked
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_blocker_id UUID;
    v_blocked_uuid UUID;
    v_are_friends BOOLEAN := FALSE;
BEGIN
    -- Get the internal user id for the blocker
    SELECT id INTO v_blocker_id FROM users WHERE auth_id = p_user_id::UUID;
    
    IF v_blocker_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'User not found');
    END IF;
    
    -- Parse the blocked user's ID
    v_blocked_uuid := p_blocked_id::UUID;
    
    -- Check if they are friends (using friendships table)
    SELECT EXISTS (
        SELECT 1 FROM friendships 
        WHERE (user_id = v_blocker_id AND friend_id = v_blocked_uuid)
           OR (user_id = v_blocked_uuid AND friend_id = v_blocker_id)
    ) INTO v_are_friends;
    
    IF NOT v_are_friends THEN
        RETURN json_build_object('success', false, 'error', 'You can only block friends');
    END IF;
    
    -- Can't block yourself
    IF v_blocker_id = v_blocked_uuid THEN
        RETURN json_build_object('success', false, 'error', 'Cannot block yourself');
    END IF;
    
    -- Check if already blocked
    IF EXISTS (SELECT 1 FROM blocked_users WHERE blocker_id = v_blocker_id AND blocked_id = v_blocked_uuid) THEN
        RETURN json_build_object('success', false, 'error', 'User already blocked');
    END IF;
    
    -- Insert block record
    INSERT INTO blocked_users (blocker_id, blocked_id)
    VALUES (v_blocker_id, v_blocked_uuid);
    
    -- Remove the friendship from friendships table
    DELETE FROM friendships 
    WHERE (user_id = v_blocker_id AND friend_id = v_blocked_uuid)
       OR (user_id = v_blocked_uuid AND friend_id = v_blocker_id);
    
    RETURN json_build_object('success', true);
END;
$$;


-- 4. Unblock User RPC
-- ============================================
CREATE OR REPLACE FUNCTION unblock_user(
    p_user_id TEXT,      -- The auth_id of the user doing the unblocking
    p_blocked_id TEXT    -- The internal user id of the person being unblocked
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_blocker_id UUID;
    v_blocked_uuid UUID;
BEGIN
    -- Get the internal user id for the unblocker
    SELECT id INTO v_blocker_id FROM users WHERE auth_id = p_user_id::UUID;
    
    IF v_blocker_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'User not found');
    END IF;
    
    -- Parse the blocked user's ID
    v_blocked_uuid := p_blocked_id::UUID;
    
    -- Delete the block record
    DELETE FROM blocked_users 
    WHERE blocker_id = v_blocker_id AND blocked_id = v_blocked_uuid;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Block not found');
    END IF;
    
    RETURN json_build_object('success', true);
END;
$$;


-- 5. Get Blocked Users RPC
-- ============================================
CREATE OR REPLACE FUNCTION get_blocked_users(p_user_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_blocked_ids UUID[];
BEGIN
    -- Get the internal user id
    SELECT id INTO v_user_id FROM users WHERE auth_id = p_user_id::UUID;
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'User not found', 'blockedIds', '[]'::JSON);
    END IF;
    
    -- Get all blocked user IDs
    SELECT COALESCE(array_agg(blocked_id), ARRAY[]::UUID[])
    INTO v_blocked_ids
    FROM blocked_users
    WHERE blocker_id = v_user_id;
    
    RETURN json_build_object(
        'success', true,
        'blockedIds', v_blocked_ids
    );
END;
$$;


-- 6. Report User RPC
-- ============================================
CREATE OR REPLACE FUNCTION report_user(
    p_user_id TEXT,          -- The auth_id of the reporter
    p_reported_id TEXT,      -- The internal user id of the person being reported
    p_reason TEXT            -- The reason for reporting
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_reporter_id UUID;
    v_reporter_username TEXT;
    v_reported_uuid UUID;
    v_reported_username TEXT;
BEGIN
    -- Get the internal user id and username for the reporter
    SELECT id, username INTO v_reporter_id, v_reporter_username 
    FROM users WHERE auth_id = p_user_id::UUID;
    
    IF v_reporter_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'User not found');
    END IF;
    
    -- Parse the reported user's ID and get their username
    v_reported_uuid := p_reported_id::UUID;
    SELECT username INTO v_reported_username FROM users WHERE id = v_reported_uuid;
    
    IF v_reported_username IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Reported user not found');
    END IF;
    
    -- Can't report yourself
    IF v_reporter_id = v_reported_uuid THEN
        RETURN json_build_object('success', false, 'error', 'Cannot report yourself');
    END IF;
    
    -- Insert the report into user_feedback
    INSERT INTO user_feedback (
        user_id,
        username,
        message,
        tag,
        reported_user_id,
        is_anonymous,
        status
    ) VALUES (
        v_reporter_id,
        v_reporter_username,
        'Reported @' || v_reported_username || ': ' || p_reason,
        'report',
        v_reported_uuid,
        FALSE,
        'pending'
    );
    
    RETURN json_build_object('success', true);
END;
$$;


-- 7. Grant execute permissions
-- ============================================
GRANT EXECUTE ON FUNCTION block_user(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION unblock_user(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_blocked_users(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION report_user(TEXT, TEXT, TEXT) TO authenticated;
