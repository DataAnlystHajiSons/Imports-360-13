import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const FROM_EMAIL = Deno.env.get('FROM_EMAIL') || 'noreply@trade.hajisons.pk';
const APP_URL = Deno.env.get('APP_URL') || 'https://imports360.netlify.app';
const COMPANY_NAME = Deno.env.get('COMPANY_NAME') || 'Haji Sons Group Pvt Ltd';
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  try {
    const { to, attachments, shipment_ref, shipment_id } = await req.json()

    console.log('📧 Starting email send process...');
    console.log('Recipient:', to);
    console.log('Document URLs count:', attachments?.length || 0);
    console.log('FROM_EMAIL:', FROM_EMAIL);

    if (!RESEND_API_KEY) {
      throw new Error('RESEND_API_KEY is not set.');
    }

    if (!to) {
      throw new Error('Recipient email is required.');
    }

    const form_link = `${APP_URL}/supplier-shipment-details-form.html?shipment_id=${shipment_id}`;

    // Generate HTML for document links
    let documentLinksHtml = '';
    if (attachments && attachments.length > 0) {
      documentLinksHtml += '<h3 style="color: #1F2937; margin: 30px 0 15px 0; font-size: 18px;">Attached Documents:</h3>';
      documentLinksHtml += '<ul style="list-style-type: none; padding: 0; margin: 0;">';
      attachments.forEach((url, index) => {
        const filename = url.split('/').pop() || `Document ${index + 1}`;
        documentLinksHtml += `
          <li style="margin-bottom: 10px;">
            <a href="${url}" 
               style="display: inline-block; background-color: #F3F4F6; color: #374151; 
                      padding: 12px 20px; text-decoration: none; border-radius: 6px; 
                      font-weight: 500; border: 1px solid #E5E7EB;">
              <i class="fas fa-file-alt" style="margin-right: 8px;"></i>${filename}
            </a>
          </li>
        `;
      });
      documentLinksHtml += '</ul>';
    }

    // Create unsubscribe link (required for commercial emails)
    const unsubscribe_url = `${APP_URL}/unsubscribe.html?email=${encodeURIComponent(to)}`;

    // Anti-spam optimized Resend payload
    const resendPayload = {
      from: `${COMPANY_NAME} <${FROM_EMAIL}>`,
      to: to,
      subject: `Shipment ${shipment_ref} - Documents Required`,
      html: `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Shipment ${shipment_ref} - Documents Required</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
</head>
<body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f4f4f4;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
        <tr>
            <td align="center" style="padding: 20px 0;">
                <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                    
                    <!-- Header -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #7C3AED 0%, #8B5CF6 100%); padding: 20px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 600;">${COMPANY_NAME}</h1>
                            <p style="color: #E5E7EB; margin: 8px 0 0 0; font-size: 16px;">Shipment Documentation Required</p>
                        </td>
                    </tr>
                    
                    <!-- Main Content -->
                    <tr>
                        <td style="padding: 30px;">
                            <h2 style="color: #1F2937; margin: 0 0 20px 0; font-size: 20px;">Shipment Reference: ${shipment_ref}</h2>
                            
                            <p style="color: #374151; line-height: 1.6; margin: 0 0 20px 0;">
                                Dear Supplier Partner,
                            </p>
                            
                            <p style="color: #374151; line-height: 1.6; margin: 0 0 20px 0;">
                                We have prepared the documentation for your shipment <strong>${shipment_ref}</strong>. 
                                To proceed with the next stage of processing, we require you to provide the shipment details through our secure online form.
                            </p>
                            
                            ${documentLinksHtml}

                            <!-- Call to Action Button -->
                            <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin: 30px 0;">
                                <tr>
                                    <td style="text-align: center;">
                                        <a href="${form_link}" 
                                           style="display: inline-block; background: linear-gradient(135deg, #7C3AED 0%, #8B5CF6 100%); 
                                                  color: #ffffff; padding: 16px 32px; text-decoration: none; 
                                                  border-radius: 6px; font-weight: 600; font-size: 16px;">
                                            Provide Shipment Details
                                        </a>
                                    </td>
                                </tr>
                            </table>
                            
                            <!-- Important Notice -->
                            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin: 20px 0; background-color: #FEF3C7; border-radius: 6px; border-left: 4px solid #F59E0B;">
                                <tr>
                                    <td style="padding: 15px;">
                                        <p style="margin: 0; color: #92400E; font-size: 14px;">
                                            <strong>Important:</strong> Please complete the form within 48 hours to avoid delays in processing.
                                        </p>
                                    </td>
                                </tr>
                            </table>
                            
                            <!-- Alternative Link -->
                            <p style="color: #6B7280; font-size: 14px; line-height: 1.5; margin: 20px 0;">
                                If the button above doesn't work, copy and paste this link in your browser:<br>
                                <a href="${form_link}" style="color: #7C3AED; word-break: break-all;">${form_link}</a>
                            </p>
                            
                            <p style="color: #374151; line-height: 1.6; margin: 20px 0 0 0;">
                                If you have any questions regarding this shipment, please contact your account manager.
                            </p>
                            
                            <p style="color: #374151; line-height: 1.6; margin: 20px 0 0 0;">
                                Best regards,<br>
                                <strong>${COMPANY_NAME} Team</strong>
                            </p>
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #F9FAFB; padding: 20px; border-radius: 0 0 8px 8px; text-align: center; border-top: 1px solid #E5E7EB;">
                            <p style="margin: 0; color: #9CA3AF; font-size: 12px; line-height: 1.5;">
                                This email was sent to <a href="mailto:${to}" style="color: #7C3AED;">${to}</a><br>
                                You received this email because you are listed as a supplier partner.<br>
                                <a href="${unsubscribe_url}" style="color: #7C3AED;">Unsubscribe</a> | 
                                <a href="mailto:${FROM_EMAIL}" style="color: #7C3AED;">Contact Support</a>
                            </p>
                        </td>
                    </tr>
                    
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
          `.trim(),
      attachments: attachments.map(url => ({
        filename: url.split('/').pop(),
        path: url
      }))
    };

    console.log('📤 Sending to Resend API...');
    console.log('Payload size:', JSON.stringify(resendPayload).length, 'bytes');

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify(resendPayload),
    });

    console.log('📨 Resend Response Status:', response.status);
    console.log('📨 Resend Response Headers:', Object.fromEntries(response.headers.entries()));

    if (!response.ok) {
      const errorData = await response.text();
      console.error('❌ Resend API Error Response:', errorData);
      throw new Error(`Resend API Error: ${response.status} ${response.statusText} - ${errorData}`);
    }

    const responseText = await response.text();
    console.log('📬 Resend Response Body:', responseText || 'Empty response body (normal for success)');

    return new Response(JSON.stringify({ 
      message: 'Email sent successfully with deliverability optimizations', 
      status: response.status,
      attachments_count: attachments?.length || 0
    }), {
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('❌ Error in function:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})