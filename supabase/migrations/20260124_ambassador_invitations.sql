-- Ambassador Invitation System & Weekly Code Limits
-- Created: January 24, 2026

-- ============================================
-- 1. AMBASSADOR INVITATIONS TABLE
-- ============================================
-- Track pending ambassador invitations from developers

CREATE TABLE IF NOT EXISTS ambassador_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invited_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invited_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    developer_message TEXT, -- Personal message from the developer
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    UNIQUE(invited_user_id) -- Only one pending invitation per user
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ambassador_invitations_invited_user ON ambassador_invitations(invited_user_id);
CREATE INDEX IF NOT EXISTS idx_ambassador_invitations_status ON ambassador_invitations(status);
CREATE INDEX IF NOT EXISTS idx_ambassador_invitations_invited_by ON ambassador_invitations(invited_by_user_id);

-- ============================================
-- 2. UPDATE AMBASSADORS TABLE FOR INVITATION TRACKING
-- ============================================

ALTER TABLE ambassadors ADD COLUMN IF NOT EXISTS invited_by UUID REFERENCES users(id);

-- ============================================
-- 3. RPC: INVITE USER TO BE AMBASSADOR (Developer only)
-- ============================================

CREATE OR REPLACE FUNCTION invite_ambassador(
    p_username TEXT,
    p_developer_message TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_developer_id UUID;
    v_target_user_id UUID;
    v_target_display_name TEXT;
    v_existing_ambassador BOOLEAN;
    v_existing_invitation BOOLEAN;
BEGIN
    -- Get the calling user's ID and verify they are a developer
    SELECT u.id INTO v_developer_id
    FROM users u
    WHERE u.auth_id = auth.uid() AND u.is_developer = true;
    
    IF v_developer_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Only developers can invite ambassadors'
        );
    END IF;
    
    -- Find target user by username
    SELECT id, display_name INTO v_target_user_id, v_target_display_name
    FROM users
    WHERE LOWER(username) = LOWER(p_username);
    
    IF v_target_user_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;
    
    -- Check if already an ambassador
    SELECT EXISTS(
        SELECT 1 FROM ambassadors 
        WHERE user_id = v_target_user_id AND status = 'active'
    ) INTO v_existing_ambassador;
    
    IF v_existing_ambassador THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User is already an ambassador'
        );
    END IF;
    
    -- Check for existing pending invitation
    SELECT EXISTS(
        SELECT 1 FROM ambassador_invitations 
        WHERE invited_user_id = v_target_user_id AND status = 'pending'
    ) INTO v_existing_invitation;
    
    IF v_existing_invitation THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User already has a pending invitation'
        );
    END IF;
    
    -- Create the invitation
    INSERT INTO ambassador_invitations (invited_user_id, invited_by_user_id, developer_message)
    VALUES (v_target_user_id, v_developer_id, p_developer_message)
    ON CONFLICT (invited_user_id) 
    DO UPDATE SET 
        invited_by_user_id = v_developer_id,
        developer_message = p_developer_message,
        status = 'pending',
        created_at = NOW(),
        responded_at = NULL;
    
    RETURN json_build_object(
        'success', true,
        'user_id', v_target_user_id,
        'display_name', v_target_display_name
    );
END;
$$;

-- ============================================
-- 4. RPC: RESPOND TO AMBASSADOR INVITATION
-- ============================================

CREATE OR REPLACE FUNCTION respond_to_ambassador_invitation(
    p_accept BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_invitation ambassador_invitations%ROWTYPE;
BEGIN
    -- Get calling user's ID
    SELECT id INTO v_user_id
    FROM users
    WHERE auth_id = auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'User not found');
    END IF;
    
    -- Get pending invitation
    SELECT * INTO v_invitation
    FROM ambassador_invitations
    WHERE invited_user_id = v_user_id AND status = 'pending';
    
    IF v_invitation.id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'No pending invitation found');
    END IF;
    
    IF p_accept THEN
        -- Accept: Create ambassador record
        INSERT INTO ambassadors (user_id, status, max_codes, invited_by)
        VALUES (v_user_id, 'active', 5, v_invitation.invited_by_user_id)
        ON CONFLICT (user_id) 
        DO UPDATE SET status = 'active', invited_by = v_invitation.invited_by_user_id, updated_at = NOW();
        
        -- Update user's is_ambassador flag
        UPDATE users SET is_ambassador = true WHERE id = v_user_id;
        
        -- Update invitation status
        UPDATE ambassador_invitations 
        SET status = 'accepted', responded_at = NOW()
        WHERE id = v_invitation.id;
        
        RETURN json_build_object(
            'success', true,
            'status', 'accepted'
        );
    ELSE
        -- Decline: Just update invitation status
        UPDATE ambassador_invitations 
        SET status = 'declined', responded_at = NOW()
        WHERE id = v_invitation.id;
        
        RETURN json_build_object(
            'success', true,
            'status', 'declined'
        );
    END IF;
