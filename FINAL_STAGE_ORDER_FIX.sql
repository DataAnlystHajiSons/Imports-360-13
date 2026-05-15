-- ============================================================================
-- FINAL FIX: Complete stage_requirements_met function with corrected order
-- ============================================================================
-- Based on your All Functions.txt, I can see the exact issues:
-- 1. The stage order for purchase_order/proforma is still wrong
-- 2. The advance_stage function might be missing parameters
-- 3. Need to ensure all functions are properly synchronized

-- First, let's fix the stage_requirements_met function with the correct order
CREATE OR REPLACE FUNCTION public.stage_requirements_met(
    p_shipment_id uuid,
    p_to_stage public.stage
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_commodity_id uuid;
  seed_commodity_id uuid;
  has_seed_commodity boolean := FALSE;
BEGIN
  -- Get the Seed commodity ID (if it exists)
  SELECT id INTO seed_commodity_id 
  FROM public.commodity 
  WHERE name = 'Seed' 
  LIMIT 1;

  -- Check if shipment has seed commodity products
  IF seed_commodity_id IS NOT NULL THEN
    has_seed_commodity := EXISTS (
      SELECT 1 
      FROM public.shipment_products sp
      JOIN public.product_variety pv ON sp.product_variety_id = pv.id
      WHERE sp.shipment_id = p_shipment_id 
      AND pv.commodity_id = seed_commodity_id
    );
  END IF;

  CASE p_to_stage
    WHEN 'forecast' THEN
      RETURN TRUE; -- Always allow forecast stage
      
    WHEN 'enlistment_verification' THEN
      -- If no seed commodity, auto-advance. If has seed commodity, check forecast existence
      IF NOT has_seed_commodity THEN
        RETURN TRUE; -- No seed commodity, skip enlistment verification stage
      ELSE
        -- Check if seed commodity product exists in forecast for current year
        RETURN EXISTS (
          SELECT 1 
          FROM public.shipment_products sp
          JOIN public.product_variety pv ON sp.product_variety_id = pv.id
          JOIN public.forecast f ON f.product_variety_id = pv.id
          WHERE sp.shipment_id = p_shipment_id 
          AND pv.commodity_id = seed_commodity_id
          AND f.year = EXTRACT(YEAR FROM CURRENT_DATE)
        );
      END IF;
      
    WHEN 'availability_confirmation' THEN
      -- If no seed commodity, auto-advance. If has seed commodity, check enlistment status
      IF NOT has_seed_commodity THEN
        RETURN TRUE; -- No seed commodity, skip enlistment verification stage
      ELSE
        -- Check if enlistment status is true for seed commodity product
        RETURN EXISTS (
          SELECT 1 
          FROM public.shipment_products sp
          JOIN public.product_variety pv ON sp.product_variety_id = pv.id
          JOIN public.forecast f ON f.product_variety_id = pv.id
          WHERE sp.shipment_id = p_shipment_id 
          AND pv.commodity_id = seed_commodity_id
          AND f.enlistment_status = TRUE
          AND f.year = EXTRACT(YEAR FROM CURRENT_DATE)
        );
      END IF;
      
    -- *** CORRECTED ORDER: proforma comes BEFORE purchase_order ***
    WHEN 'proforma' THEN
      -- Check availability_confirmation is completed
      RETURN EXISTS (
        SELECT 1 FROM public.availability_confirmation ac
        WHERE ac.shipment_id = p_shipment_id AND ac.available = TRUE
      );
      
    WHEN 'purchase_order' THEN
      -- Check proforma_invoice document is uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.proforma_invoice pi
        WHERE pi.shipment_id = p_shipment_id AND pi.file_url IS NOT NULL
      );
      
    -- *** END CORRECTED ORDER ***
      
    WHEN 'invoice' THEN
      -- Check purchase_order document is uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.purchase_order po
        WHERE po.shipment_id = p_shipment_id AND po.po_file_url IS NOT NULL
      );
      
    WHEN 'ip_number' THEN
      -- Check commercial_invoice document is uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.commercial_invoice ci
        WHERE ci.shipment_id = p_shipment_id AND ci.file_url IS NOT NULL
      );
      
    WHEN 'lc_opening' THEN
      -- Check ip_number document is uploaded (THIS IS THE ISSUE YOU'RE FACING)
      DECLARE
        ip_exists boolean;
        ip_file_url text;
      BEGIN
        -- Enhanced debugging for this specific issue
        SELECT 
          EXISTS(SELECT 1 FROM public.ip_number WHERE shipment_id = p_shipment_id),
          COALESCE((SELECT file_url FROM public.ip_number WHERE shipment_id = p_shipment_id LIMIT 1), 'NULL')
        INTO ip_exists, ip_file_url;
        
        -- Log for debugging the exact issue
        RAISE NOTICE 'lc_opening check - Shipment: %, IP exists: %, File URL: %', 
          p_shipment_id, ip_exists, ip_file_url;
          
        -- Return the result with detailed checking
        IF ip_exists AND ip_file_url IS NOT NULL AND ip_file_url != '' THEN
          RAISE NOTICE '✅ IP Number requirements met for lc_opening';
          RETURN TRUE;
        ELSE
          RAISE NOTICE '❌ IP Number requirements NOT met - exists: %, file_url: %', ip_exists, ip_file_url;
          RETURN FALSE;
        END IF;
      END;
      
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
        WHERE go.shipment_id = p_shipment_id AND go.is_gate_out = TRUE
      );
      
    WHEN 'warehouse' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.transporter t
        WHERE t.shipment_id = p_shipment_id
      );
      
    WHEN 'bills' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.warehouse_arrival wa
        WHERE wa.shipment_id = p_shipment_id
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

