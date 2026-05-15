-- This script creates the automation for calculating supplier payment due dates.

-- 1. The Function
CREATE OR REPLACE FUNCTION public.update_supplier_payment_due_date()
RETURNS TRIGGER AS $$
DECLARE
    v_shipment_id uuid;
    v_payment_term RECORD;
    v_event_date DATE;
    v_days_offset INT;
    v_schedule_item JSONB;
BEGIN
    -- Determine the shipment_id from the triggering table
    IF TG_TABLE_NAME = 'supplier_shipment_details' THEN
        v_shipment_id := NEW.shipment_id;
    -- Add other tables here in the future, e.g.:
    -- ELSIF TG_TABLE_NAME = 'commercial_invoice' THEN
    --     v_shipment_id := NEW.shipment_id;
    END IF;

    -- Find the corresponding payment term for this shipment
    SELECT INTO v_payment_term
        pt.payment_schedule
    FROM public.supplier_payments sp
    JOIN public.payment_terms pt ON sp.payment_term_id = pt.id
    WHERE sp.shipment_id = v_shipment_id;

    -- If no payment term is found, do nothing
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Loop through the events in the payment schedule
    FOR v_schedule_item IN SELECT * FROM jsonb_array_elements(v_payment_term.payment_schedule)
    LOOP
        -- Case for 'readiness_date' event
        IF v_schedule_item->>'event' = 'readiness_date' THEN
            -- Get the readiness_date from the newly inserted/updated row
            SELECT NEW.readiness_date INTO v_event_date;

            -- If the date exists, calculate the due date
            IF v_event_date IS NOT NULL THEN
                v_days_offset := (v_schedule_item->>'days_offset')::INT;
                
                UPDATE public.supplier_payments
                SET due_date = v_event_date + v_days_offset
                WHERE shipment_id = v_shipment_id;
            END IF;
        END IF;

        -- Add other event cases here in the future
        -- IF v_schedule_item->>'event' = 'invoice_date' THEN ...

    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. The Trigger
CREATE TRIGGER trigger_update_due_date_on_readiness
AFTER INSERT OR UPDATE OF readiness_date ON public.supplier_shipment_details
FOR EACH ROW
EXECUTE FUNCTION public.update_supplier_payment_due_date();
