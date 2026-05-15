-- This script creates a dynamic and scalable automation for calculating supplier payment due dates.

-- 1. The "Dictionary" Table
-- This table maps event names from the JSON to actual database tables and columns.
CREATE TABLE IF NOT EXISTS public.payment_event_definitions (
    event_name TEXT PRIMARY KEY,
    source_table TEXT NOT NULL,
    date_column TEXT NOT NULL,
    description TEXT
);

-- Insert the definition for the 'readiness_date' event. 
-- To add more events in the future (e.g., 'invoice_date'), you only need to add a new row here.
INSERT INTO public.payment_event_definitions (event_name, source_table, date_column, description)
VALUES ('readiness_date', 'supplier_shipment_details', 'readiness_date', 'Fires when the supplier provides the shipment readiness date.')
ON CONFLICT (event_name) DO NOTHING;


-- 2. The Dynamic Function
-- This function reads the payment schedule and uses the dictionary table to find the correct date.
CREATE OR REPLACE FUNCTION public.update_supplier_payment_due_date()
RETURNS TRIGGER AS $$
DECLARE
    v_shipment_id uuid;
    v_payment_term RECORD;
    v_schedule_item JSONB;
    v_event_def RECORD;
    v_event_date DATE;
    v_days_offset INT;
    v_query TEXT;
BEGIN
    -- Determine the shipment_id from the triggering table
    IF TG_TABLE_NAME = 'supplier_shipment_details' THEN
        v_shipment_id := NEW.shipment_id;
    -- Add other source tables here as you create more triggers
    -- ELSIF TG_TABLE_NAME = 'commercial_invoice' THEN
    --     v_shipment_id := NEW.shipment_id;
    END IF;

    -- Find the corresponding payment term for this shipment
    SELECT INTO v_payment_term pt.payment_schedule
    FROM public.supplier_payments sp
    JOIN public.payment_terms pt ON sp.payment_term_id = pt.id
    WHERE sp.shipment_id = v_shipment_id;

    IF NOT FOUND THEN RETURN NULL; END IF;

    -- Loop through the events in the payment schedule
    FOR v_schedule_item IN SELECT * FROM jsonb_array_elements(v_payment_term.payment_schedule)
    LOOP
        -- Look up the event in our dictionary
        SELECT * INTO v_event_def
        FROM public.payment_event_definitions
        WHERE event_name = v_schedule_item->>'event';

        -- If the event is defined in our dictionary and matches the table that fired the trigger
        IF FOUND AND TG_TABLE_NAME = v_event_def.source_table THEN
            -- Dynamically build a query to get the date from the correct table and column
            v_query := format('SELECT %I FROM public.%I WHERE shipment_id = %L', 
                            v_event_def.date_column, v_event_def.source_table, v_shipment_id);
            
            -- Execute the dynamic query
            EXECUTE v_query INTO v_event_date;

            -- If we found a date, calculate and update the due_date
            IF v_event_date IS NOT NULL THEN
                v_days_offset := (v_schedule_item->>'days_offset')::INT;
                
                UPDATE public.supplier_payments
                SET due_date = v_event_date + v_days_offset
                WHERE shipment_id = v_shipment_id;
            END IF;
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. The Trigger
-- This trigger still fires on the specific table, but the function it calls is now generic.
DROP TRIGGER IF EXISTS trigger_update_due_date_on_readiness ON public.supplier_shipment_details;
CREATE TRIGGER trigger_update_due_date_on_readiness
AFTER INSERT OR UPDATE OF readiness_date ON public.supplier_shipment_details
FOR EACH ROW
EXECUTE FUNCTION public.update_supplier_payment_due_date();
