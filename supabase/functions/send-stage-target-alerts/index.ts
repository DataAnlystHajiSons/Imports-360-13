import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Resend } from 'https://esm.sh/resend@3.2.0'

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Stage display names mapping
const STAGE_NAMES: Record<string, string> = {
  'forecast': 'Forecast',
  'enlistment_verification': 'Enlistment Verification',
  'availability_confirmation': 'Availability Confirmation',
  'purchase_order': 'Purchase Order',
  'proforma': 'Proforma Invoice',
  'invoice': 'Commercial Invoice',
  'ip_number': 'IP Number',
  'lc_opening': 'LC Management',
  'shipment_details_from_supplier': 'Supplier Shipment Details',
  'freight_query': 'Freight Query',
  'award_shipment': 'Award Shipment',
  'original_docs': 'Original Documents',
  'non_negotiable_docs': 'Non Negotiable Documents',
  'bank_endorsement': 'Bank Endorsement',
  'send_to_clearing_agent': 'Send to Clearing Agent',
  'under_clearing_agent': 'Under Clearing Agent',
  'release_orders': 'Release Orders',
  'gate_out': 'Gate Out',
  'transportation': 'Transportation',
  'warehouse': 'Warehouse',
  'documents': 'Documents',
  'bills': 'Bills'
}

interface AlertData {
  shipment_id: string
  shipment_reference: string
  stage_name: string
  target_date: string
  current_stage: string
  alert_type: 'upcoming' | 'overdue'
  days_until_target: number
  responsible_team: string
  stage_target_id: string
}

function formatDate(dateString: string): string {
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', { 
    year: 'numeric', 
    month: 'long', 
    day: 'numeric' 
  })
}