END;
$$;

-- ============================================
-- 5. RPC: CHECK FOR PENDING INVITATION
-- ============================================

CREATE OR REPLACE FUNCTION check_ambassador_invitation()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_invitation ambassador_invitations%ROWTYPE;
    v_developer_name TEXT;
    v_developer_username TEXT;
BEGIN
    -- Get calling user's ID
    SELECT id INTO v_user_id
    FROM users
    WHERE auth_id = auth.uid();
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object('has_invitation', false);
    END IF;
    
    -- Get pending invitation
    SELECT * INTO v_invitation
    FROM ambassador_invitations
    WHERE invited_user_id = v_user_id AND status = 'pending';
    
    IF v_invitation.id IS NULL THEN
        RETURN json_build_object('has_invitation', false);
    END IF;
    
    -- Get developer info
    SELECT display_name, username INTO v_developer_name, v_developer_username
    FROM users
    WHERE id = v_invitation.invited_by_user_id;
    
    RETURN json_build_object(
        'has_invitation', true,
        'invitation_id', v_invitation.id,
        'developer_name', v_developer_name,
        'developer_username', v_developer_username,
        'developer_message', v_invitation.developer_message,
        'invited_at', v_invitation.created_at
    );
END;
$$;

-- ============================================
-- 6. RPC: REVOKE AMBASSADOR STATUS (Developer only)
-- ============================================

CREATE OR REPLACE FUNCTION revoke_ambassador(p_username TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_developer_id UUID;
    v_target_user_id UUID;
    v_target_display_name TEXT;
BEGIN
    -- Verify caller is a developer
    SELECT id INTO v_developer_id
    FROM users
    WHERE auth_id = auth.uid() AND is_developer = true;
    
    IF v_developer_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Only developers can revoke ambassador status'
        );
    END IF;
    
    -- Find target user
    SELECT id, display_name INTO v_target_user_id, v_target_display_name
    FROM users
    WHERE LOWER(username) = LOWER(p_username);
    
    IF v_target_user_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;
    
    -- Revoke ambassador status
    UPDATE ambassadors 
    SET status = 'revoked', updated_at = NOW()
    WHERE user_id = v_target_user_id AND status = 'active';
    
    -- Update user flag
    UPDATE users SET is_ambassador = false WHERE id = v_target_user_id;
    
    -- Delete any pending invitations
    DELETE FROM ambassador_invitations WHERE invited_user_id = v_target_user_id;
    
    RETURN json_build_object(
        'success', true,
        'display_name', v_target_display_name
    );
END;
$$;

-- ============================================
-- 7. RPC: LIST AMBASSADORS (Developer only)
-- ============================================

CREATE OR REPLACE FUNCTION list_ambassadors()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_developer_id UUID;
BEGIN
    -- Verify caller is a developer
    SELECT id INTO v_developer_id
    FROM users
    WHERE auth_id = auth.uid() AND is_developer = true;
    
    IF v_developer_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Only developers can list ambassadors'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'ambassadors', (
            SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
            FROM (
                SELECT 
                    u.id,
                    u.username,
                    u.display_name,
                    a.status,
                    a.created_at,
                    inviter.display_name as invited_by_name,
                    (SELECT COUNT(*) FROM referral_codes rc WHERE rc.created_by = u.id AND rc.status = 'redeemed') as codes_redeemed
                FROM ambassadors a
                JOIN users u ON a.user_id = u.id
                LEFT JOIN users inviter ON a.invited_by = inviter.id
                WHERE a.status = 'active'
                ORDER BY a.created_at DESC
            ) t
        ),
        'pending_invitations', (
            SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
            FROM (
                SELECT 
                    u.id,
                    u.username,
                    u.display_name,
                    ai.created_at as invited_at,
                    inviter.display_name as invited_by_name
                FROM ambassador_invitations ai
                JOIN users u ON ai.invited_user_id = u.id
                LEFT JOIN users inviter ON ai.invited_by_user_id = inviter.id
                WHERE ai.status = 'pending'
                ORDER BY ai.created_at DESC
            ) t
        )
    );
