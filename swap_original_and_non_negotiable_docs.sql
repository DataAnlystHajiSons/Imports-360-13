-- ============================================================================
-- SQL Script to Swap "Original Docs" and "Non Negotiable Docs" Stage Order
-- ============================================================================
-- This script updates the backend to reflect the new stage order where
-- "original_docs" comes BEFORE "non_negotiable_docs"
-- ============================================================================

-- Step 1: Update stage_edge table to reflect new transitions
-- ============================================================================

BEGIN;

-- Delete the old transitions for these two stages
DELETE FROM public.stage_edge 
WHERE (from_stage = 'award_shipment' AND to_stage = 'non_negotiable_docs')
   OR (from_stage = 'non_negotiable_docs' AND to_stage = 'original_docs')
   OR (from_stage = 'original_docs' AND to_stage = 'bank_endorsement');

-- Insert the new transitions with swapped order
INSERT INTO public.stage_edge (from_stage, to_stage) VALUES
('award_shipment', 'original_docs'),           -- Award Shipment → Original Docs (NEW ORDER)
('original_docs', 'non_negotiable_docs'),      -- Original Docs → Non Negotiable Docs (SWAPPED)
('non_negotiable_docs', 'bank_endorsement');   -- Non Negotiable Docs → Bank Endorsement (NEW ORDER)

COMMIT;

-- Step 2: Update the stage_requirements_met function
-- ============================================================================