function generateUpcomingAlertEmail(alert: AlertData): string {
  const stageName = STAGE_NAMES[alert.stage_name] || alert.stage_name
  const daysText = alert.days_until_target === 0 
    ? 'today' 
    : alert.days_until_target === 1 
      ? 'tomorrow' 
      : `in ${alert.days_until_target} days`

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9fafb; padding: 30px; border-radius: 0 0 10px 10px; }
    .alert-box { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 15px; margin: 20px 0; border-radius: 4px; }
    .info-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #e5e7eb; }
    .info-label { font-weight: bold; color: #6b7280; }
    .info-value { color: #111827; }
    .button { display: inline-block; background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin-top: 20px; }
    .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⚠️ Stage Target Date Alert</h1>
      <p>Upcoming Deadline Notification</p>
    </div>
    <div class="content">
      <div class="alert-box">
        <h3 style="margin-top: 0;">⏰ Stage Target Date Approaching</h3>
        <p>The target date for <strong>${stageName}</strong> is <strong>${daysText}</strong>.</p>
      </div>
      
      <h3>Shipment Details</h3>
      <div class="info-row">
        <span class="info-label">Shipment Reference:</span>
        <span class="info-value">${alert.shipment_reference}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Stage:</span>
        <span class="info-value">${stageName}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Current Stage:</span>
        <span class="info-value">${STAGE_NAMES[alert.current_stage] || alert.current_stage}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Target Date:</span>
        <span class="info-value">${formatDate(alert.target_date)}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Days Remaining:</span>
        <span class="info-value">${alert.days_until_target} day(s)</span>
      </div>
      <div class="info-row">
        <span class="info-label">Responsible Team:</span>
        <span class="info-value">${alert.responsible_team}</span>
      </div>
      
      <p style="margin-top: 30px;">
        Please ensure this stage is completed before the target date to maintain the shipment schedule.
      </p>
      
      <a href="${Deno.env.get('APP_URL') || 'http://localhost:5500'}/shipment-tracker.html?id=${alert.shipment_id}" class="button">
        View Shipment Details
      </a>
    </div>
    <div class="footer">
      <p>This is an automated alert from Imports 360 Shipment Management System</p>
      <p>© ${new Date().getFullYear()} Imports 360. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
  `
}

function generateOverdueAlertEmail(alert: AlertData): string {
  const stageName = STAGE_NAMES[alert.stage_name] || alert.stage_name
  const daysOverdue = Math.abs(alert.days_until_target)

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9fafb; padding: 30px; border-radius: 0 0 10px 10px; }
    .alert-box { background: #fee2e2; border-left: 4px solid #ef4444; padding: 15px; margin: 20px 0; border-radius: 4px; }
    .info-row { display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #e5e7eb; }
    .info-label { font-weight: bold; color: #6b7280; }
    .info-value { color: #111827; }
    .button { display: inline-block; background: #ef4444; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin-top: 20px; }
    .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🚨 Stage Target Date Overdue</h1>
      <p>Urgent Action Required</p>
    </div>
    <div class="content">
      <div class="alert-box">
        <h3 style="margin-top: 0;">❌ Target Date Has Passed</h3>
        <p>The target date for <strong>${stageName}</strong> has passed by <strong>${daysOverdue} day(s)</strong>.</p>
        <p style="margin-bottom: 0;"><strong>Immediate action is required!</strong></p>
      </div>
      
      <h3>Shipment Details</h3>
      <div class="info-row">
        <span class="info-label">Shipment Reference:</span>
        <span class="info-value">${alert.shipment_reference}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Stage:</span>
        <span class="info-value">${stageName}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Current Stage:</span>
        <span class="info-value">${STAGE_NAMES[alert.current_stage] || alert.current_stage}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Target Date:</span>
        <span class="info-value">${formatDate(alert.target_date)}</span>
      </div>
      <div class="info-row">
        <span class="info-label">Days Overdue:</span>
        <span class="info-value" style="color: #ef4444; font-weight: bold;">${daysOverdue} day(s)</span>
      </div>
      <div class="info-row">
        <span class="info-label">Responsible Team:</span>
        <span class="info-value">${alert.responsible_team}</span>
      </div>
      
      <p style="margin-top: 30px; color: #ef4444; font-weight: bold;">
        ⚠️ This stage is overdue and may be impacting the overall shipment schedule. Please prioritize completion of this stage immediately.
      </p>
      
      <a href="${Deno.env.get('APP_URL') || 'http://localhost:5500'}/shipment-tracker.html?id=${alert.shipment_id}" class="button">
        Take Action Now
      </a>
    </div>
    <div class="footer">
      <p>This is an automated alert from Imports 360 Shipment Management System</p>
      <p>© ${new Date().getFullYear()} Imports 360. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
  `
}

serve(async (req) => {
  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🔔 Stage Target Alerts: Starting alert check...')

    // Initialize clients
    const resend = new Resend(Deno.env.get('RESEND_API_KEY')!)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get list of alert emails
    const { data: alertEmailsList, error: alertEmailsError } = await supabaseAdmin
      .from('alert_emails_list')
      .select('emails')
      .order('added_at', { ascending: false })
      .limit(1)
      .single()

    if (alertEmailsError) {
      console.warn('⚠️ No alert emails configured, using default')
    }

    const alertEmails = alertEmailsList?.emails 
      ? alertEmailsList.emails.split(',').map((e: string) => e.trim()).filter((e: string) => e.length > 0)
      : []

    if (alertEmails.length === 0) {
      console.warn('⚠️ No alert email recipients configured. Please add emails to alert_emails_list table.')
    }

    // Get shipments needing alerts
    const { data: alerts, error: alertsError } = await supabaseAdmin
      .rpc('get_shipments_needing_alerts')

    if (alertsError) {
      console.error('Error fetching alerts:', alertsError)
      throw alertsError
    }

    if (!alerts || alerts.length === 0) {
      console.log('✅ No alerts to send')
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No alerts needed',
          alerts_sent: 0
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📋 Found ${alerts.length} alert(s) to send`)

    const results = []
    let successCount = 0
    let errorCount = 0

    // Process each alert
    for (const alert of alerts) {
      try {
        const alertData = alert as AlertData
        console.log(`📧 Processing ${alertData.alert_type} alert for ${alertData.shipment_reference} - Stage: ${alertData.stage_name}`)

        // Generate email content
        const emailHTML = alertData.alert_type === 'upcoming'
          ? generateUpcomingAlertEmail(alertData)
          : generateOverdueAlertEmail(alertData)

        const subject = alertData.alert_type === 'upcoming'
          ? `⚠️ Stage Target Approaching: ${alertData.shipment_reference} - ${STAGE_NAMES[alertData.stage_name]}`
          : `🚨 Stage Target OVERDUE: ${alertData.shipment_reference} - ${STAGE_NAMES[alertData.stage_name]}`

        // Send email to all configured recipients
        if (alertEmails.length > 0) {
          const { data: emailData, error: emailError } = await resend.emails.send({
            from: 'Imports 360 Alerts <onboarding@resend.dev>',
            to: alertEmails,
            subject: subject,
            html: emailHTML,
          })

          if (emailError) {
            console.error(`❌ Error sending email for ${alertData.shipment_reference}:`, emailError)
            errorCount++
            results.push({
              shipment: alertData.shipment_reference,
              stage: alertData.stage_name,
              alert_type: alertData.alert_type,
              status: 'failed',
              error: emailError.message
            })
            continue
          }

          console.log(`✅ Email sent successfully for ${alertData.shipment_reference}`)
        } else {
          console.log(`⚠️ Skipping email (no recipients) for ${alertData.shipment_reference}`)
        }

        // Mark alert as sent
        const { error: markError } = await supabaseAdmin
          .rpc('mark_stage_alert_sent', {
            p_stage_target_id: alertData.stage_target_id,
            p_alert_type: alertData.alert_type
          })

        if (markError) {
          console.error(`❌ Error marking alert as sent:`, markError)
        } else {
          console.log(`✅ Alert marked as sent in database`)
        }

        successCount++
        results.push({
          shipment: alertData.shipment_reference,
          stage: alertData.stage_name,
          alert_type: alertData.alert_type,
          status: 'success',
          recipients: alertEmails.length
        })

      } catch (error) {
        console.error(`❌ Error processing alert:`, error)
        errorCount++
        results.push({
          shipment: alert.shipment_reference,
          stage: alert.stage_name,
          alert_type: alert.alert_type,
          status: 'failed',
          error: error.message
        })
      }
    }

    console.log(`\n📊 Summary: ${successCount} successful, ${errorCount} failed`)

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processed ${alerts.length} alert(s)`,
        alerts_sent: successCount,
        alerts_failed: errorCount,
        results: results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Fatal error:', error)
    return new Response(
      JSON.stringify({ 
        success: false,
        error: error.message 
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
