import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Resend } from 'https://esm.sh/resend@3.2.0'

// CORS headers for preflight and response
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // --- 1. Initialize Clients ---
    const resend = new Resend(Deno.env.get('RESEND_API_KEY')!)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // --- 2. Get Communication ID from Request ---
    const { communication_id } = await req.json()
    if (!communication_id) {
      throw new Error('communication_id is required.')
    }

    // --- 3. Fetch Data from Supabase ---
    const { data: commData, error: commError } = await supabaseAdmin
      .from('warehouse_communication')
      .select(
        `
        email_subject,
        email_body,
        cc_emails,
        warehouse ( email, warehouse_name )
      `)
      .eq('id', communication_id)
      .single()

    if (commError) throw commError
    if (!commData) throw new Error('Communication record not found.')

    // --- 4. Prepare Email Payload ---
    const recipientEmail = commData.warehouse?.email
    if (!recipientEmail) {
      throw new Error('Recipient email not found in warehouse details.')
    }

    // Validate and filter CC emails
    let ccEmails: string[] = []
    if (commData.cc_emails && commData.cc_emails.length > 0) {
      const emailRegex = /^[^S@]+@[^S@]+\.[^S@]+$/
      ccEmails = commData.cc_emails.filter((email: string) => emailRegex.test(email))
    }

    // --- 5. Send Email with Resend ---
    console.log('Sending Warehouse Intimation email:')
    console.log('  To:', recipientEmail)
    console.log('  Subject:', commData.email_subject)

    const emailPayload: any = {
      from: 'Imports 360 <onboarding@resend.dev>', // Replace with your verified domain if you have one
      to: [recipientEmail],
      subject: commData.email_subject || 'Warehouse Stock Intimation',
      html: commData.email_body ? commData.email_body.replace(/\n/g, '<br>') : '',
    }

    // Add CC emails if present
    if (ccEmails.length > 0) {
      emailPayload.cc = ccEmails
    }

    const { data, error } = await resend.emails.send(emailPayload)

    if (error) {
      console.error({ error })
      throw error
    }

    // Update status in database
    await supabaseAdmin
      .from('warehouse_communication')
      .update({ status: 'sent' })
      .eq('id', communication_id)

    // --- 6. Return Success Response ---
    return new Response(JSON.stringify({ 
      data,
      message: 'Email sent successfully'
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error(error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
