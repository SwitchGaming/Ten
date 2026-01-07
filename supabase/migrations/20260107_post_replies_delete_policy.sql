-- Migration: Add delete policy for post_replies
-- Allows users to delete their own replies

-- Enable RLS on post_replies if not already enabled
ALTER TABLE post_replies ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to delete their own replies
DROP POLICY IF EXISTS "Users can delete own replies" ON post_replies;
CREATE POLICY "Users can delete own replies"
ON post_replies FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Add comment for documentation
COMMENT ON POLICY "Users can delete own replies" ON post_replies IS 'Allows authenticated users to delete their own replies';
