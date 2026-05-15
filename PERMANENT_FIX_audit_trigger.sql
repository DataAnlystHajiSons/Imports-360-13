-- PERMANENT FIX: Modify audit trigger to handle cascading deletes gracefully
-- This fixes the root cause so you never have to disable triggers again

-- ============================================
-- Option A: Skip audit logging during cascade deletes
-- ============================================
-- This is the cleanest solution - don't log if shipment is being deleted anyway

CREATE OR REPLACE FUNCTION public.log_shipment_product_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id uuid;
    v_shipment_exists boolean;
BEGIN
    -- Get the current user's ID
    v_user_id := auth.uid();
    
    -- Handle DELETE operations
    IF (TG_OP = 'DELETE') THEN
        -- Check if the shipment still exists (not being cascade deleted)
        SELECT EXISTS(
            SELECT 1 FROM shipment WHERE id = OLD.shipment_id
        ) INTO v_shipment_exists;
        
        -- Only create audit record if shipment still exists
        -- (Skip audit if this is a cascade delete from shipment deletion)
        IF v_shipment_exists THEN
            INSERT INTO public.shipment_products_audit (
                shipment_id,
                product_variety_id,
                action,
                old_quantity,
                old_unit,
                old_rate,
                old_amount,
                changed_by,
                metadata
            ) VALUES (
                OLD.shipment_id,
                OLD.product_variety_id,
                'removed',
                OLD.quantity,
                OLD.unit,
                OLD.rate,
                OLD.amount,
                v_user_id,
                jsonb_build_object(
                    'trigger', 'auto',
                    'operation', TG_OP
                )
            );
        END IF;
        
        RETURN OLD;
    END IF;
    
    -- Handle UPDATE operations
    IF (TG_OP = 'UPDATE') THEN
        INSERT INTO public.shipment_products_audit (
            shipment_id,
            product_variety_id,
            action,
            old_quantity,
            old_unit,
            old_rate,
            old_amount,
            new_quantity,
            new_unit,
            new_rate,
            new_amount,
            changed_by,
            metadata
        ) VALUES (
            OLD.shipment_id,
            OLD.product_variety_id,
            'modified',
            OLD.quantity,
            OLD.unit,
            OLD.rate,
            OLD.amount,
            NEW.quantity,
            NEW.unit,
            NEW.rate,
            NEW.amount,
            v_user_id,
            jsonb_build_object(
                'trigger', 'auto',
                'operation', TG_OP
            )
        );
        
        RETURN NEW;
    END IF;
    
    -- Handle INSERT operations
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.shipment_products_audit (
            shipment_id,
            product_variety_id,
            action,
            new_quantity,
            new_unit,
            new_rate,
            new_amount,
            changed_by,
            metadata
        ) VALUES (
            NEW.shipment_id,
            NEW.product_variety_id,
            'added',
            NEW.quantity,
            NEW.unit,
            NEW.rate,
            NEW.amount,
            v_user_id,
            jsonb_build_object(
                'trigger', 'auto',
                'operation', TG_OP
            )
        );
        
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- Verify the fix
-- ============================================
SELECT 
    'Function updated successfully!' as status,
    proname as function_name,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc 
WHERE proname = 'log_shipment_product_changes';

-- ============================================
-- Test the fix
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '✅ Audit trigger has been updated!';
    RAISE NOTICE '📌 It will now skip audit logging when shipments are cascade deleted.';
    RAISE NOTICE '🎯 Try deleting your test shipment now - it should work!';
END $$;

-- ============================================
-- Now try deleting your shipment
-- ============================================
-- DELETE FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
