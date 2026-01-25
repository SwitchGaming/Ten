-- Comprehensive delete account function
-- Deletes ALL user data from ALL tables and removes the auth user

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS delete_user_account(UUID);

-- Create comprehensive delete function
-- Uses dynamic SQL to handle tables that may or may not exist
CREATE OR REPLACE FUNCTION delete_user_account(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
    v_auth_id UUID;
BEGIN
    -- Get the auth_id for this user
    SELECT auth_id INTO v_auth_id FROM users WHERE id = p_user_id;
    
    IF v_auth_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;

    -- =====================================================
    -- DELETE FROM TABLES THAT EXIST
    -- Many tables have ON DELETE CASCADE, so deleting from
    -- users table will cascade to child tables
    -- =====================================================
    
    -- Delete from tables that reference users but might not cascade
    -- Using EXECUTE to handle tables that may not exist
    
    -- Messages where user is sender
    BEGIN
        DELETE FROM messages WHERE sender_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        -- Table or column doesn't exist, skip
    END;
    
    -- Conversations where user is participant
    BEGIN
        DELETE FROM conversations WHERE p_user_id = ANY(participant_ids);
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        -- Table or column doesn't exist, skip
    END;
    
    -- Message reactions
    BEGIN
        DELETE FROM message_reactions WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- In-app notifications (both as sender and receiver)
    BEGIN
        DELETE FROM in_app_notifications WHERE sender_id = p_user_id;
        DELETE FROM in_app_notifications WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Notification queue
    BEGIN
        DELETE FROM notification_queue WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- User feedback
    BEGIN
        DELETE FROM user_feedback WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- User changelog reads
    BEGIN
        DELETE FROM user_changelog_reads WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Blocked users (both directions)
    BEGIN
        DELETE FROM blocked_users WHERE blocker_id = p_user_id OR blocked_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Ambassadors
    BEGIN
        DELETE FROM ambassadors WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Referral codes
    BEGIN
        DELETE FROM referral_codes WHERE ambassador_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Premium transactions
    BEGIN
        DELETE FROM premium_transactions WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Connection of week
    BEGIN
        DELETE FROM connection_of_week WHERE user_id = p_user_id OR matched_user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Ambassador invitations
    BEGIN
        DELETE FROM ambassador_invitations WHERE invited_user_id = p_user_id OR invited_by_user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Delete OTP records
    BEGIN
        DELETE FROM delete_account_otps WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Posts
    BEGIN
        DELETE FROM posts WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Post likes
    BEGIN
        DELETE FROM post_likes WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Post replies
    BEGIN
        DELETE FROM post_replies WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Vibes
    BEGIN
        DELETE FROM vibes WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Vibe responses
    BEGIN
        DELETE FROM vibe_responses WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Friend groups
    BEGIN
        DELETE FROM friend_group_members WHERE user_id = p_user_id OR friend_id = p_user_id;
        DELETE FROM friend_groups WHERE owner_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Friend requests
    BEGIN
        DELETE FROM friend_requests WHERE sender_id = p_user_id OR receiver_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Friendships
    BEGIN
        DELETE FROM friendships WHERE user_id = p_user_id OR friend_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Rating history
    BEGIN
        DELETE FROM rating_history WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- User badges
    BEGIN
        DELETE FROM user_badges WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- User stats
    BEGIN
        DELETE FROM user_stats WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Device tokens
    BEGIN
        DELETE FROM device_tokens WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Notification preferences
    BEGIN
        DELETE FROM notification_preferences WHERE user_id = p_user_id;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        NULL;
    END;
    
    -- Finally, delete the user profile (this will cascade to remaining child tables)
    DELETE FROM users WHERE id = p_user_id;
    
    -- Delete the auth user (this removes them from Supabase Auth)
    DELETE FROM auth.users WHERE id = v_auth_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account(UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION delete_user_account(UUID) IS 'Comprehensively deletes all user data from all tables and removes the auth user.';
