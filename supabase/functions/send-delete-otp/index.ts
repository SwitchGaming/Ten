import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get the user from the authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    // Get the OTP code from request body
    const body = await req.json().catch(() => ({}))
    const otpCode = body.code
    
    if (!otpCode) {
      throw new Error('No OTP code provided')
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser(token)
    
    if (userError || !user) {
      throw new Error('Invalid user token')
    }

    // Get user profile to get user_id
    const { data: userProfile, error: profileError } = await supabaseClient
      .from('users')
      .select('id, email, display_name')
      .eq('auth_id', user.id)
      .single()

    if (profileError || !userProfile) {
      throw new Error('User profile not found')
    }

    // Send email using Supabase's built-in email (via auth.admin)
    // We'll use a custom email template approach
    const emailHtml = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #0a0a0a; color: #ffffff; padding: 40px; }
          .container { max-width: 480px; margin: 0 auto; background-color: #141414; border-radius: 16px; padding: 40px; }
          .header { text-align: center; margin-bottom: 32px; }
          .logo { font-size: 24px; font-weight: 300; letter-spacing: 4px; color: #ffffff; }
          .warning-icon { font-size: 48px; margin-bottom: 16px; }
          .title { font-size: 20px; font-weight: 300; margin-bottom: 8px; color: #ef4444; }
          .subtitle { font-size: 14px; color: #888888; margin-bottom: 32px; }
          .code-box { background-color: #1a1a1a; border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 24px; border: 1px solid #333333; }
          .code { font-size: 36px; font-weight: 600; letter-spacing: 8px; color: #ffffff; }
          .expires { font-size: 12px; color: #666666; margin-top: 16px; }
          .warning { background-color: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.3); border-radius: 8px; padding: 16px; margin-bottom: 24px; }
          .warning-text { font-size: 13px; color: #ef4444; margin: 0; }
          .footer { text-align: center; font-size: 12px; color: #666666; margin-top: 32px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="logo">ten</div>
          </div>
          
          <div style="text-align: center;">
            <div class="warning-icon">⚠️</div>
            <div class="title">Account Deletion Request</div>
            <div class="subtitle">Hi ${userProfile.display_name || 'there'}, you requested to delete your account.</div>
          </div>
          
          <div class="code-box">
            <div class="code">${otpCode}</div>
            <div class="expires">This code expires in 10 minutes</div>
          </div>
          
          <div class="warning">
            <p class="warning-text">⚠️ This action is permanent and cannot be undone. All your data will be permanently deleted.</p>
          </div>
          
          <div class="footer">
            <p>If you didn't request this, please ignore this email or contact support.</p>
            <p style="margin-top: 16px;">© 2026 Ten App</p>
          </div>
        </div>
      </body>
      </html>
    `

    // Use Resend or similar service to send email
    // For now, we'll use Supabase's SMTP if configured
    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
    
    if (RESEND_API_KEY) {
      // Send via Resend
      const emailResponse = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: 'Ten App <onboarding@resend.dev>',
          to: [userProfile.email || user.email],
          subject: 'Confirm Account Deletion - Ten App',
          html: emailHtml,
        }),
      })

      if (!emailResponse.ok) {
        const errorText = await emailResponse.text()
        console.error('Resend error:', errorText)
        throw new Error('Failed to send verification email')
      }
    } else {
      // Fallback: Store the code and let client show it (for development)
      console.log('No RESEND_API_KEY configured, OTP code:', otpCode)
      // In production, you should configure an email service
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Verification code sent to your email',
        // Remove this in production - only for testing
        ...(Deno.env.get('ENVIRONMENT') === 'development' && { code: otpCode })
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error) {
    console.error('Error:', error.message)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400 
      }
    )
  }
})
