import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const FROM_EMAIL = Deno.env.get('FROM_EMAIL') || 'noreply@trade.hajisons.pk';
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  try {
    console.log('Function invoked');
    const { email, quote_url, is_revision } = await req.json()
    console.log('Request body:', { email, quote_url, is_revision });

    if (!RESEND_API_KEY) {
      throw new Error('RESEND_API_KEY is not set.');
    }

    const isRevision = !!is_revision;
    const emailSubject = isRevision ? 'Revision Requested: Freight Query - Imports 360' : 'New Freight Query - Imports 360';
    const emailHeading = isRevision ? 'Revision Requested for Freight Query' : 'New Freight Query';
    const emailDescription = isRevision 
      ? 'Our procurement team has requested a revision on your previously submitted quote. Your quotation form has been successfully unlocked for editing. Please update your rates and submit your revised quote using the button below:' 
      : 'You have received a new freight query from Imports 360. Please submit your quote using the following link:';

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: `Imports 360 <${FROM_EMAIL}>`,
        to: email,
        subject: emailSubject,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e2e8f0; border-radius: 12px; padding: 24px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);">
            <div style="text-align: center; border-bottom: 2px solid #7C3AED; padding-bottom: 16px; margin-bottom: 20px;">
              <h2 style="color: #7C3AED; margin: 0; font-size: 22px;">${emailHeading}</h2>
            </div>
            <p style="font-size: 15px; color: #1f2937; line-height: 1.5;">Dear Logistics Partner,</p>
            <p style="font-size: 15px; color: #4b5563; line-height: 1.6; margin-bottom: 24px;">${emailDescription}</p>
            <p style="text-align: center; margin: 30px 0;">
              <a href="${quote_url}" style="background-color: #7C3AED; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px; display: inline-block; box-shadow: 0 4px 10px rgba(124, 92, 237, 0.3);">
                ${isRevision ? 'Submit Revised Quote' : 'Submit Quote'}
              </a>
            </p>
            <p style="font-size: 14px; color: #4b5563; margin-top: 24px;">If the button doesn't work, copy and paste this link in your browser:</p>
            <p style="word-break: break-all; color: #2563eb; font-size: 13px; font-family: monospace; background-color: #f8fafc; padding: 10px; border-radius: 6px; border: 1px solid #e2e8f0;">${quote_url}</p>
            <hr style="margin: 30px 0; border: none; border-top: 1px solid #eee;">
            <p style="font-size: 12px; color: #888; text-align: center; line-height: 1.4;">
              This email was sent by the Imports 360 Import Management System.<br>
              Please do not reply directly to this automated email.
            </p>
          </div>
        `
      }),
    });

    if (!response.ok) {
      const errorData = await response.text();
      console.error('Resend API Error:', errorData);
      throw new Error(`Resend API Error: ${response.status} ${response.statusText}`);
    }

    console.log('Email sent successfully via Resend');

    return new Response(JSON.stringify({ message: 'Email sent successfully' }), {
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error in function:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
