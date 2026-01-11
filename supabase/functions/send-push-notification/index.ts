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

// Rate limiting constants
const MAX_NOTIFICATIONS_PER_DAY = 20
const MIN_SAME_TYPE_INTERVAL_MINUTES = 5
const COLLAPSE_THRESHOLD = 3 // Collapse if 3+ similar notifications pending

// Notification copy templates - enticing and curiosity-driven
const NOTIFICATION_COPY: Record<string, { title: (name?: string, count?: number) => string, body: (name?: string) => string }> = {
  vibe: {
    title: (name) => `${name} started a vibe ✨`,
    body: () => "see what's happening"
  },
  vibe_collapsed: {
    title: (_, count) => `${count} friends started vibes`,
    body: () => "see what everyone's up to"
  },
  vibe_response: {
    title: () => "someone's in! 🎉",
    body: (name) => `${name} responded to your vibe`
  },
  vibe_response_collapsed: {
    title: (_, count) => `${count} people responded`,
    body: () => "your vibe is taking off"
  },
  friend_request: {
    title: () => "new connection request 👋",
    body: (name) => `${name} wants to be friends`
  },
  reply: {
    title: (name) => `${name} replied 💬`,
    body: () => "tap to see what they said"
  },
  reply_collapsed: {
    title: (_, count) => `${count} new replies`,
    body: () => "people are talking on your post"
  },
  connection_match: {
    title: () => "your match is here! 🌟",
    body: () => "meet this week's connection"
  },
  daily_reminder: {
    title: () => "how's your day going?",
    body: () => "take a moment to check in"
  },
  check_in_alert: {
    title: (name) => `${name} might need some support 💙`,
    body: () => "a gentle nudge to reach out"
  },
  check_in_response: {
    title: (name) => `${name} is thinking of you 💙`,
    body: () => "you've got someone in your corner"
  }
}

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
    const { type, userId, senderName, data } = await req.json()
    
    console.log(`📬 Processing ${type} notification for user ${userId}`)
    
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
    
    // Check user's notification preferences
    const { data: prefs } = await supabase
      .from('notification_preferences')
      .select('*')
      .eq('user_id', userId)
      .single()
    
    // Check if this notification type is enabled
    if (prefs) {
      const typeEnabled = checkNotificationTypeEnabled(type, prefs)
      if (!typeEnabled) {
        console.log(`${type} notifications disabled for user`)
        return new Response(JSON.stringify({ skipped: 'disabled' }), {
          headers: { 'Content-Type': 'application/json' }
        })
      }
      
      // Check rate limiting
      const rateLimitCheck = await checkRateLimits(supabase, userId, type)
      if (!rateLimitCheck.allowed) {
        console.log(`Rate limited: ${rateLimitCheck.reason}`)
        return new Response(JSON.stringify({ skipped: 'rate_limited', reason: rateLimitCheck.reason }), {
          headers: { 'Content-Type': 'application/json' }
        })
      }
      
      // Check quiet hours (only if enabled)
      if (prefs.quiet_hours_enabled !== false) {
        const quietHoursCheck = checkQuietHours(prefs)
        if (quietHoursCheck.inQuietHours) {
          // Queue the notification instead of dropping it
          console.log('User is in quiet hours - queuing notification')
          await queueNotification(supabase, userId, type, senderName, data, quietHoursCheck.deliverAfter!)
          return new Response(JSON.stringify({ queued: true, deliver_after: quietHoursCheck.deliverAfter }), {
            headers: { 'Content-Type': 'application/json' }
          })
        }
      }
    }
    
    // Check for collapsible notifications
    const collapseCheck = await checkForCollapse(supabase, userId, type)
    
    // Generate notification content
    const { title, body } = generateNotificationContent(type, senderName, collapseCheck.count)
    
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
      status: results.every(r => r.ok) ? 'sent' : 'partial_failure',
      created_at: new Date().toISOString()
    })
    
    // If we collapsed notifications, mark queued ones as processed
    if (collapseCheck.count > 1) {
      await supabase
        .from('notification_queue')
        .update({ processed: true, processed_at: new Date().toISOString() })
        .eq('user_id', userId)
        .eq('type', type)
        .eq('processed', false)
    }
    
    return new Response(JSON.stringify({ success: true, results, collapsed: collapseCheck.count }), { 
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

// Check if notification type is enabled in preferences
function checkNotificationTypeEnabled(type: string, prefs: any): boolean {
  switch (type) {
    case 'vibe':
      return prefs.vibes_enabled !== false
    case 'vibe_response':
      return prefs.vibe_responses_enabled !== false
    case 'friend_request':
      return prefs.friend_requests_enabled !== false
    case 'reply':
      return prefs.replies_enabled !== false
    case 'connection_match':
      return prefs.connection_match_enabled !== false
    case 'daily_reminder':
      return prefs.daily_reminder_enabled === true
    case 'check_in_alert':
      return prefs.check_in_alerts_enabled !== false
    case 'check_in_response':
      return true  // Always deliver support messages
    default:
      return true
  }
}

// Check rate limits
async function checkRateLimits(supabase: any, userId: string, type: string): Promise<{ allowed: boolean, reason?: string }> {
  const now = new Date()
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const fiveMinutesAgo = new Date(now.getTime() - MIN_SAME_TYPE_INTERVAL_MINUTES * 60 * 1000)
  
  // Check daily limit
  const { count: dailyCount } = await supabase
    .from('notification_logs')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('created_at', startOfDay.toISOString())
  
  if (dailyCount >= MAX_NOTIFICATIONS_PER_DAY) {
    return { allowed: false, reason: 'daily_limit_exceeded' }
  }
  
  // Check same-type cooldown
  const { data: recentSameType } = await supabase
    .from('notification_logs')
    .select('created_at')
    .eq('user_id', userId)
    .eq('notification_type', type)
    .gte('created_at', fiveMinutesAgo.toISOString())
    .limit(1)
  
  if (recentSameType && recentSameType.length > 0) {
    return { allowed: false, reason: 'same_type_cooldown' }
  }
  
  return { allowed: true }
}

// Check quiet hours and return when to deliver
function checkQuietHours(prefs: any): { inQuietHours: boolean, deliverAfter?: string } {
  const userTimezone = prefs.timezone || 'America/New_York'
  const start = prefs.quiet_hours_start || '22:00'
  const end = prefs.quiet_hours_end || '08:00'
  
  // Get current time in user's timezone
  const now = new Date()
  const userTime = new Date(now.toLocaleString('en-US', { timeZone: userTimezone }))
  const currentHour = userTime.getHours()
  const currentMinute = userTime.getMinutes()
  const currentTime = `${currentHour.toString().padStart(2, '0')}:${currentMinute.toString().padStart(2, '0')}`
  
  const inQuietHours = isInQuietHours(currentTime, start, end)
  
  if (inQuietHours) {
    // Calculate when quiet hours end
    const [endHour, endMinute] = end.split(':').map(Number)
    const deliverDate = new Date(userTime)
    deliverDate.setHours(endHour, endMinute, 0, 0)
    
    // If end time is earlier than current time, it's tomorrow
    if (deliverDate <= userTime) {
      deliverDate.setDate(deliverDate.getDate() + 1)
    }
    
    return { inQuietHours: true, deliverAfter: deliverDate.toISOString() }
  }
  
  return { inQuietHours: false }
}

function isInQuietHours(current: string, start: string, end: string): boolean {
  if (!start || !end) return false
  
  if (start <= end) {
    return current >= start && current < end
  } else {
    // Quiet hours span midnight (e.g., 22:00 to 08:00)
    return current >= start || current < end
  }
}

// Queue notification for later delivery
async function queueNotification(supabase: any, userId: string, type: string, senderName: string, data: any, deliverAfter: string) {
  const { title, body } = generateNotificationContent(type, senderName, 1)
  
  await supabase.from('notification_queue').insert({
    user_id: userId,
    type,
    title,
    body,
    data: { senderName, ...data },
    deliver_after: deliverAfter,
    processed: false
  })
}

// Check for notifications to collapse
async function checkForCollapse(supabase: any, userId: string, type: string): Promise<{ count: number }> {
  // Only collapse certain types
  const collapsibleTypes = ['vibe', 'vibe_response', 'reply']
  if (!collapsibleTypes.includes(type)) {
    return { count: 1 }
  }
  
  // Check pending queue for same type
  const { count } = await supabase
    .from('notification_queue')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('type', type)
    .eq('processed', false)
  
  const totalCount = (count || 0) + 1
  
  if (totalCount >= COLLAPSE_THRESHOLD) {
    return { count: totalCount }
  }
  
  return { count: 1 }
}

// Generate notification content based on type
function generateNotificationContent(type: string, senderName?: string, count: number = 1): { title: string, body: string } {
  // Check if we should use collapsed version
  const useCollapsed = count >= COLLAPSE_THRESHOLD
  const copyType = useCollapsed && NOTIFICATION_COPY[`${type}_collapsed`] ? `${type}_collapsed` : type
  
  const template = NOTIFICATION_COPY[copyType] || NOTIFICATION_COPY[type] || {
    title: () => 'ten',
    body: () => 'you have a new notification'
  }
  
  return {
    title: template.title(senderName, count),
    body: template.body(senderName)
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