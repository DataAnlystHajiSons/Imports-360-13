import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// CORS headers for preflight and response
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { event_name, source_table, date_column, description } = await req.json();

    // Basic validation
    if (!event_name || !source_table || !date_column) {
      throw new Error("Event name, source table, and date column are required.");
    }

    // Use the Supabase admin client for privileged operations
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // 1. Insert the definition into the dictionary table
    const { error: insertError } = await adminClient
      .from('payment_event_definitions')
      .insert({
        event_name,
        source_table,
        date_column,
        description
      });

    if (insertError) throw insertError;

    // 2. Remotely call the helper function in the database to create the trigger
    const { error: rpcError } = await adminClient.rpc('create_trigger_for_payment_event', {
      p_source_table: source_table,
      p_date_column: date_column
    });

    if (rpcError) throw rpcError;

    // Return success response
    return new Response(JSON.stringify({ message: `Successfully created event '${event_name}' and its database trigger.` }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    // Return error response
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
