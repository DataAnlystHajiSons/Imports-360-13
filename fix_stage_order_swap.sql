-- ============================================================================
-- FIX: Stage Order Swap - Proforma and Purchase Order
-- ============================================================================
-- Frontend stage order has been changed from:
-- OLD: availability_confirmation -> purchase_order -> proforma
-- NEW: availability_confirmation -> proforma -> purchase_order
--
-- Need to update the stage_requirements_met function to match new order

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
  
  -- FIXED: Check if shipment has any "Seed" commodity products  
  -- Join with commodity table to check commodity name
  SELECT sp.product_variety_id INTO v_seed_product_variety_id
  FROM public.shipment_products sp
  JOIN public.product_variety pv ON sp.product_variety_id = pv.id
  JOIN public.commodity c ON pv.commodity_id = c.id  -- ✅ FIXED: Join with commodity table
  WHERE sp.shipment_id = p_shipment_id
  AND c.name = 'Seed'  -- ✅ FIXED: Use c.name instead of pv.commodity
  LIMIT 1;
  
  -- Determine if we have a seed product
  v_has_seed_product := (v_seed_product_variety_id IS NOT NULL);

  CASE p_to_stage
    -- ========================================================================
    -- FORECAST STAGE: Always allow (starting stage)
    -- ========================================================================
    WHEN 'forecast' THEN
      RETURN TRUE;
      
    -- ========================================================================
    -- ENLISTMENT VERIFICATION STAGE
    -- ========================================================================
    WHEN 'enlistment_verification' THEN
      -- If no seed product, auto-complete this stage
      IF NOT v_has_seed_product THEN
        RETURN TRUE; -- Auto-advance
      END IF;
      
      -- If seed product exists, check forecast
      SELECT EXISTS(
        SELECT 1 FROM public.forecast f
        WHERE f.product_variety_id = v_seed_product_variety_id
        AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
      ) INTO v_forecast_exists;
      
      RETURN v_forecast_exists;
      
    -- ========================================================================
    -- AVAILABILITY CONFIRMATION STAGE
    -- ========================================================================
    WHEN 'availability_confirmation' THEN
      -- If no seed product, auto-complete this stage
      IF NOT v_has_seed_product THEN
        RETURN TRUE; -- Auto-advance
      END IF;
      
      -- If seed product exists, check enlistment_status
      SELECT COALESCE(f.enlistment_status, false) INTO v_enlistment_status
      FROM public.forecast f
      WHERE f.product_variety_id = v_seed_product_variety_id
      AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year;
      
      RETURN v_enlistment_status;
      
    -- ========================================================================
    -- UPDATED ORDER: PROFORMA comes BEFORE PURCHASE ORDER
    -- ========================================================================
    WHEN 'proforma' THEN
      -- FIXED: Proforma now depends on availability_confirmation, not purchase_order
      RETURN EXISTS (
        SELECT 1 FROM public.availability_confirmation ac
        WHERE ac.shipment_id = p_shipment_id AND ac.available = TRUE
      );
      
    WHEN 'purchase_order' THEN
      -- FIXED: Purchase order now depends on proforma, not availability_confirmation
      RETURN EXISTS (
        SELECT 1 FROM public.proforma_invoice pi
        WHERE pi.shipment_id = p_shipment_id AND pi.file_url IS NOT NULL
      );
    
    -- ========================================================================
    -- ALL OTHER STAGES: Keep existing logic
    -- ========================================================================
    WHEN 'invoice' THEN
      -- Invoice still depends on purchase_order
      RETURN EXISTS (
        SELECT 1 FROM public.purchase_order po
        WHERE po.shipment_id = p_shipment_id AND po.po_file_url IS NOT NULL
      );
    WHEN 'ip_number' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.commercial_invoice ci
        WHERE ci.shipment_id = p_shipment_id AND ci.file_url IS NOT NULL
      );
    WHEN 'lc_opening' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.ip_number ip
        WHERE ip.shipment_id = p_shipment_id AND ip.file_url IS NOT NULL
      );
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
        WHERE nnd.shipment_id = p_shipment_id AND nnd.file_url IS NOT NULL
      );
    WHEN 'bank_endorsement' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.original_docs od
        WHERE od.shipment_id = p_shipment_id AND od.file_url IS NOT NULL
      );
    WHEN 'send_to_clearing_agent' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.bank_endorsement be
        WHERE be.shipment_id = p_shipment_id AND be.file_url IS NOT NULL
      );
    WHEN 'under_clearing_agent' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.send_to_clearing_agent stca
        WHERE stca.shipment_id = p_shipment_id
      );
    WHEN 'release_orders' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.under_clearing_agent uca
        WHERE uca.shipment_id = p_shipment_id
      );
    WHEN 'gate_out' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.release_orders ro
        WHERE ro.shipment_id = p_shipment_id AND ro.file_url IS NOT NULL
      );
    WHEN 'transportation' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.gate_out go
        WHERE go.shipment_id = p_shipment_id AND go.is_gate_out = TRUE
      );
    WHEN 'warehouse' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.transportation t
        WHERE t.shipment_id = p_shipment_id
      );
    WHEN 'bills' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.warehouse w
        WHERE w.shipment_id = p_shipment_id
      );
    ELSE
      RETURN FALSE;
  END CASE;
END;
$$;

-- Also need to update the stage_edge table to reflect the new order
-- Remove old edges
DELETE FROM public.stage_edge 
WHERE (from_stage = 'availability_confirmation' AND to_stage = 'purchase_order')
   OR (from_stage = 'purchase_order' AND to_stage = 'proforma')
   OR (from_stage = 'proforma' AND to_stage = 'invoice');

-- Add new edges for the swapped order
INSERT INTO public.stage_edge (from_stage, to_stage) VALUES
  ('availability_confirmation', 'proforma'),
  ('proforma', 'purchase_order'),
  ('purchase_order', 'invoice')
ON CONFLICT (from_stage, to_stage) DO NOTHING;

-- Verification query to check the new order
SELECT 'New stage order verification:' as info;
SELECT from_stage, to_stage 
FROM public.stage_edge 
WHERE from_stage IN ('availability_confirmation', 'proforma', 'purchase_order')
   OR to_stage IN ('availability_confirmation', 'proforma', 'purchase_order', 'invoice')
ORDER BY 
  CASE from_stage
    WHEN 'availability_confirmation' THEN 1
    WHEN 'proforma' THEN 2
    WHEN 'purchase_order' THEN 3
    ELSE 4
  END;