import { createClient } from '@supabase/supabase-js'
import { corsHeaders } from '../_shared/cors.ts'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!)

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { shipment_id } = await req.json()

    const { data: insurance, error: insuranceError } = await supabase
      .from('insurance')
      .select('*')
      .eq('shipment_id', shipment_id)
      .single()

    if (insuranceError && insuranceError.code !== 'PGRST116') {
      throw insuranceError
    }

    if (insurance) {
      const { data: documents, error: documentsError } = await supabase
        .from('insurance_documents')
        .select('*')
        .eq('insurance_id', insurance.id)

      if (documentsError) {
        throw documentsError
      }
      insurance.insurance_documents = documents || []
    }

    return new Response(JSON.stringify({ insurance }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
