import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface InsuranceInput {
  value: number;
  rate: number;
  marine_perc: number;
  war_perc: number;
  asc_1: number;
  fif_perc: number;
  sts_perc: number;
  stamp: number;
}

interface InsuranceCalculationResult {
  amount: number;
  ten_perc: number;
  total_value: number;
  marine_amount: number;
  war_amount: number;
  fif_amount: number;
  sts_amount: number;
  grand_total: number;
  calculation_breakdown: {
    step1: string;
    step2: string;
    step3: string;
    step4: string;
    step5: string;
    step6: string;
    step7: string;
  };
}

function calculateInsurance(input: InsuranceInput): InsuranceCalculationResult {
  // Step 1: amount = value * rate
  const amount = input.value * (input.rate / 100);
  
  // Step 2: ten_perc = amount * 10%
  const ten_perc = amount * 0.10;
  
  // Step 3: total_value = amount + ten_perc
  const total_value = amount + ten_perc;
  
  // Step 4: marine_amount = total_value * marine_perc %
  const marine_amount = total_value * (input.marine_perc / 100);
  
  // Step 5: war_amount = total_value * war_perc %
  const war_amount = total_value * (input.war_perc / 100);
  
  // Step 6: base_for_fif_sts = (marine_amount + war_amount) + asc_1
  const base_for_fif_sts = marine_amount + war_amount + input.asc_1;
  
  // Step 7: fif_amount = base_for_fif_sts * fif_perc
  const fif_amount = base_for_fif_sts * (input.fif_perc / 100);
  
  // Step 8: sts_amount = base_for_fif_sts * sts_perc
  const sts_amount = base_for_fif_sts * (input.sts_perc / 100);
  
  // Step 9: grand_total = base_for_fif_sts + fif_amount + sts_amount + stamp
  const grand_total = base_for_fif_sts + fif_amount + sts_amount + input.stamp;

  return {
    amount: Math.round(amount * 100) / 100,
    ten_perc: Math.round(ten_perc * 100) / 100,
    total_value: Math.round(total_value * 100) / 100,
    marine_amount: Math.round(marine_amount * 100) / 100,
    war_amount: Math.round(war_amount * 100) / 100,
    fif_amount: Math.round(fif_amount * 100) / 100,
    sts_amount: Math.round(sts_amount * 100) / 100,
    grand_total: Math.round(grand_total * 100) / 100,
    calculation_breakdown: {
      step1: `amount = ${input.value} * ${input.rate}% = ${amount}`,
      step2: `ten_perc = ${amount} * 10% = ${ten_perc}`,
      step3: `total_value = ${amount} + ${ten_perc} = ${total_value}`,
      step4: `marine_amount = ${total_value} * ${input.marine_perc}% = ${marine_amount}`,
      step5: `war_amount = ${total_value} * ${input.war_perc}% = ${war_amount}`,
      step6: `fif_amount = (${marine_amount} + ${war_amount} + ${input.asc_1}) * ${input.fif_perc}% = ${fif_amount}`,
      step7: `grand_total = ${base_for_fif_sts} + ${fif_amount} + ${sts_amount} + ${input.stamp} = ${grand_total}`
    }
  };
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { input, shipment_id, user_id } = await req.json()

    // Validate required fields
    if (!input || typeof input.value !== 'number' || typeof input.rate !== 'number') {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: value and rate' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Set defaults for optional fields
    const calculationInput: InsuranceInput = {
      value: input.value,
      rate: input.rate,
      marine_perc: input.marine_perc || 0,
      war_perc: input.war_perc || 0,
      asc_1: input.asc_1 || 0,
      fif_perc: input.fif_perc || 0,
      sts_perc: input.sts_perc || 0,
      stamp: input.stamp || 0
    }

    // Perform calculations
    const result = calculateInsurance(calculationInput)

    // If shipment_id and user_id are provided, log the calculation
    if (shipment_id && user_id) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
      const supabase = createClient(supabaseUrl, supabaseKey)

      await supabase.from('calculation_audit').insert({
        shipment_id,
        calculation_type: 'insurance',
        input_data: calculationInput,
        output_data: result,
        calculated_by: user_id
      })
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        calculations: result 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in calculate-insurance function:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error', 
        details: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})