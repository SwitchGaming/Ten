-- Add is_ambassador column to users table for easy profile display
-- This denormalizes the ambassador status for faster profile lookups

-- Add the column
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_ambassador BOOLEAN DEFAULT FALSE;

-- Create index for queries
CREATE INDEX IF NOT EXISTS idx_users_is_ambassador ON users(is_ambassador) WHERE is_ambassador = true;

-- Sync existing ambassadors
UPDATE users u
SET is_ambassador = true
WHERE EXISTS (
    SELECT 1 FROM ambassadors a 
    WHERE a.user_id = u.id 
    AND a.status = 'active'
);

-- Create trigger to keep is_ambassador in sync with ambassadors table
CREATE OR REPLACE FUNCTION sync_user_ambassador_status()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status = 'active' THEN
            UPDATE users SET is_ambassador = true WHERE id = NEW.user_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.status = 'active' AND (OLD.status IS NULL OR OLD.status != 'active') THEN
            UPDATE users SET is_ambassador = true WHERE id = NEW.user_id;
        ELSIF NEW.status != 'active' AND OLD.status = 'active' THEN
            UPDATE users SET is_ambassador = false WHERE id = NEW.user_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE users SET is_ambassador = false WHERE id = OLD.user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trg_sync_ambassador_status ON ambassadors;

-- Create the trigger
CREATE TRIGGER trg_sync_ambassador_status
AFTER INSERT OR UPDATE OR DELETE ON ambassadors
FOR EACH ROW EXECUTE FUNCTION sync_user_ambassador_status();

-- Grant select on is_ambassador to authenticated users
-- (already part of users table, no additional grants needed)
