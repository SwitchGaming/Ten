-- Message Reactions

-- Create reactions table
CREATE TABLE IF NOT EXISTS message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL CHECK (length(emoji) <= 10),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- One reaction per user per message
    CONSTRAINT unique_user_message_reaction UNIQUE (message_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_reactions_message ON message_reactions (message_id);
CREATE INDEX IF NOT EXISTS idx_reactions_user ON message_reactions (user_id);

-- RLS Policies
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;

-- Users can view reactions on messages in their conversations
CREATE POLICY "Users can view reactions in own conversations" ON message_reactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM messages m
            JOIN conversations c ON c.id = m.conversation_id
            WHERE m.id = message_reactions.message_id
            AND get_current_user_id() = ANY(c.participant_ids)
        )
    );

-- Users can add reactions to messages in their conversations
CREATE POLICY "Users can add reactions in own conversations" ON message_reactions
    FOR INSERT WITH CHECK (
        user_id = get_current_user_id() AND
        EXISTS (
            SELECT 1 FROM messages m
            JOIN conversations c ON c.id = m.conversation_id
            WHERE m.id = message_id
            AND get_current_user_id() = ANY(c.participant_ids)
        )
    );

-- Users can remove their own reactions
CREATE POLICY "Users can remove own reactions" ON message_reactions
    FOR DELETE USING (user_id = get_current_user_id());

-- Enable realtime for reactions
ALTER PUBLICATION supabase_realtime ADD TABLE message_reactions;

-- Enable full replica identity so we can get old record on delete
ALTER TABLE message_reactions REPLICA IDENTITY FULL;

-- Function to toggle reaction (add if not exists, remove if exists)
CREATE OR REPLACE FUNCTION toggle_reaction(
    p_message_id UUID,
    p_emoji TEXT
)
RETURNS TABLE (
    action TEXT,
    reaction_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_existing_id UUID;
    v_new_id UUID;
BEGIN
    -- Get user ID from auth
    SELECT id INTO v_user_id FROM users WHERE auth_id = auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Check if reaction exists
    SELECT id INTO v_existing_id
    FROM message_reactions
    WHERE message_id = p_message_id AND user_id = v_user_id;
    
    IF v_existing_id IS NOT NULL THEN
        -- Check if same emoji - if so, remove it
        IF EXISTS (
            SELECT 1 FROM message_reactions 
            WHERE id = v_existing_id AND emoji = p_emoji
        ) THEN
            DELETE FROM message_reactions WHERE id = v_existing_id;
            RETURN QUERY SELECT 'removed'::TEXT, v_existing_id;
        ELSE
            -- Different emoji - update it
            UPDATE message_reactions 
            SET emoji = p_emoji, created_at = NOW()
            WHERE id = v_existing_id;
            RETURN QUERY SELECT 'updated'::TEXT, v_existing_id;
        END IF;
    ELSE
        -- Add new reaction
        INSERT INTO message_reactions (message_id, user_id, emoji)
        VALUES (p_message_id, v_user_id, p_emoji)
        RETURNING id INTO v_new_id;
        RETURN QUERY SELECT 'added'::TEXT, v_new_id;
    END IF;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION toggle_reaction(UUID, TEXT) TO authenticated;
