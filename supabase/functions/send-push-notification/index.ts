import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')!
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')!
const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')!
const BUNDLE_ID = Deno.env.get('BUNDLE_ID') || 'com.joealapat.SocialTen'

// Use sandbox for development, production for TestFlight/App Store
const APNS_HOST = Deno.env.get('APNS_ENVIRONMENT') === 'production' 
  ? 'api.push.apple.com' 
  : 'api.sandbox.push.apple.com'

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    const { type, userId, title, body, data } = await req.json()
    
    console.log(`📬 Sending ${type} notification to user ${userId}`)
    
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    
    // Get user's device tokens
    const { data: tokens, error: tokensError } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', userId)
    
    if (tokensError) {
      console.error('Error fetching tokens:', tokensError)
      return new Response(JSON.stringify({ error: 'Failed to fetch tokens' }), { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    if (!tokens || tokens.length === 0) {
      console.log('No device tokens found for user')
      return new Response(JSON.stringify({ error: 'No device tokens found' }), { 
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log(`Found ${tokens.length} device token(s)`)
    
    // Check user's notification preferences
    const { data: prefs } = await supabase
      .from('notification_preferences')
      .select('*')
      .eq('user_id', userId)
      .single()
    
    // Check if this notification type is enabled
    if (prefs) {
      if (type === 'vibe' && !prefs.vibes_enabled) {
        console.log('Vibes notifications disabled for user')
        return new Response(JSON.stringify({ skipped: 'disabled' }), {
          headers: { 'Content-Type': 'application/json' }
        })
      }
      if (type === 'friend_request' && !prefs.friend_requests_enabled) {
        console.log('Friend request notifications disabled for user')
        return new Response(JSON.stringify({ skipped: 'disabled' }), {
          headers: { 'Content-Type': 'application/json' }
        })
      }
      if (type === 'reply' && !prefs.replies_enabled) {
        console.log('Reply notifications disabled for user')
        return new Response(JSON.stringify({ skipped: 'disabled' }), {
          headers: { 'Content-Type': 'application/json' }
        })
      }
      
      // Check quiet hours
      const now = new Date()
      const currentHour = now.getHours()
      const currentMinute = now.getMinutes()
      const currentTime = `${currentHour.toString().padStart(2, '0')}:${currentMinute.toString().padStart(2, '0')}`
      
      if (isInQuietHours(currentTime, prefs.quiet_hours_start, prefs.quiet_hours_end)) {
        console.log('User is in quiet hours')
        return new Response(JSON.stringify({ skipped: 'quiet_hours' }), {
          headers: { 'Content-Type': 'application/json' }
        })
      }
    }
    
    // Generate JWT for APNs
    console.log('Generating APNs JWT...')
    const jwt = await generateAPNsJWT()
    
    // Send to all device tokens
    console.log('Sending to APNs...')
    const results = await Promise.all(
      tokens.map(({ token }) => sendAPNsNotification(token, title, body, data, type, jwt))
    )
    
    console.log('APNs results:', results)
    
    // Log notification
    await supabase.from('notification_logs').insert({
      user_id: userId,
      notification_type: type,
      title,
      body,
      status: results.every(r => r.ok) ? 'sent' : 'partial_failure'
    })
    
    return new Response(JSON.stringify({ success: true, results }), { 
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ error: error.message }), { 
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

function isInQuietHours(current: string, start: string, end: string): boolean {
  if (!start || !end) return false
  
  if (start <= end) {
    // Normal range (e.g., 22:00 to 08:00 doesn't apply here)
    return current >= start && current < end
  } else {
    // Quiet hours span midnight (e.g., 22:00 to 08:00)
    return current >= start || current < end
  }
}

async function generateAPNsJWT(): Promise<string> {
  // Clean up the private key - handle both formats
  let privateKeyPem = APNS_PRIVATE_KEY
    .replace(/\\n/g, '\n')
    .trim()
  
  // If the key doesn't have headers, add them
  if (!privateKeyPem.includes('-----BEGIN PRIVATE KEY-----')) {
    privateKeyPem = `-----BEGIN PRIVATE KEY-----\n${privateKeyPem}\n-----END PRIVATE KEY-----`
  }
  
  // Import the private key
  const privateKey = await jose.importPKCS8(privateKeyPem, 'ES256')
  
  // Create JWT
  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({ 
      alg: 'ES256', 
      kid: APNS_KEY_ID 
    })
    .setIssuer(APNS_TEAM_ID)
    .setIssuedAt()
    .sign(privateKey)
  
  return jwt
}

async function sendAPNsNotification(
  deviceToken: string, 
  title: string, 
  body: string, 
  data: any,
  type: string,
  jwt: string
) {
  const payload = {
    aps: {
      alert: { 
        title, 
        body 
      },
      sound: 'default',
      badge: 1,
      'mutable-content': 1
    },
    type,
    ...data
  }
  
  const url = `https://${APNS_HOST}/3/device/${deviceToken}`
  
  console.log(`Sending to ${APNS_HOST}...`)
  
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${jwt}`,
        'apns-topic': BUNDLE_ID,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-expiration': '0'
      },
      body: JSON.stringify(payload)
    })
    
    const responseText = await response.text()
    console.log(`APNs response: ${response.status} - ${responseText}`)
    
    return { 
      status: response.status, 
      ok: response.ok,
      response: responseText
    }
  } catch (error) {
    console.error('APNs request failed:', error)
    return { 
      status: 500, 
      ok: false, 
      error: error.message 
    }
  }
}