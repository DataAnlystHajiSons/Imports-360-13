import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

// Define CORS headers directly
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const FROM_EMAIL = Deno.env.get('FROM_EMAIL') || 'noreply@trade.hajisons.pk';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!RESEND_API_KEY) {
      throw new Error('RESEND_API_KEY is not set in environment variables.');
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Get the list of recipient emails from the database
    const { data: alertEmails, error: emailError } = await supabaseAdmin
      .from('alert_emails_list')
      .select('emails');

    if (emailError) {
      throw new Error(`Failed to fetch alert emails: ${emailError.message}`);
    }

    if (!alertEmails || alertEmails.length === 0) {
      return new Response(JSON.stringify({ message: 'No recipient emails found in alert_emails_alert table.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    const recipientEmails = alertEmails.map(row => row.emails);

    // 2. Calculate the target date (today + 60 days)
    const targetDate = new Date();
    targetDate.setDate(targetDate.getDate() + 60);
    const targetDateString = targetDate.toISOString().split('T')[0];

    // 3. Find forecasts that need alerts
    const { data: forecasts, error: forecastError } = await supabaseAdmin
      .from('forecast')
      .select(`id, date_of_sowing, product_variety (product_name, variety_name)`)
      .eq('date_of_sowing', targetDateString)
      .eq('dos_alert_sent', false);

    if (forecastError) {
      throw new Error(`Error fetching forecasts: ${forecastError.message}`);
    }

    if (forecasts.length === 0) {
      return new Response(JSON.stringify({ message: 'No alerts to send today.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // 4. Process each forecast
    for (const forecast of forecasts) {
      const productName = forecast.product_variety ? forecast.product_variety.product_name : 'N/A';
      const varietyName = forecast.product_variety ? forecast.product_variety.variety_name : 'N/A';

      // 5. Send email via Resend
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${RESEND_API_KEY}`
        },
        body: JSON.stringify({
          from: `Imports 360 - Alert System <${FROM_EMAIL}>`,
          to: recipientEmails,
          subject: '🌱 Sowing Date Alert - Imports 360',
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
              <div style="background: linear-gradient(135deg, #7C3AED 0%, #8B5CF6 100%); padding: 20px; border-radius: 10px 10px 0 0; text-align: center;">
                <h1 style="color: white; margin: 0; font-size: 24px;">🌱 Sowing Date Alert</h1>
              </div>
              <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; border: 1px solid #e9ecef;">
                <div style="background: white; padding: 20px; border-radius: 8px; border-left: 4px solid #7C3AED; margin-bottom: 20px;">
                  <h2 style="color: #1E293B; margin-top: 0;">Upcoming Sowing Date</h2>
                  <p style="font-size: 16px; color: #374151; line-height: 1.5;">
                    This is an alert that the sowing date for <strong>${productName} - ${varietyName}</strong> is scheduled for:
                  </p>
                  <p style="background: #7C3AED; color: white; padding: 12px 20px; border-radius: 6px; text-align: center; font-size: 18px; font-weight: bold; margin: 20px 0;">
                    📅 ${forecast.date_of_sowing}
                  </p>
                  <p style="color: #6B7280; font-size: 14px;">
                    Please ensure all preparations are completed on time.
                  </p>
                </div>
                <div style="background: #FEF3C7; padding: 15px; border-radius: 6px; border: 1px solid #F59E0B;">
                  <p style="margin: 0; color: #92400E; font-size: 14px;">
                    ⚠️ <strong>Note:</strong> This is an automated alert sent 60 days in advance.
                  </p>
                </div>
              </div>
              <div style="text-align: center; padding: 20px 0;">
                <p style="font-size: 12px; color: #9CA3AF; margin: 0;">
                  Sent by Imports 360 Import Management System<br>
                  Please do not reply to this email.
                </p>
              </div>
            </div>
          `
        }),
      });

      if (!response.ok) {
        const errorData = await response.text();
        console.error(`Failed to send email for forecast ID ${forecast.id}:`, errorData);
        continue;
      }

      // 6. Update the forecast to prevent re-sending
      const { error: updateError } = await supabaseAdmin
        .from('forecast')
        .update({ dos_alert_sent: true })
        .eq('id', forecast.id);

      if (updateError) {
        console.error(`Failed to update dos_alert_sent for forecast ID ${forecast.id}:`, updateError.message);
      }
    }

    return new Response(JSON.stringify({ message: `Successfully processed ${forecasts.length} alerts.` }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});