-- Alternative Fixes for Audit Trigger Blocking Deletion
-- Choose ONE of these options based on your audit requirements

-- ============================================
-- OPTION 2: Make audit records CASCADE (Delete audit when shipment deleted)
-- ============================================
-- WARNING: This defeats the purpose of an audit trail!
-- Only use if you don't need audit history after shipment deletion

ALTER TABLE public.shipment_products_audit 
DROP CONSTRAINT IF EXISTS shipment_products_audit_shipment_id_fkey;

ALTER TABLE public.shipment_products_audit 
ADD CONSTRAINT shipment_products_audit_shipment_id_fkey 
FOREIGN KEY (shipment_id) 
REFERENCES public.shipment(id) 
ON DELETE CASCADE;


-- ============================================
-- OPTION 3: Remove the foreign key constraint entirely
-- ============================================
-- Keeps audit records but removes the relationship validation
-- Audit records will have orphaned shipment_ids

ALTER TABLE public.shipment_products_audit 
DROP CONSTRAINT IF EXISTS shipment_products_audit_shipment_id_fkey;


-- ============================================
-- OPTION 4: Temporarily disable the trigger for testing
-- ============================================
-- Find the trigger name
SELECT 
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'shipment_products'
  AND event_manipulation IN ('DELETE', 'UPDATE');

-- Disable the trigger (replace trigger_name with actual name from above)
-- ALTER TABLE shipment_products DISABLE TRIGGER log_shipment_product_changes_trigger;

-- Try deleting now, then re-enable:
-- ALTER TABLE shipment_products ENABLE TRIGGER log_shipment_product_changes_trigger;


-- ============================================
-- OPTION 5: Modify the trigger to handle cascading deletes
-- ============================================
-- This is the most robust solution

-- First, let's see the current trigger function
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'log_shipment_product_changes';

-- You'll need to modify the function to:
-- 1. Check if the shipment still exists before inserting
-- 2. Or use NULLIF to set shipment_id to NULL if it doesn't exist

CREATE OR REPLACE FUNCTION public.log_shipment_product_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id uuid;
    v_shipment_exists boolean;
BEGIN
    -- Get the current user's ID
    v_user_id := auth.uid();
    
    -- For DELETE operations during cascade, check if shipment still exists
    IF (TG_OP = 'DELETE') THEN
        -- Check if the shipment is being deleted (cascade scenario)
        SELECT EXISTS(SELECT 1 FROM shipment WHERE id = OLD.shipment_id) 
        INTO v_shipment_exists;
        
        -- Only log to audit if shipment still exists OR set shipment_id to NULL
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
            CASE WHEN v_shipment_exists THEN OLD.shipment_id ELSE NULL END,  -- Use NULL if shipment deleted
            OLD.product_variety_id,
            'removed',
            OLD.quantity,
            OLD.unit,
            OLD.rate,
            OLD.amount,
            v_user_id,
            jsonb_build_object(
                'trigger', 'auto',
                'operation', TG_OP,
                'cascade_delete', NOT v_shipment_exists
            )
        );
        
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
-- VERIFICATION
-- ============================================
-- After applying any fix, test with:

BEGIN;

DELETE FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- Check if it's gone
SELECT COUNT(*) FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- Check audit records
SELECT * FROM shipment_products_audit 
WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18' 
   OR shipment_id IS NULL
ORDER BY changed_at DESC 
LIMIT 5;

COMMIT;
-- Or ROLLBACK; if something went wrong