END;
$$;

-- ============================================
-- 8. UPDATE CODE GENERATION FOR WEEKLY LIMIT
-- ============================================

-- First update check_ambassador_status to return weekly codes info
CREATE OR REPLACE FUNCTION check_ambassador_status(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ambassador ambassadors%ROWTYPE;
    v_active_codes INTEGER;
    v_total_redeemed INTEGER;
    v_codes_this_week INTEGER;
    v_weekly_limit INTEGER := 5;
BEGIN
    -- Get ambassador record
    SELECT * INTO v_ambassador
    FROM ambassadors
    WHERE user_id = p_user_id AND status = 'active';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'is_ambassador', false
        );
    END IF;
    
    -- Count active codes
    SELECT COUNT(*) INTO v_active_codes
    FROM referral_codes
    WHERE created_by = p_user_id 
    AND status = 'active'
    AND expires_at > NOW();
    
    -- Count total redeemed
    SELECT COUNT(*) INTO v_total_redeemed
    FROM referral_codes
    WHERE created_by = p_user_id AND status = 'redeemed';
    
    -- Count codes created this week (Monday to Sunday)
    SELECT COUNT(*) INTO v_codes_this_week
    FROM referral_codes
    WHERE created_by = p_user_id 
    AND created_at >= date_trunc('week', NOW());
    
    RETURN json_build_object(
        'is_ambassador', true,
        'max_codes', v_weekly_limit,
        'active_codes', v_active_codes,
        'total_redeemed', v_total_redeemed,
        'codes_this_week', v_codes_this_week,
        'can_generate_code', v_codes_this_week < v_weekly_limit
    );
END;
$$;

-- Update generate_referral_code to enforce weekly limit
CREATE OR REPLACE FUNCTION generate_referral_code(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ambassador ambassadors%ROWTYPE;
    v_codes_this_week INTEGER;
    v_weekly_limit INTEGER := 5;
    v_new_code TEXT;
    v_code_id UUID;
BEGIN
    -- Verify ambassador status
    SELECT * INTO v_ambassador
    FROM ambassadors
    WHERE user_id = p_user_id AND status = 'active';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Not an active ambassador'
        );
    END IF;
    
    -- Check weekly limit
    SELECT COUNT(*) INTO v_codes_this_week
    FROM referral_codes
    WHERE created_by = p_user_id 
    AND created_at >= date_trunc('week', NOW());
    
    IF v_codes_this_week >= v_weekly_limit THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Weekly code limit reached (5 per week)'
        );
    END IF;
    
    -- Generate unique code
    v_new_code := 'TEN-' || UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 8));
    
    -- Make sure code is unique
    WHILE EXISTS(SELECT 1 FROM referral_codes WHERE code = v_new_code) LOOP
        v_new_code := 'TEN-' || UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 8));
    END LOOP;
    
    -- Insert the code (expires in 7 days)
    INSERT INTO referral_codes (code, created_by, expires_at, premium_days)
    VALUES (v_new_code, p_user_id, NOW() + INTERVAL '7 days', 7)
    RETURNING id INTO v_code_id;
    
    RETURN json_build_object(
        'success', true,
        'code', v_new_code,
        'code_id', v_code_id,
        'expires_at', NOW() + INTERVAL '7 days',
        'codes_remaining', v_weekly_limit - v_codes_this_week - 1
    );
END;
$$;

-- ============================================
-- 9. GRANT PERMISSIONS
-- ============================================

GRANT EXECUTE ON FUNCTION invite_ambassador(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION respond_to_ambassador_invitation(BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION check_ambassador_invitation() TO authenticated;
GRANT EXECUTE ON FUNCTION revoke_ambassador(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION list_ambassadors() TO authenticated;

-- Enable RLS on ambassador_invitations
ALTER TABLE ambassador_invitations ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own invitations
CREATE POLICY "Users can read own invitations"
ON ambassador_invitations FOR SELECT
TO authenticated
USING (invited_user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Policy: Developers can read all invitations
CREATE POLICY "Developers can read all invitations"
ON ambassador_invitations FOR SELECT
TO authenticated
USING (EXISTS (SELECT 1 FROM users WHERE auth_id = auth.uid() AND is_developer = true));
