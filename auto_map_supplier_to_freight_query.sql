-- ============================================================================
-- SQL Script to Auto-Map Supplier Details to Freight Query
-- ============================================================================
-- This script creates a trigger that automatically updates freight_query
-- whenever supplier_shipment_details are inserted or updated
-- ============================================================================

-- Step 1: Create or replace the trigger function
-- ============================================================================

CREATE OR REPLACE FUNCTION public.auto_map_supplier_to_freight_query()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_freight_query_exists BOOLEAN;
BEGIN
    -- Check if freight_query already exists for this shipment
    SELECT EXISTS(
        SELECT 1 
        FROM public.freight_query 
        WHERE shipment_id = NEW.shipment_id
    ) INTO v_freight_query_exists;

    -- If freight_query exists, update it with the new supplier details
    IF v_freight_query_exists THEN
        UPDATE public.freight_query
        SET 
            readiness_date = NEW.readiness_date,
            origin = NEW.origin,
            pick_up_address = NEW.address,
            gross_weight = NEW.gross_weight,
            net_weight = NEW.net_weight,
            no_of_cartoons = NEW.cartons_count
        WHERE shipment_id = NEW.shipment_id;
        
        RAISE NOTICE 'Auto-mapped supplier details to existing freight_query for shipment %', NEW.shipment_id;
    ELSE
        -- If freight_query doesn't exist, create a new record with mapped values
        INSERT INTO public.freight_query (
            shipment_id,
            readiness_date,
            origin,
            pick_up_address,
            gross_weight,
            net_weight,
            no_of_cartoons
        ) VALUES (
            NEW.shipment_id,
            NEW.readiness_date,
            NEW.origin,
            NEW.address,
            NEW.gross_weight,
            NEW.net_weight,
            NEW.cartons_count
        );
        
        RAISE NOTICE 'Created new freight_query with auto-mapped supplier details for shipment %', NEW.shipment_id;
    END IF;

    RETURN NEW;
END;
$$;

-- Step 2: Drop existing trigger if it exists
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_auto_map_supplier_to_freight_query 
ON public.supplier_shipment_details;

-- Step 3: Create the trigger
-- ============================================================================

CREATE TRIGGER trigger_auto_map_supplier_to_freight_query
AFTER INSERT OR UPDATE ON public.supplier_shipment_details
FOR EACH ROW
EXECUTE FUNCTION public.auto_map_supplier_to_freight_query();

-- Step 4: Add comment for documentation
-- ============================================================================

COMMENT ON FUNCTION public.auto_map_supplier_to_freight_query() IS 
'Automatically maps supplier shipment details to freight query stage.
Triggered on INSERT or UPDATE of supplier_shipment_details.
Maps: readiness_date, origin, address→pick_up_address, gross_weight, net_weight, cartons_count→no_of_cartoons';

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Verify the function exists
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'auto_map_supplier_to_freight_query';

-- Verify the trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name = 'trigger_auto_map_supplier_to_freight_query';

-- ============================================================================
-- Test Query (Optional)
-- ============================================================================
-- To test the mapping, uncomment and run:
/*
-- Find a shipment with supplier details but no freight query
SELECT 
    ssd.shipment_id,
    ssd.readiness_date,
    ssd.address,
    ssd.origin,
    ssd.gross_weight,
    fq.id as freight_query_exists
FROM supplier_shipment_details ssd
LEFT JOIN freight_query fq ON ssd.shipment_id = fq.shipment_id
LIMIT 5;

-- Update supplier details to trigger the mapping
UPDATE supplier_shipment_details
SET readiness_date = readiness_date
WHERE shipment_id = 'your-test-shipment-id';
*/

-- ============================================================================
-- Script Completion Notice
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Auto-mapping trigger created successfully!';
    RAISE NOTICE 'Trigger: trigger_auto_map_supplier_to_freight_query';
    RAISE NOTICE 'Function: auto_map_supplier_to_freight_query()';
    RAISE NOTICE '';
    RAISE NOTICE 'Mapped fields:';
    RAISE NOTICE '  readiness_date → readiness_date';
    RAISE NOTICE '  origin → origin';
    RAISE NOTICE '  address → pick_up_address';
    RAISE NOTICE '  gross_weight → gross_weight';
    RAISE NOTICE '  net_weight → net_weight';
    RAISE NOTICE '  cartons_count → no_of_cartoons';
    RAISE NOTICE '========================================';
END $$;