-- Now let's recreate the advance_stage function with proper parameters
CREATE OR REPLACE FUNCTION public.advance_stage(
    p_shipment_id uuid,
    p_to_stage public.stage,
    p_meta jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_from_stage public.stage;
  v_user_id uuid;
BEGIN
  -- Enhanced logging
  RAISE NOTICE 'advance_stage called: shipment=%, to_stage=%, meta=%', p_shipment_id, p_to_stage, p_meta;
  
  -- Get current user (with fallback)
  BEGIN
    v_user_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_user_id := NULL;
  END;
  
  -- Lock the shipment row to prevent race conditions
  SELECT current_stage INTO v_from_stage
  FROM public.shipment
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF v_from_stage IS NULL THEN
    RAISE EXCEPTION 'Shipment % not found', p_shipment_id;
  END IF;
  
  RAISE NOTICE 'Current stage: %, Target stage: %', v_from_stage, p_to_stage;

  -- Check if the transition is valid
  IF NOT EXISTS (
    SELECT 1 FROM public.stage_edge
    WHERE from_stage = v_from_stage AND to_stage = p_to_stage
  ) THEN
    RAISE EXCEPTION 'Invalid stage transition: % -> %', v_from_stage, p_to_stage;
  END IF;
  
  RAISE NOTICE 'Stage transition is valid';

  -- Check if the requirements for the new stage are met
  IF NOT public.stage_requirements_met(p_shipment_id, p_to_stage) THEN
    RAISE EXCEPTION 'Requirements not met for stage %', p_to_stage;
  END IF;
  
  RAISE NOTICE 'Stage requirements are met';

  -- Update the shipment stage
  UPDATE public.shipment
  SET current_stage = p_to_stage,
      updated_at = NOW()
  WHERE id = p_shipment_id;
  
  RAISE NOTICE 'Shipment stage updated to %', p_to_stage;

  -- Insert a record into the audit log
  INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta, at)
  VALUES (p_shipment_id, v_user_id, 'advance_stage', v_from_stage, p_to_stage, p_meta, NOW());
  
  RAISE NOTICE 'Audit log entry created';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'advance_stage error: %', SQLERRM;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO service_role;
GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO anon;

GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO anon;

-- Test with your specific shipment
SELECT 'Testing with your problematic shipment:' as test_section;

DO $$
DECLARE
    test_shipment_id uuid := 'fb6c3681-d213-40a3-998e-62fec92d0453';
    current_stage_val public.stage;
    next_stage_val public.stage;
BEGIN
    -- Get current stage
    SELECT current_stage INTO current_stage_val
    FROM public.shipment
    WHERE id = test_shipment_id;
    
    -- Get next stage
    SELECT to_stage INTO next_stage_val
    FROM public.stage_edge
    WHERE from_stage = current_stage_val;
    
    RAISE NOTICE '=== TESTING SHIPMENT: % ===', test_shipment_id;
    RAISE NOTICE 'Current stage: %', current_stage_val;
    RAISE NOTICE 'Next stage: %', next_stage_val;
    
    -- Test stage requirements
    IF public.stage_requirements_met(test_shipment_id, next_stage_val) THEN
        RAISE NOTICE '✅ Requirements met for %', next_stage_val;
        
        -- Test advance_stage
        BEGIN
            PERFORM public.advance_stage(test_shipment_id, next_stage_val, '{"test": true}'::jsonb);
            RAISE NOTICE '✅ advance_stage succeeded!';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ advance_stage failed: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE '❌ Requirements NOT met for %', next_stage_val;
    END IF;
END $$;