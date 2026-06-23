-- repopulate_latest_activity.sql
-- Run this in your Supabase SQL editor to retroactively backfill latest activity stages 
-- for all existing historical shipments. This version is exception-safe and dynamically 
-- handles tables that do not have an "updated_at" column.

BEGIN;

CREATE OR REPLACE FUNCTION public.backfill_latest_activity()
RETURNS void AS $$
DECLARE
    s RECORD;
    v_latest_stage TEXT;
    v_max_time TIMESTAMP WITH TIME ZONE;
    v_temp_time TIMESTAMP WITH TIME ZONE;
    v_table TEXT;
    v_mapped_stage TEXT;
    v_tables TEXT[][] := ARRAY[
        ['proforma_invoice', 'proforma'],
        ['purchase_order', 'purchase_order'],
        ['commercial_invoice', 'invoice'],
        ['letter_of_credit', 'lc_opening'],
        ['ip_number', 'ip_number'],
        ['non_negotiable_docs', 'non_negotiable_docs'],
        ['original_docs', 'original_docs'],
        ['bank_charges', 'lc_opening'],
        ['insurance', 'lc_opening'],
        ['freight_forwarder_bill', 'bills'],
        ['fbr_duty', 'under_clearing_agent'],
        ['bility', 'transportation'],
        ['clearing_agent_bill', 'under_clearing_agent'],
        ['warehouse_arrival', 'warehouse'],
        ['under_clearing_agent', 'under_clearing_agent'],
        ['release_orders', 'release_orders'],
        ['docs_to_clearing_agent', 'send_to_clearing_agent'],
        ['supplier_shipment_details', 'shipment_details_from_supplier'],
        ['costing', 'bills'],
        ['bank_endorsement', 'bank_endorsement'],
        ['gate_out', 'gate_out'],
        ['transporter', 'transportation'],
        ['bank_debit_advice', 'bank_debit_advice']
    ];
BEGIN
    FOR s IN SELECT id, current_stage, created_at FROM public.shipment LOOP
        -- Default to the shipment's current stage and created date
        v_latest_stage := s.current_stage::text;
        v_max_time := s.created_at;

        -- 1. Check the forecast table (special structure using product_variety_id)
        BEGIN
            SELECT MAX(updated_at) INTO v_temp_time 
            FROM public.forecast 
            WHERE product_variety_id IN (
                SELECT product_variety_id FROM public.shipment_products WHERE shipment_id = s.id
            );
            IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN
                v_max_time := v_temp_time;
                v_latest_stage := 'forecast';
            END IF;
        EXCEPTION WHEN OTHERS THEN
            v_temp_time := NULL;
        END;

        -- 2. Dynamically check all other 23 stage tables
        FOR i IN 1 .. array_upper(v_tables, 1) LOOP
            v_table := v_tables[i][1];
            v_mapped_stage := v_tables[i][2];
            v_temp_time := NULL;

            BEGIN
                -- Safely execute query to handle missing updated_at columns
                EXECUTE format('SELECT MAX(updated_at) FROM public.%I WHERE shipment_id = $1', v_table)
                INTO v_temp_time
                USING s.id;
                
                IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN
                    v_max_time := v_temp_time;
                    v_latest_stage := v_mapped_stage;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                -- If column or table doesn't exist, safely ignore and continue
                v_temp_time := NULL;
            END;
        END LOOP;

        -- Save the computed most recent edit details back to the parent shipment table
        UPDATE public.shipment 
        SET latest_activity_stage = v_latest_stage,
            latest_activity_at = v_max_time
        WHERE id = s.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Execute the retroactive backfill
SELECT public.backfill_latest_activity();

-- Cleanup the temporary helper function
DROP FUNCTION IF EXISTS public.backfill_latest_activity();

COMMIT;
