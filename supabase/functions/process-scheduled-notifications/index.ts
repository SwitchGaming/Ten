import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// This function is called by pg_cron or can be invoked manually
// It processes the notification queue and calls send-push-notification for each

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

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  
  try {
    const { action } = await req.json()
    
    let result: any = { success: true }
    
    switch (action) {
      case 'daily_reminders':
        result = await sendDailyReminders(supabase)
        break
      case 'weekly_connections':
        result = await generateWeeklyConnections(supabase)
        break
      case 'process_queue':
        result = await processNotificationQueue(supabase)
        break
      default:
        // Process all by default
        const reminders = await sendDailyReminders(supabase)
        const queue = await processNotificationQueue(supabase)
        result = { reminders, queue }
    }
    
    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (error: any) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})

// Send daily reminders to users who haven't rated today
async function sendDailyReminders(supabase: any) {
  console.log('📅 Processing daily reminders...')
  
  // Find users who should receive a reminder now
  const { data: users, error } = await supabase.rpc('get_users_for_daily_reminder')
  
  if (error) {
    console.error('Error getting users for reminder:', error)
    return { success: false, error: error.message }
  }
  
  let sentCount = 0
  
  for (const user of users || []) {
    try {
      // Call the main push notification function
      const response = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
        },
        body: JSON.stringify({
          type: 'daily_reminder',
          userId: user.id,
          senderName: null,
          data: {}
        })
      })
      
      if (response.ok) {
        sentCount++
        console.log(`✅ Sent daily reminder to ${user.display_name}`)
      }
    } catch (err) {
      console.error(`Error sending reminder to ${user.id}:`, err)
    }
  }
  
  return { success: true, reminders_sent: sentCount }
}

// Generate weekly connection matches and notify users
async function generateWeeklyConnections(supabase: any) {
  console.log('🌟 Generating weekly connections...')
  
  // Call the SQL function
  const { data, error } = await supabase.rpc('generate_weekly_connections')
  
  if (error) {
    console.error('Error generating connections:', error)
    return { success: false, error: error.message }
  }
  
  // Now process the queued connection_match notifications
  await processNotificationQueue(supabase, 'connection_match')
  
  return data
}

// Process queued notifications
async function processNotificationQueue(supabase: any, filterType?: string) {
  console.log(`📬 Processing notification queue${filterType ? ` for type: ${filterType}` : ''}...`)
  
  let query = supabase
    .from('notification_queue')
    .select('*, users!user_id(display_name)')
    .eq('processed', false)
    .lte('deliver_after', new Date().toISOString())
    .order('deliver_after', { ascending: true })
    .limit(100)
  
  if (filterType) {
    query = query.eq('type', filterType)
  }
  
  const { data: queued, error } = await query
  
  if (error) {
    console.error('Error fetching queue:', error)
    return { success: false, error: error.message }
  }
  
  let processedCount = 0
  
  for (const notification of queued || []) {
    try {
      // Call the main push notification function
      const response = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
        },
        body: JSON.stringify({
          type: notification.type,
          userId: notification.user_id,
          senderName: notification.data?.senderName || null,
          data: notification.data
        })
      })
      
      // Mark as processed regardless of result
      await supabase
        .from('notification_queue')
        .update({ processed: true, processed_at: new Date().toISOString() })
        .eq('id', notification.id)
      
      if (response.ok) {
        processedCount++
      }
    } catch (err) {
      console.error(`Error processing notification ${notification.id}:`, err)
    }
  }
  
  return { success: true, processed: processedCount }
}
