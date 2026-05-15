-- ====================================================================
--  SETUP SCRIPT FOR DYNAMIC PAYMENT AUTOMATION INFRASTRUCTURE
--  Run this entire script in your Supabase SQL Editor ONCE.
-- ====================================================================

-- 1. The "Dictionary" Table
-- This table maps event names from the JSON to actual database tables and columns.
CREATE TABLE IF NOT EXISTS public.payment_event_definitions (
    event_name TEXT PRIMARY KEY,
    source_table TEXT NOT NULL,
    date_column TEXT NOT NULL,
    description TEXT
);

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
    v_new_due_date DATE;
    v_query TEXT;
BEGIN
    RAISE NOTICE '[Payment Trigger]: Function started for table: %', TG_TABLE_NAME;

    IF TG_TABLE_NAME = 'supplier_shipment_details' THEN
        v_shipment_id := NEW.shipment_id;
    ELSIF TG_TABLE_NAME = 'commercial_invoice' THEN
        v_shipment_id := NEW.shipment_id;
    END IF;

    RAISE NOTICE '[Payment Trigger]: Processing for shipment_id: %', v_shipment_id;

    SELECT INTO v_payment_term pt.payment_schedule
    FROM public.supplier_payments sp
    JOIN public.payment_terms pt ON sp.payment_term_id = pt.id
    WHERE sp.shipment_id = v_shipment_id;

    IF NOT FOUND THEN
        RAISE NOTICE '[Payment Trigger]: No supplier_payments record found for shipment_id: %', v_shipment_id;
        RETURN NULL;
    END IF;

    RAISE NOTICE '[Payment Trigger]: Found payment schedule: %', v_payment_term.payment_schedule;

    FOR v_schedule_item IN SELECT * FROM jsonb_array_elements(v_payment_term.payment_schedule)
    LOOP
        RAISE NOTICE '[Payment Trigger]: Checking schedule item: %', v_schedule_item;

        SELECT * INTO v_event_def
        FROM public.payment_event_definitions
        WHERE event_name = v_schedule_item->>'event';

        IF FOUND AND TG_TABLE_NAME = v_event_def.source_table THEN
            RAISE NOTICE '[Payment Trigger]: Match found for event: %', v_event_def.event_name;

            EXECUTE format('SELECT ($1).%I', v_event_def.date_column) USING NEW INTO v_event_date;
            RAISE NOTICE '[Payment Trigger]: Extracted event date: %', v_event_date;

            IF v_event_date IS NOT NULL THEN
                v_days_offset := (v_schedule_item->>'days_offset')::INT;
                v_new_due_date := v_event_date + v_days_offset;
                RAISE NOTICE '[Payment Trigger]: Calculated new due_date: %', v_new_due_date;

                UPDATE public.supplier_payments
                SET due_date = v_new_due_date
                WHERE shipment_id = v_shipment_id;
                
                RAISE NOTICE '[Payment Trigger]: Successfully updated due_date for shipment_id: %', v_shipment_id;
            ELSE
                RAISE NOTICE '[Payment Trigger]: Event date is NULL, skipping update.';
            END IF;
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. The Helper Function for Creating Triggers
-- This function is called by the Edge Function. It safely builds and executes the CREATE TRIGGER command.
CREATE OR REPLACE FUNCTION public.create_trigger_for_payment_event(p_source_table TEXT, p_date_column TEXT)
RETURNS TEXT AS $$
DECLARE
    v_trigger_name TEXT;
    v_query TEXT;
    v_table_exists BOOLEAN;
BEGIN
    -- First, validate that the provided table and column exist in the schema
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = p_source_table
        AND column_name = p_date_column
    ) INTO v_table_exists;

    IF NOT v_table_exists THEN
        RAISE EXCEPTION 'Invalid input: The column "%" does not exist on table "%", or the table itself does not exist.', p_date_column, p_source_table;
    END IF;

    -- If validation passes, proceed with creating the trigger
    v_trigger_name := 'trigger_update_due_date_on_' || p_source_table;

    v_query := format(
        'CREATE OR REPLACE TRIGGER %I ' ||
        'AFTER INSERT OR UPDATE OF %I ON public.%I ' ||
        'FOR EACH ROW EXECUTE FUNCTION public.update_supplier_payment_due_date();',
        v_trigger_name, p_date_column, p_source_table
    );

    EXECUTE v_query;

    RETURN 'Successfully created trigger ' || v_trigger_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
