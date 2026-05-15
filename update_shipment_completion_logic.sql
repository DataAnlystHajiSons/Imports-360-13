-- ============================================================================
-- Updated Shipment Completion Logic
-- ============================================================================
-- This trigger marks a shipment as completed when:
-- 1. Bills.per_unit_rate > 0 (costing is finalized)
-- 2. Shipment current_stage = 'bills' (all previous stages completed)
-- ============================================================================

-- Drop the old trigger and function
DROP TRIGGER IF EXISTS on_bill_update_or_insert ON public.bills;
DROP FUNCTION IF EXISTS public.update_shipment_status_to_completed();

-- Create the new trigger function
CREATE OR REPLACE FUNCTION public.update_shipment_status_to_completed()
RETURNS TRIGGER AS $$
DECLARE
    v_current_stage stage;
BEGIN
    -- Get the current stage of the shipment
    SELECT current_stage INTO v_current_stage
    FROM public.shipment
    WHERE id = NEW.shipment_id;

    -- Mark shipment as completed if:
    -- 1. per_unit_rate is greater than zero (costing is finalized)
    -- 2. current_stage is 'bills' (all previous stages are completed)
    IF NEW.per_unit_rate > 0 AND v_current_stage = 'bills' THEN
        UPDATE public.shipment
        SET status = 'completed'
        WHERE id = NEW.shipment_id;
        
        RAISE NOTICE 'Shipment % marked as completed. per_unit_rate: %, current_stage: %', 
                     NEW.shipment_id, NEW.per_unit_rate, v_current_stage;
    ELSE
        RAISE NOTICE 'Shipment % not completed. per_unit_rate: %, current_stage: %, required: per_unit_rate > 0 AND stage = bills', 
                     NEW.shipment_id, NEW.per_unit_rate, v_current_stage;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger on the costing table (not bills table)
CREATE TRIGGER on_costing_update_or_insert
  AFTER INSERT OR UPDATE OF per_unit_rate ON public.costing
  FOR EACH ROW 
  EXECUTE FUNCTION public.update_shipment_status_to_completed();

-- Add helpful comment
COMMENT ON FUNCTION public.update_shipment_status_to_completed() IS 
'Marks a shipment as completed when per_unit_rate > 0 in the costing table and current_stage = bills.
This ensures that costing is finalized and all previous stages are completed before marking shipment complete.';

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.update_shipment_status_to_completed() TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_shipment_status_to_completed() TO service_role;
