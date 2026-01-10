-- Add soft delete support for conversations (per-user basis)
-- When a user deletes a conversation, it's only hidden for them, not the other participant

-- Add deleted_by array to track which users have deleted the conversation
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS deleted_by UUID[] DEFAULT '{}';

-- Create index for efficient deleted_by lookups
CREATE INDEX IF NOT EXISTS idx_conversations_deleted_by ON conversations USING GIN (deleted_by);

-- Drop existing function first (required because return type is changing)
DROP FUNCTION IF EXISTS get_conversations_with_unread();

-- Update the get_conversations_with_unread function to exclude deleted conversations
CREATE OR REPLACE FUNCTION get_conversations_with_unread()
RETURNS TABLE (
    id UUID,
    participant_ids UUID[],
    last_message_preview TEXT,
    last_message_sender_id UUID,
    last_message_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    unread_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Get the user's ID from their auth ID
    SELECT u.id INTO v_user_id
    FROM users u
    WHERE u.auth_id = auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        c.id,
        c.participant_ids,
        c.last_message_preview,
        c.last_message_sender_id,
        c.last_message_at,
        c.created_at,
        c.updated_at,
        COALESCE(
            (SELECT COUNT(*) 
             FROM messages m 
             WHERE m.conversation_id = c.id 
             AND m.sender_id != v_user_id 
             AND m.status != 'read'),
            0
        ) as unread_count
    FROM conversations c
    WHERE v_user_id = ANY(c.participant_ids)
    AND NOT (v_user_id = ANY(COALESCE(c.deleted_by, '{}')))
    ORDER BY c.last_message_at DESC NULLS LAST;
END;
$$;

-- Function to delete a conversation for a specific user (soft delete)
CREATE OR REPLACE FUNCTION delete_conversation_for_user(p_conversation_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Get the user's ID from their auth ID
    SELECT u.id INTO v_user_id
    FROM users u
    WHERE u.auth_id = auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Verify user is a participant
    IF NOT EXISTS (
        SELECT 1 FROM conversations c 
        WHERE c.id = p_conversation_id 
        AND v_user_id = ANY(c.participant_ids)
    ) THEN
        RAISE EXCEPTION 'Conversation not found or access denied';
    END IF;
    
    -- Add user to deleted_by array (if not already there)
    UPDATE conversations
    SET deleted_by = array_append(COALESCE(deleted_by, '{}'), v_user_id)
    WHERE id = p_conversation_id
    AND NOT (v_user_id = ANY(COALESCE(deleted_by, '{}')));
    
    RETURN TRUE;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION delete_conversation_for_user(UUID) TO authenticated;
