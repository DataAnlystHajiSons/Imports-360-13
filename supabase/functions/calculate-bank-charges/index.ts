import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface BankChargesInput {
  usd_amount: number;
  rate: number;
  services_charges_amount: number;
  swift_amount: number;
  fed_amount: number;
}

function calculateBankCharges(input: BankChargesInput) {
  const rs = (input.usd_amount || 0) * (input.rate || 0);
  const services_charges_per = rs > 0 ? ((input.services_charges_amount || 0) / rs) * 100 : 0;
  const swift_percentage = rs > 0 ? ((input.swift_amount || 0) / rs) * 100 : 0;
  const fed_per = (input.services_charges_amount || 0) > 0 ? ((input.fed_amount || 0) / (input.services_charges_amount || 0)) * 100 : 0;

  return {
    rs,
    services_charges_per,
    swift_percentage,
    fed_per,
  };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { input } = await req.json()

    const result = calculateBankCharges(input)

    return new Response(
      JSON.stringify({ success: true, calculations: result }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
