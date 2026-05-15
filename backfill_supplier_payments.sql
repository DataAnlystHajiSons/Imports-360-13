DO $$
DECLARE
    shipment_record RECORD;
    v_total_amount NUMERIC;
    v_supplier_id UUID;
    v_payment_term_id UUID;
BEGIN
    FOR shipment_record IN SELECT id, payment_term_id FROM public.shipment LOOP
        -- Check if a supplier_payments record already exists
        IF NOT EXISTS (SELECT 1 FROM public.supplier_payments WHERE shipment_id = shipment_record.id) THEN
            -- Get the supplier_id from the first product in the shipment
            SELECT pv.supplier_id INTO v_supplier_id
            FROM public.shipment_products sp
            JOIN public.product_variety pv ON sp.product_variety_id = pv.id
            WHERE sp.shipment_id = shipment_record.id
            LIMIT 1;

            -- Get the payment_term_id from the shipment
            v_payment_term_id := shipment_record.payment_term_id;

            -- Calculate the total amount for the shipment
            SELECT COALESCE(SUM(quantity * rate), 0)
            INTO v_total_amount
            FROM public.shipment_products
            WHERE shipment_id = shipment_record.id;

            -- Insert the new record into supplier_payments
            IF v_supplier_id IS NOT NULL AND v_payment_term_id IS NOT NULL THEN
                INSERT INTO public.supplier_payments (shipment_id, supplier_id, payment_term_id, total_amount)
                VALUES (shipment_record.id, v_supplier_id, v_payment_term_id, v_total_amount);

                RAISE NOTICE 'Created supplier_payments record for shipment_id: %', shipment_record.id;
            ELSE
                RAISE NOTICE 'Skipping shipment_id: % because supplier_id or payment_term_id is null', shipment_record.id;
            END IF;
        END IF;
    END LOOP;
END;
$$;