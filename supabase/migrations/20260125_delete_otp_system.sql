-- Delete Account OTP verification system
-- Creates a custom OTP table and functions for account deletion verification

-- Table to store delete account OTP codes
CREATE TABLE IF NOT EXISTS delete_account_otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    used BOOLEAN DEFAULT FALSE,
    UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE delete_account_otps ENABLE ROW LEVEL SECURITY;

-- Users can only see their own OTP records
CREATE POLICY "Users can view own OTP" ON delete_account_otps
    FOR SELECT USING (user_id = auth.uid() OR user_id IN (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Function to generate and store a delete OTP
CREATE OR REPLACE FUNCTION generate_delete_otp(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_code TEXT;
    v_code_hash TEXT;
    v_user_email TEXT;
BEGIN
    -- Generate a 6-digit code
    v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    
    -- Hash the code for storage
    v_code_hash := crypt(v_code, gen_salt('bf'));
    
    -- Delete any existing OTP for this user
    DELETE FROM delete_account_otps WHERE user_id = p_user_id;
    
    -- Insert the new OTP with 10 minute expiry
    INSERT INTO delete_account_otps (user_id, code_hash, expires_at)
    VALUES (p_user_id, v_code_hash, NOW() + INTERVAL '10 minutes');
    
    -- Return the plain code (will be sent via edge function)
    RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify a delete OTP
CREATE OR REPLACE FUNCTION verify_delete_otp(p_user_id UUID, p_code TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_otp_record delete_account_otps%ROWTYPE;
BEGIN
    -- Get the OTP record
    SELECT * INTO v_otp_record
    FROM delete_account_otps
    WHERE user_id = p_user_id
    AND used = FALSE
    AND expires_at > NOW();
    
    -- Check if record exists
    IF v_otp_record IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Verify the code
    IF v_otp_record.code_hash = crypt(p_code, v_otp_record.code_hash) THEN
        -- Mark as used
        UPDATE delete_account_otps SET used = TRUE WHERE id = v_otp_record.id;
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION generate_delete_otp(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_delete_otp(UUID, TEXT) TO authenticated;

-- Enable pgcrypto if not already enabled (for crypt function)
CREATE EXTENSION IF NOT EXISTS pgcrypto;