CREATE OR REPLACE FUNCTION public.stage_requirements_met(
  p_shipment_id uuid,
  p_to_stage public.stage
)
RETURNS boolean
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
  JOIN public.commodity c ON pv.commodity_id = c.id
  WHERE sp.shipment_id = p_shipment_id
  AND c.name = 'Seed'
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
    -- Complex Logic: Seed priority + Auto-complete for non-seed shipments
    -- ========================================================================
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
      
      IF v_forecast_exists THEN
        RAISE NOTICE 'Seed product found in forecast for current year. Allowing advancement to enlistment_verification.';
      ELSE
        RAISE NOTICE 'Seed product NOT found in forecast for current year. Blocking advancement.';
      END IF;
      
      RETURN v_forecast_exists;
      
    -- ========================================================================
    -- AVAILABILITY CONFIRMATION STAGE  
    -- Complex Logic: Seed priority + Auto-complete for non-seed shipments
    -- ========================================================================
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
      
      IF v_enlistment_status THEN
        RAISE NOTICE 'Seed product enlistment_status is TRUE. Allowing advancement to availability_confirmation.';
      ELSE
        RAISE NOTICE 'Seed product enlistment_status is FALSE or not found. Blocking advancement.';
      END IF;
      
      RETURN v_enlistment_status;
      
    -- ========================================================================
    -- PROFORMA STAGE
    -- ========================================================================
    WHEN 'proforma' THEN
      -- If it's not a seed product, it should have auto-completed the previous stage.
      IF NOT v_has_seed_product THEN
        RETURN TRUE;
      END IF;
      
      -- For seed products, advance only when the boolean field is true
      RETURN EXISTS (
        SELECT 1 FROM public.availability_confirmation ac
        WHERE ac.shipment_id = p_shipment_id AND ac.available = TRUE
      );
      
    -- ========================================================================
    -- PURCHASE ORDER STAGE
    -- ========================================================================
    WHEN 'purchase_order' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.proforma_invoice pi
        WHERE pi.shipment_id = p_shipment_id AND pi.file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- IP NUMBER STAGE
    -- ========================================================================
    WHEN 'ip_number' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.purchase_order po
        WHERE po.shipment_id = p_shipment_id AND po.po_file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- LC OPENING STAGE
    -- ========================================================================
    WHEN 'lc_opening' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.ip_number ip
        WHERE ip.shipment_id = p_shipment_id AND ip.file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- LC SHARED WITH SUPPLIER STAGE
    -- ========================================================================
    WHEN 'lc_shared_with_supplier' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.letter_of_credit lc
        WHERE lc.shipment_id = p_shipment_id AND lc.file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- INVOICE STAGE
    -- ========================================================================
    WHEN 'invoice' THEN
      -- Advance only when LC has been shared with supplier
      RETURN EXISTS (
        SELECT 1 FROM public.lc_share lcs
        WHERE lcs.shipment_id = p_shipment_id
      );
      
    -- ========================================================================
    -- SHIPMENT DETAILS FROM SUPPLIER STAGE
    -- ========================================================================
    WHEN 'shipment_details_from_supplier' THEN
      -- Advance only when invoice document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.commercial_invoice ci
        WHERE ci.shipment_id = p_shipment_id AND ci.file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- FREIGHT QUERY STAGE
    -- ========================================================================
    WHEN 'freight_query' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.supplier_shipment_details ssd
        WHERE ssd.shipment_id = p_shipment_id
      );
      
    -- ========================================================================
    -- AWARD SHIPMENT STAGE
    -- ========================================================================
    WHEN 'award_shipment' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.freight_query fq
        WHERE fq.shipment_id = p_shipment_id
      );
      
    -- ========================================================================
    -- ORIGINAL DOCS STAGE (NOW COMES FIRST - SWAPPED ORDER)
    -- Requirements: Award shipment must be completed
    -- ========================================================================
    WHEN 'original_docs' THEN
      -- Advance only when shipment has been awarded
      RETURN EXISTS (
        SELECT 1 FROM public.shipment_awarded sa
        WHERE sa.shipment_id = p_shipment_id AND sa.awarded = TRUE
      );
      
    -- ========================================================================
    -- NON NEGOTIABLE DOCS STAGE (NOW COMES SECOND - SWAPPED ORDER)
    -- Requirements: Original docs must be uploaded
    -- ========================================================================
    WHEN 'non_negotiable_docs' THEN
      -- Advance only when original docs have been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.original_docs od
        WHERE od.shipment_id = p_shipment_id AND od.docs_url IS NOT NULL
      );
      
    -- ========================================================================
    -- BANK ENDORSEMENT STAGE (NOW CHECKS NON-NEGOTIABLE DOCS)
    -- ========================================================================
    WHEN 'bank_endorsement' THEN
      -- Advance only when non-negotiable docs have been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.non_negotiable_docs nnd
        WHERE nnd.shipment_id = p_shipment_id AND nnd.file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- SEND TO CLEARING AGENT STAGE
    -- ========================================================================
    WHEN 'send_to_clearing_agent' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.bank_endorsement be
        WHERE be.shipment_id = p_shipment_id AND be.endorsed = TRUE
      );
      
    -- ========================================================================
    -- UNDER CLEARING AGENT STAGE
    -- ========================================================================
    WHEN 'under_clearing_agent' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.docs_to_clearing_agent dtca
        WHERE dtca.shipment_id = p_shipment_id AND dtca.slip_picture_url IS NOT NULL
      );
      
    -- ========================================================================
    -- RELEASE ORDERS STAGE
    -- ========================================================================
    WHEN 'release_orders' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.under_clearing_agent uca
        WHERE uca.shipment_id = p_shipment_id AND uca.is_received = TRUE
      );
      
    -- ========================================================================
    -- GATE OUT STAGE
    -- ========================================================================
    WHEN 'gate_out' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.release_orders ro
        WHERE ro.shipment_id = p_shipment_id
      );
      
    -- ========================================================================
    -- TRANSPORTATION STAGE
    -- ========================================================================
    WHEN 'transportation' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.gate_out go
        WHERE go.shipment_id = p_shipment_id AND go.is_gate_out = TRUE
      );
      
    -- ========================================================================
    -- WAREHOUSE STAGE
    -- ========================================================================
    WHEN 'warehouse' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.transporter t
        WHERE t.shipment_id = p_shipment_id
      );
      
    -- ========================================================================
    -- BILLS STAGE
    -- ========================================================================
    WHEN 'bills' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.warehouse_arrival wa
        WHERE wa.shipment_id = p_shipment_id
      );
      
    ELSE
      RETURN FALSE;
  END CASE;
  
EXCEPTION
  WHEN OTHERS THEN
    -- Log error and return false for safety
    RAISE WARNING 'Error in stage_requirements_met for shipment % to stage %: %', 
                 p_shipment_id, p_to_stage, SQLERRM;
    RETURN FALSE;
END;
$$;

-- ============================================================================
-- Verification Query
-- ============================================================================
-- Run this to verify the stage_edge table has been updated correctly:

SELECT from_stage, to_stage 
FROM public.stage_edge 
WHERE from_stage IN ('award_shipment', 'original_docs', 'non_negotiable_docs')
   OR to_stage IN ('original_docs', 'non_negotiable_docs', 'bank_endorsement')
ORDER BY 
  CASE from_stage
    WHEN 'award_shipment' THEN 1
    WHEN 'original_docs' THEN 2
    WHEN 'non_negotiable_docs' THEN 3
  END;

-- Expected result:
-- from_stage         | to_stage
-- -------------------+----------------------
-- award_shipment     | original_docs
-- original_docs      | non_negotiable_docs
-- non_negotiable_docs| bank_endorsement
