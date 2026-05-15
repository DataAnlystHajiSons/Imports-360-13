import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface FbrDutyInput {
  invoice_amount: number;
  insurance_fix: number;
  landing_charges_rate: number;
  usd_rate: number;
  custom_duty_rate: number;
  additional_custom_duty_rate: number;
  regulatory_duty_rate: number;
  sales_tax_rate: number;
  additional_sales_tax_rate: number;
  income_tax_rate: number;
  excise_on_a_value_rate: number;
  l_single_declaration_amount: number;
  m_release_order_amount: number;
  n_stamp_duty_amount: number;
  as_per_psid: number;
}

function calculateFbrDuty(input: FbrDutyInput) {
  const total_after_insurance = (input.invoice_amount || 0) + (input.insurance_fix || 0);
  const landing_charges_amount = (input.landing_charges_rate || 0) * total_after_insurance;
  const total_invoice = total_after_insurance + landing_charges_amount;
  const access_value = total_invoice * (input.usd_rate || 0);
  const custom_duty_amount = access_value * (input.custom_duty_rate || 0);
  const additional_custom_duty_amount = access_value * (input.additional_custom_duty_rate || 0);
  const regulatory_duty_amount = access_value * (input.regulatory_duty_rate || 0);
  const value_for_sales_tax = access_value + custom_duty_amount + additional_custom_duty_amount + regulatory_duty_amount;
  const sales_tax_amount = value_for_sales_tax * (input.sales_tax_rate || 0);
  const additional_sales_tax_amount = value_for_sales_tax * (input.additional_sales_tax_rate || 0);
  const value_for_income_tax = value_for_sales_tax + sales_tax_amount + additional_sales_tax_amount;
  const income_tax_amount = value_for_income_tax * (input.income_tax_rate || 0);
  const custom = custom_duty_amount + additional_custom_duty_amount + regulatory_duty_amount + value_for_sales_tax + sales_tax_amount + additional_sales_tax_amount + value_for_income_tax + income_tax_amount;
  const excise_on_a_value_amount = access_value * (input.excise_on_a_value_rate || 0);
  const total_duties = custom + excise_on_a_value_amount + (input.l_single_declaration_amount || 0) + (input.m_release_order_amount || 0) + (input.n_stamp_duty_amount || 0);
  const difference = total_duties - (input.as_per_psid || 0);

  return {
    total_after_insurance,
    landing_charges_amount,
    total_invoice,
    access_value,
    custom_duty_amount,
    additional_custom_duty_amount,
    regulatory_duty_amount,
    value_for_sales_tax,
    sales_tax_amount,
    additional_sales_tax_amount,
    value_for_income_tax,
    income_tax_amount,
    custom,
    excise_on_a_value_amount,
    total_duties,
    difference,
  };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { input } = await req.json()

    const result = calculateFbrDuty(input)

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
