-- Fix ambassador functions to accept auth_id and look up user_id
-- The Swift app passes auth.users.id but tables reference users.id

-- Fix check_ambassador_status
CREATE OR REPLACE FUNCTION check_ambassador_status(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_ambassador ambassadors%ROWTYPE;
    v_active_codes INTEGER;
    v_total_redeemed INTEGER;
    v_codes_this_week INTEGER;
    v_weekly_limit INTEGER := 5;
BEGIN
    -- First, try to find user by auth_id (what Swift passes)
    SELECT id INTO v_user_id FROM users WHERE auth_id = p_user_id;
    
    -- If not found, maybe it's already a users.id
    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM users WHERE id = p_user_id;
    END IF;
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object('is_ambassador', false);
    END IF;

    -- Get ambassador record using the resolved user_id
    SELECT * INTO v_ambassador
    FROM ambassadors
    WHERE user_id = v_user_id AND status = 'active';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'is_ambassador', false
        );
    END IF;
    
    -- Count active codes
    SELECT COUNT(*) INTO v_active_codes
    FROM referral_codes
    WHERE created_by = v_user_id 
    AND status = 'active'
    AND expires_at > NOW();
    
    -- Count total redeemed
    SELECT COUNT(*) INTO v_total_redeemed
    FROM referral_codes
    WHERE created_by = v_user_id AND status = 'redeemed';
    
    -- Count codes created this week (Monday to Sunday)
    SELECT COUNT(*) INTO v_codes_this_week
    FROM referral_codes
    WHERE created_by = v_user_id 
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

-- Fix generate_referral_code
CREATE OR REPLACE FUNCTION generate_referral_code(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_ambassador ambassadors%ROWTYPE;
    v_codes_this_week INTEGER;
    v_weekly_limit INTEGER := 5;
    v_new_code TEXT;
    v_code_id UUID;
BEGIN
    -- First, try to find user by auth_id (what Swift passes)
    SELECT id INTO v_user_id FROM users WHERE auth_id = p_user_id;
    
    -- If not found, maybe it's already a users.id
    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM users WHERE id = p_user_id;
    END IF;
    
    IF v_user_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User not found'
        );
    END IF;

    -- Verify ambassador status
    SELECT * INTO v_ambassador
    FROM ambassadors
    WHERE user_id = v_user_id AND status = 'active';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Not an active ambassador'
        );
    END IF;
    
    -- Check weekly limit
    SELECT COUNT(*) INTO v_codes_this_week
    FROM referral_codes
    WHERE created_by = v_user_id 
    AND created_at >= date_trunc('week', NOW());
    
    IF v_codes_this_week >= v_weekly_limit THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Weekly code limit reached'
        );
    END IF;
    
    -- Generate unique code (8 characters)
    LOOP
        v_new_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || CLOCK_TIMESTAMP()::TEXT) FROM 1 FOR 8));
        -- Make sure code is unique
        EXIT WHEN NOT EXISTS (SELECT 1 FROM referral_codes WHERE code = v_new_code);
    END LOOP;
    
    -- Insert the new code
    INSERT INTO referral_codes (code, created_by, premium_days, expires_at, status)
    VALUES (v_new_code, v_user_id, 7, NOW() + INTERVAL '30 days', 'active')
    RETURNING id INTO v_code_id;
    
    RETURN json_build_object(
        'success', true,
        'code', v_new_code,
        'code_id', v_code_id,
        'expires_at', (NOW() + INTERVAL '30 days')::TEXT
    );
END;
$$;

-- Fix get_ambassador_codes
CREATE OR REPLACE FUNCTION get_ambassador_codes(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- First, try to find user by auth_id (what Swift passes)
    SELECT id INTO v_user_id FROM users WHERE auth_id = p_user_id;
    
    -- If not found, maybe it's already a users.id
    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM users WHERE id = p_user_id;
    END IF;
    
    IF v_user_id IS NULL THEN
        RETURN '[]'::JSON;
    END IF;

    RETURN (
        SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
        FROM (
            SELECT 
                id,
                code,
                premium_days,
                created_at,
                expires_at,
                redeemed_at,
                status,
                (SELECT display_name FROM users WHERE id = redeemed_by) as redeemed_by_name
            FROM referral_codes
            WHERE created_by = v_user_id
            ORDER BY created_at DESC
            LIMIT 50
        ) t
    );
END;
$$;
