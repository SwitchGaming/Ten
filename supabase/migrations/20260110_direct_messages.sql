-- Direct Messaging Tables
-- Optimized for minimal queries with denormalized last_message data

-- Message status enum
CREATE TYPE message_status AS ENUM ('sent', 'delivered', 'read');

-- Conversations table (1:1 chats between friends)
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participant_ids UUID[] NOT NULL CHECK (array_length(participant_ids, 1) = 2),
    last_message_id UUID,
    last_message_preview TEXT,
    last_message_sender_id UUID,
    last_message_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique conversation between two users (order-independent)
    CONSTRAINT unique_participants UNIQUE (participant_ids)
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (length(content) > 0 AND length(content) <= 2000),
    status message_status NOT NULL DEFAULT 'sent',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_conversations_participant ON conversations USING GIN (participant_ids);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON conversations (updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages (conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages (sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_status ON messages (conversation_id, status) WHERE status != 'read';

-- Add foreign key for last_message_id after messages table exists
ALTER TABLE conversations 
    ADD CONSTRAINT fk_last_message 
    FOREIGN KEY (last_message_id) 
    REFERENCES messages(id) 
    ON DELETE SET NULL;

-- RLS Policies
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Conversations: Users can only see conversations they're part of
CREATE POLICY "Users can view own conversations" ON conversations
    FOR SELECT USING (auth.uid() = ANY(participant_ids));

CREATE POLICY "Users can insert conversations they're part of" ON conversations
    FOR INSERT WITH CHECK (auth.uid() = ANY(participant_ids));

CREATE POLICY "Users can update own conversations" ON conversations
    FOR UPDATE USING (auth.uid() = ANY(participant_ids));

-- Messages: Users can only see messages in their conversations
CREATE POLICY "Users can view messages in own conversations" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = messages.conversation_id 
            AND auth.uid() = ANY(c.participant_ids)
        )
    );

CREATE POLICY "Users can insert messages in own conversations" ON messages
    FOR INSERT WITH CHECK (
        sender_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = conversation_id 
            AND auth.uid() = ANY(c.participant_ids)
        )
    );

CREATE POLICY "Users can update message status in own conversations" ON messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = messages.conversation_id 
            AND auth.uid() = ANY(c.participant_ids)
        )
    );

-- Function to get or create conversation between two users
CREATE OR REPLACE FUNCTION get_or_create_conversation(user1_id UUID, user2_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    conv_id UUID;
    sorted_ids UUID[];
BEGIN
    -- Sort participant IDs for consistent storage
    sorted_ids := ARRAY(SELECT unnest(ARRAY[user1_id, user2_id]) ORDER BY 1);
    
    -- Try to find existing conversation
    SELECT id INTO conv_id
    FROM conversations
    WHERE participant_ids = sorted_ids;
    
    -- If not found, create new conversation
    IF conv_id IS NULL THEN
        INSERT INTO conversations (participant_ids)
        VALUES (sorted_ids)
        RETURNING id INTO conv_id;
    END IF;
    
    RETURN conv_id;
END;
$$;

-- Function to send a message (creates conversation if needed, updates last_message)
CREATE OR REPLACE FUNCTION send_message(
    p_recipient_id UUID,
    p_content TEXT
)
RETURNS TABLE (
    message_id UUID,
    conversation_id UUID,
    sender_id UUID,
    content TEXT,
    status message_status,
    created_at TIMESTAMP WITH TIME ZONE
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
    
    -- Insert message
    INSERT INTO messages (conversation_id, sender_id, content, status, created_at)
    VALUES (v_conversation_id, v_sender_id, p_content, 'sent', v_created_at)
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
        v_created_at;
END;
$$;

-- Function to mark messages as read (batch operation)
CREATE OR REPLACE FUNCTION mark_messages_read(p_conversation_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_count INTEGER;
BEGIN
    -- Get user ID from auth ID
    SELECT id INTO v_user_id FROM users WHERE auth_id = auth.uid();
    
    -- Mark all unread messages from other user as read
    UPDATE messages
    SET status = 'read', read_at = NOW()
    WHERE conversation_id = p_conversation_id
      AND sender_id != v_user_id
      AND status != 'read';
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

-- Function to mark messages as delivered (called when recipient opens app)
CREATE OR REPLACE FUNCTION mark_messages_delivered(p_conversation_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_count INTEGER;
BEGIN
    -- Get user ID from auth ID
    SELECT id INTO v_user_id FROM users WHERE auth_id = auth.uid();
    
    -- Mark all 'sent' messages from other user as delivered
    UPDATE messages
    SET status = 'delivered'
    WHERE conversation_id = p_conversation_id
      AND sender_id != v_user_id
      AND status = 'sent';
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

-- Function to get conversations with unread count
CREATE OR REPLACE FUNCTION get_conversations_with_unread()
RETURNS TABLE (
    id UUID,
    participant_ids UUID[],
    last_message_preview TEXT,
    last_message_sender_id UUID,
    last_message_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    unread_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Get user ID from auth ID
    SELECT users.id INTO v_user_id FROM users WHERE auth_id = auth.uid();
    
    RETURN QUERY
    SELECT 
        c.id,
        c.participant_ids,
        c.last_message_preview,
        c.last_message_sender_id,
        c.last_message_at,
        c.updated_at,
        COUNT(m.id) FILTER (WHERE m.sender_id != v_user_id AND m.status != 'read') AS unread_count
    FROM conversations c
    LEFT JOIN messages m ON m.conversation_id = c.id
    WHERE v_user_id = ANY(c.participant_ids)
    GROUP BY c.id
    ORDER BY c.updated_at DESC NULLS LAST;
END;
$$;

-- Function to get total unread message count (for badge)
CREATE OR REPLACE FUNCTION get_total_unread_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_count INTEGER;
BEGIN
    -- Get user ID from auth ID
    SELECT id INTO v_user_id FROM users WHERE auth_id = auth.uid();
    
    SELECT COUNT(*)::INTEGER INTO v_count
    FROM messages m
    JOIN conversations c ON c.id = m.conversation_id
    WHERE v_user_id = ANY(c.participant_ids)
      AND m.sender_id != v_user_id
      AND m.status != 'read';
    
    RETURN COALESCE(v_count, 0);
END;
$$;

-- Enable realtime for messages table
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_or_create_conversation(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION send_message(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_messages_read(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_messages_delivered(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_conversations_with_unread() TO authenticated;
GRANT EXECUTE ON FUNCTION get_total_unread_count() TO authenticated;
