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
    const { email, quote_url } = await req.json()
    console.log('Request body:', { email, quote_url });

    if (!RESEND_API_KEY) {
      throw new Error('RESEND_API_KEY is not set.');
    }

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: `Imports 360 <${FROM_EMAIL}>`,
        to: email,
        subject: 'New Freight Query - Imports 360',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #7C3AED;">New Freight Query</h2>
            <p>Dear Logistics Partner,</p>
            <p>You have received a new freight query from Imports 360.</p>
            <p>Please submit your quote using the following link:</p>
            <p style="margin: 20px 0;">
              <a href="${quote_url}" style="background-color: #7C3AED; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
                Submit Quote
              </a>
            </p>
            <p>If the button doesn't work, copy and paste this link in your browser:</p>
            <p style="word-break: break-all; color: #666;">${quote_url}</p>
            <hr style="margin: 30px 0; border: none; border-top: 1px solid #eee;">
            <p style="font-size: 12px; color: #888;">
              This email was sent by Imports 360 Import Management System.<br>
              Please do not reply to this email.
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
