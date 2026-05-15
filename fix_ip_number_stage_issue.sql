-- ============================================================================
-- FIX: IP Number Stage Advancement Issue
-- ============================================================================
-- Issue: IP Number stage cannot advance to LC Opening due to missing requirements
-- Root Cause: stage_requirements_met function is checking wrong table/condition

-- First, let's check what the current function is doing for LC Opening stage
SELECT 'Current stage_requirements_met function content:' as info;

-- The issue is likely in the stage_requirements_met function
-- Let's look at what it's checking for 'lc_opening' stage

-- Check if the function exists and what it's doing
SELECT 
  p.proname as function_name,
  pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
AND p.proname = 'stage_requirements_met';

-- Now let's fix the function - the issue is likely in the lc_opening requirement
CREATE OR REPLACE FUNCTION public.stage_requirements_met(
    p_shipment_id uuid,
    p_to_stage public.stage
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  shipment_rec record;
  v_current_year integer;
  v_seed_product_variety_id uuid;
  v_has_seed_product boolean;
  v_forecast_exists boolean;
  v_enlistment_status boolean;
BEGIN
  -- Get the shipment record
  SELECT * INTO shipment_rec
  FROM public.shipment
  WHERE id = p_shipment_id;

  -- Get current year for forecast validation
  v_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
  
  -- Check if shipment has any "Seed" commodity products
  SELECT sp.product_variety_id INTO v_seed_product_variety_id
  FROM public.shipment_products sp
  JOIN public.product_variety pv ON sp.product_variety_id = pv.id
  WHERE sp.shipment_id = p_shipment_id
  AND pv.commodity = 'Seed'
  LIMIT 1;
  
  -- Determine if we have a seed product
  v_has_seed_product := (v_seed_product_variety_id IS NOT NULL);

  CASE p_to_stage
    -- FORECAST STAGE: Always allow (starting stage)
    WHEN 'forecast' THEN
      RETURN TRUE;
      
    -- ENLISTMENT VERIFICATION STAGE
    WHEN 'enlistment_verification' THEN
      -- If no seed product, auto-complete this stage
      IF NOT v_has_seed_product THEN
        RAISE NOTICE 'No Seed product found in shipment %. Auto-completing enlistment_verification stage.', p_shipment_id;
        RETURN TRUE;
      END IF;
      
      -- If we have a seed product, check if it exists in forecast for current year
      SELECT EXISTS(
        SELECT 1 FROM public.forecast f
        WHERE f.product_variety_id = v_seed_product_variety_id
        AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
      ) INTO v_forecast_exists;
      
      RETURN v_forecast_exists;
      
    -- AVAILABILITY CONFIRMATION STAGE  
    WHEN 'availability_confirmation' THEN
      -- If no seed product, auto-complete this stage
      IF NOT v_has_seed_product THEN
        RAISE NOTICE 'No Seed product found in shipment %. Auto-completing availability_confirmation stage.', p_shipment_id;
        RETURN TRUE;
      END IF;
      
      -- If we have a seed product, check if enlistment_status is true in forecast for current year
      SELECT COALESCE(f.enlistment_status, false) INTO v_enlistment_status
      FROM public.forecast f
      WHERE f.product_variety_id = v_seed_product_variety_id
      AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
      LIMIT 1;
      
      RETURN v_enlistment_status;
      
    -- CORRECTED ORDER: proforma comes BEFORE purchase_order
    WHEN 'proforma' THEN
      -- Check availability_confirmation was completed
      RETURN EXISTS (
        SELECT 1 FROM public.availability_confirmation ac
        WHERE ac.shipment_id = p_shipment_id AND ac.available = TRUE
      );
      
    WHEN 'purchase_order' THEN
      -- Check proforma_invoice document was uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.proforma_invoice pi
        WHERE pi.shipment_id = p_shipment_id AND pi.file_url IS NOT NULL
      );
    
    -- INVOICE STAGE
    WHEN 'invoice' THEN
      -- Check purchase_order document was uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.purchase_order po
        WHERE po.shipment_id = p_shipment_id AND po.po_file_url IS NOT NULL
      );
      
    -- IP NUMBER STAGE  
    WHEN 'ip_number' THEN
      -- Check commercial_invoice document was uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.commercial_invoice ci
        WHERE ci.shipment_id = p_shipment_id AND ci.file_url IS NOT NULL
      );
      
    -- LC OPENING STAGE (This is where the issue is!)
    WHEN 'lc_opening' THEN
      -- Check ip_number document was uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.ip_number ip
        WHERE ip.shipment_id = p_shipment_id AND ip.file_url IS NOT NULL
      );
      
    -- All other stages remain the same...
    WHEN 'lc_shared_with_supplier' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.letter_of_credit lc
        WHERE lc.shipment_id = p_shipment_id AND lc.file_url IS NOT NULL
      );
    WHEN 'shipment_details_from_supplier' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.lc_share lcs
        WHERE lcs.shipment_id = p_shipment_id
      );
    WHEN 'freight_query' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.supplier_shipment_details ssd
        WHERE ssd.shipment_id = p_shipment_id
      );
    WHEN 'award_shipment' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.freight_query fq
        WHERE fq.shipment_id = p_shipment_id
      );
    WHEN 'non_negotiable_docs' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.shipment_awarded sa
        WHERE sa.shipment_id = p_shipment_id AND sa.awarded = TRUE
      );
    WHEN 'original_docs' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.non_negotiable_docs nnd
        WHERE nnd.shipment_id = p_shipment_id AND nnd.docs_url IS NOT NULL
      );
    WHEN 'bank_endorsement' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.original_docs od
        WHERE od.shipment_id = p_shipment_id AND od.docs_url IS NOT NULL
      );
    WHEN 'send_to_clearing_agent' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.bank_endorsement be
        WHERE be.shipment_id = p_shipment_id AND be.endorsed = TRUE
      );
    WHEN 'under_clearing_agent' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.docs_to_clearing_agent dtca
        WHERE dtca.shipment_id = p_shipment_id AND dtca.slip_picture_url IS NOT NULL
      );
    WHEN 'release_orders' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.under_clearing_agent uca
        WHERE uca.shipment_id = p_shipment_id AND uca.is_received = TRUE
      );
    WHEN 'gate_out' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.release_orders ro
        WHERE ro.shipment_id = p_shipment_id
      );
    WHEN 'transportation' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.gate_out go
        WHERE go.shipment_id = p_shipment_id AND go.gate_out = TRUE
      );
    WHEN 'warehouse' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.transporter t
        WHERE t.shipment_id = p_shipment_id
      );
    WHEN 'bills' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.warehouse_arrival wa
        WHERE wa.shipment_id = p_shipment_id AND wa.arrived = TRUE
      );
    ELSE
      RAISE EXCEPTION 'Unknown stage: %', p_to_stage;
  END CASE;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in stage_requirements_met for shipment % stage %: %', p_shipment_id, p_to_stage, SQLERRM;
    RETURN FALSE;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO service_role;

