-- This script creates the complete Payment Transaction Log system.

-- 1. The Transaction Table
-- This table will store a record for every individual payment made.
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    supplier_payment_id uuid NOT NULL,
    amount numeric NOT NULL CHECK (amount > 0),
    paid_at timestamp with time zone DEFAULT now(),
    method text,
    reference_code text,
    attachment_url text, -- For storing the URL of the payment proof
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    created_by uuid,
    CONSTRAINT payment_transactions_pkey PRIMARY KEY (id),
    CONSTRAINT payment_transactions_supplier_payment_id_fkey FOREIGN KEY (supplier_payment_id) REFERENCES public.supplier_payments(id) ON DELETE CASCADE,
    CONSTRAINT payment_transactions_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id)
);

-- 2. The Automation Function
-- This function recalculates the total paid amount and updates the status on the parent supplier_payments record.
CREATE OR REPLACE FUNCTION public.update_payment_summary()
RETURNS TRIGGER AS $$
DECLARE
    v_supplier_payment_id uuid;
    v_total_paid numeric;
    v_total_amount numeric;
    v_new_status text;
BEGIN
    -- Determine the affected supplier_payment_id from either the old or new record
    IF (TG_OP = 'DELETE') THEN
        v_supplier_payment_id := OLD.supplier_payment_id;
    ELSE
        v_supplier_payment_id := NEW.supplier_payment_id;
    END IF;

    -- Recalculate the sum of all transactions for the parent payment record
    SELECT SUM(amount)
    INTO v_total_paid
    FROM public.payment_transactions
    WHERE supplier_payment_id = v_supplier_payment_id;

    -- Get the total amount required for this payment from the parent table
    SELECT total_amount
    INTO v_total_amount
    FROM public.supplier_payments
    WHERE id = v_supplier_payment_id;

    -- Determine the new status based on the amounts
    IF COALESCE(v_total_paid, 0) >= v_total_amount THEN
        v_new_status := 'paid';
    ELSIF COALESCE(v_total_paid, 0) > 0 THEN
        v_new_status := 'partially_paid';
    ELSE
        v_new_status := 'pending';
    END IF;

    -- Update the parent supplier_payments table with the new totals and status
    UPDATE public.supplier_payments
    SET
        amount_paid = COALESCE(v_total_paid, 0),
        status = v_new_status
    WHERE id = v_supplier_payment_id;

    RETURN NULL; -- The result of an AFTER trigger is ignored, so we return NULL
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. The Trigger
-- This trigger fires the summary function after any change to the transactions table.
DROP TRIGGER IF EXISTS trigger_update_payment_summary ON public.payment_transactions;
CREATE TRIGGER trigger_update_payment_summary
    AFTER INSERT OR UPDATE OR DELETE ON public.payment_transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_payment_summary();
