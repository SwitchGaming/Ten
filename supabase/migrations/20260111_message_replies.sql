-- Add reply_to support for messages

-- Add reply_to_id column
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES messages(id) ON DELETE SET NULL;

-- Create index for reply lookups
CREATE INDEX IF NOT EXISTS idx_messages_reply_to ON messages (reply_to_id) WHERE reply_to_id IS NOT NULL;

-- Update send_message function to support replies
CREATE OR REPLACE FUNCTION send_message(
    p_recipient_id UUID,
    p_content TEXT,
    p_reply_to_id UUID DEFAULT NULL
)
RETURNS TABLE (
    message_id UUID,
    conversation_id UUID,
    sender_id UUID,
    content TEXT,
    status message_status,
    created_at TIMESTAMP WITH TIME ZONE,
    reply_to_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conversation_id UUID;
    v_message_id UUID;
    v_sender_id UUID;
    v_created_at TIMESTAMP WITH TIME ZONE := NOW();
    v_preview TEXT;
BEGIN
    -- Get the sender's user ID from their auth ID
    SELECT id INTO v_sender_id
    FROM users
    WHERE auth_id = auth.uid();
    
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Verify users are friends (check both directions)
    IF NOT EXISTS (
        SELECT 1 FROM friendships 
        WHERE (user_id = v_sender_id AND friend_id = p_recipient_id)
           OR (user_id = p_recipient_id AND friend_id = v_sender_id)
    ) THEN
        RAISE EXCEPTION 'Cannot message non-friends';
    END IF;
    
    -- Get or create conversation
    v_conversation_id := get_or_create_conversation(v_sender_id, p_recipient_id);
    
    -- Create preview (first 50 chars)
    v_preview := LEFT(p_content, 50);
    IF LENGTH(p_content) > 50 THEN
        v_preview := v_preview || '...';
    END IF;
    
    -- Insert message with optional reply
    INSERT INTO messages (conversation_id, sender_id, content, status, created_at, reply_to_id)
    VALUES (v_conversation_id, v_sender_id, p_content, 'sent', v_created_at, p_reply_to_id)
    RETURNING id INTO v_message_id;
    
    -- Update conversation with last message info
    UPDATE conversations SET
        last_message_id = v_message_id,
        last_message_preview = v_preview,
        last_message_sender_id = v_sender_id,
        last_message_at = v_created_at,
        updated_at = v_created_at
    WHERE id = v_conversation_id;
    
    -- Return the created message
    RETURN QUERY SELECT 
        v_message_id,
        v_conversation_id,
        v_sender_id,
        p_content,
        'sent'::message_status,
        v_created_at,
        p_reply_to_id;
END;
$$;