-- Test the specific case: IP Number to LC Opening
SELECT 'Testing IP Number to LC Opening transition:' as test_info;

-- This will help debug the exact issue
DO $$
DECLARE
    test_shipment_id uuid;
    ip_data_exists boolean;
    test_result boolean;
BEGIN
    -- Get first shipment on IP Number stage (if any)
    SELECT id INTO test_shipment_id FROM public.shipment WHERE current_stage = 'ip_number' LIMIT 1;
    
    IF test_shipment_id IS NOT NULL THEN
        -- Check if IP Number data exists
        SELECT EXISTS(
            SELECT 1 FROM public.ip_number ip
            WHERE ip.shipment_id = test_shipment_id AND ip.file_url IS NOT NULL
        ) INTO ip_data_exists;
        
        -- Test stage requirements
        SELECT public.stage_requirements_met(test_shipment_id, 'lc_opening'::public.stage) INTO test_result;
        
        RAISE NOTICE 'Shipment: %', test_shipment_id;
        RAISE NOTICE 'IP Number data with file_url exists: %', ip_data_exists;
        RAISE NOTICE 'LC Opening stage requirements met: %', test_result;
        
        IF NOT ip_data_exists THEN
            RAISE NOTICE '❌ ISSUE FOUND: IP Number stage needs file_url to be uploaded before advancing to LC Opening';
            RAISE NOTICE '✅ SOLUTION: Upload a document in the IP Number stage first';
        END IF;
        
    ELSE
        RAISE NOTICE 'No shipments currently on IP Number stage for testing';
    END IF;
END $$;