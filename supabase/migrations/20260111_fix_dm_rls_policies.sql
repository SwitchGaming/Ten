-- Fix RLS policies to use users.id lookup from auth.uid()
-- The participant_ids array stores users.id (database UUID), not auth.uid() (Supabase Auth ID)

-- Helper function to get current user's database ID from auth ID
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT id FROM users WHERE auth_id = auth.uid();
$$;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own conversations" ON conversations;
DROP POLICY IF EXISTS "Users can insert conversations they're part of" ON conversations;
DROP POLICY IF EXISTS "Users can update own conversations" ON conversations;
DROP POLICY IF EXISTS "Users can view messages in own conversations" ON messages;
DROP POLICY IF EXISTS "Users can insert messages in own conversations" ON messages;
DROP POLICY IF EXISTS "Users can update message status in own conversations" ON messages;

-- Recreate policies using the helper function

-- Conversations policies
CREATE POLICY "Users can view own conversations" ON conversations
    FOR SELECT USING (get_current_user_id() = ANY(participant_ids));

CREATE POLICY "Users can insert conversations they're part of" ON conversations
    FOR INSERT WITH CHECK (get_current_user_id() = ANY(participant_ids));

CREATE POLICY "Users can update own conversations" ON conversations
    FOR UPDATE USING (get_current_user_id() = ANY(participant_ids));

-- Messages policies
CREATE POLICY "Users can view messages in own conversations" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = messages.conversation_id 
            AND get_current_user_id() = ANY(c.participant_ids)
        )
    );

CREATE POLICY "Users can insert messages in own conversations" ON messages
    FOR INSERT WITH CHECK (
        sender_id = get_current_user_id() AND
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = conversation_id 
            AND get_current_user_id() = ANY(c.participant_ids)
        )
    );

CREATE POLICY "Users can update message status in own conversations" ON messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = messages.conversation_id 
            AND get_current_user_id() = ANY(c.participant_ids)
        )
    );
