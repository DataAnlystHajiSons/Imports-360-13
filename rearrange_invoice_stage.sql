-- Rearrange stages: Move "Invoice" to come after "LC Shared with Supplier"
-- 
-- CURRENT ORDER:
-- ... -> Purchase Order -> Invoice -> IP Number -> LC Opening -> LC Shared -> Shipment Details -> ...
--
-- NEW ORDER:
-- ... -> Purchase Order -> IP Number -> LC Opening -> LC Shared -> Invoice -> Shipment Details -> ...

-- Step 1: Update stage_edge table to reflect new transitions
BEGIN;

-- Remove old edges involving invoice
DELETE FROM public.stage_edge WHERE from_stage = 'purchase_order' AND to_stage = 'invoice';
DELETE FROM public.stage_edge WHERE from_stage = 'invoice' AND to_stage = 'ip_number';
DELETE FROM public.stage_edge WHERE from_stage = 'lc_shared_with_supplier' AND to_stage = 'shipment_details_from_supplier';

-- Add new edges
-- Purchase Order -> IP Number (skip invoice for now)
INSERT INTO public.stage_edge (from_stage, to_stage)
VALUES ('purchase_order', 'ip_number')
ON CONFLICT (from_stage, to_stage) DO NOTHING;

-- LC Shared -> Invoice (invoice now comes after LC shared)
INSERT INTO public.stage_edge (from_stage, to_stage)
VALUES ('lc_shared_with_supplier', 'invoice')
ON CONFLICT (from_stage, to_stage) DO NOTHING;

-- Invoice -> Shipment Details (invoice leads to shipment details)
INSERT INTO public.stage_edge (from_stage, to_stage)
VALUES ('invoice', 'shipment_details_from_supplier')
ON CONFLICT (from_stage, to_stage) DO NOTHING;

COMMIT;

-- Step 2: Update the stage_requirements_met function
CREATE OR REPLACE FUNCTION public.stage_requirements_met(p_shipment_id uuid, p_to_stage public.stage)
RETURNS boolean
LANGUAGE plpgsql
AS $function$
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
    -- IP NUMBER STAGE (Now comes BEFORE invoice, changed from original)
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
    -- INVOICE STAGE (MOVED: Now comes AFTER lc_shared_with_supplier)
    -- ========================================================================
    WHEN 'invoice' THEN
      -- Advance only when LC has been shared with supplier
      RETURN EXISTS (
        SELECT 1 FROM public.lc_share lcs
        WHERE lcs.shipment_id = p_shipment_id
      );
      
    -- ========================================================================
    -- SHIPMENT DETAILS FROM SUPPLIER STAGE (Now requires invoice instead of LC share)
    -- ========================================================================
    WHEN 'shipment_details_from_supplier' THEN
      -- Advance only when invoice document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.commercial_invoice ci
        WHERE ci.shipment_id = p_shipment_id AND ci.file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- ALL REMAINING STAGES: Unchanged
    -- ========================================================================
    WHEN 'freight_query' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.supplier_shipment_details ssd
        WHERE ssd.shipment_id = p_shipment_id
      );
    WHEN 'award_shipment' THEN
      -- Advance only when the boolean field is true
      RETURN EXISTS (
        SELECT 1 FROM public.freight_query fq
        WHERE fq.shipment_id = p_shipment_id
      );
    WHEN 'non_negotiable_docs' THEN
      -- Advance only when the boolean field is true
      RETURN EXISTS (
        SELECT 1 FROM public.shipment_awarded sa
        WHERE sa.shipment_id = p_shipment_id AND sa.awarded = TRUE
      );
    WHEN 'original_docs' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.non_negotiable_docs nnd
        WHERE nnd.shipment_id = p_shipment_id AND nnd.file_url IS NOT NULL
      );
    WHEN 'bank_endorsement' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.original_docs od
        WHERE od.shipment_id = p_shipment_id AND od.docs_url IS NOT NULL
      );
    WHEN 'send_to_clearing_agent' THEN
      -- Advance only when the boolean field is true
      RETURN EXISTS (
        SELECT 1 FROM public.bank_endorsement be
        WHERE be.shipment_id = p_shipment_id AND be.endorsed = TRUE
      );
    WHEN 'under_clearing_agent' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.docs_to_clearing_agent dtca
        WHERE dtca.shipment_id = p_shipment_id AND dtca.slip_picture_url IS NOT NULL
      );
    WHEN 'release_orders' THEN
      -- Advance only when the boolean field is true
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
      -- Advance only when the boolean field is true
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
      RETURN FALSE;
  END CASE;
  
EXCEPTION
  WHEN OTHERS THEN
    -- Log error and return false for safety
    RAISE WARNING 'Error in stage_requirements_met for shipment % to stage %: %', 
                 p_shipment_id, p_to_stage, SQLERRM;
    RETURN FALSE;
END;
$function$;

-- Step 3: Verify the changes
SELECT 'Stage edges updated. New order:' as message;
SELECT from_stage, to_stage 
FROM public.stage_edge 
WHERE from_stage IN ('purchase_order', 'invoice', 'lc_shared_with_supplier')
   OR to_stage IN ('invoice', 'ip_number', 'shipment_details_from_supplier')
ORDER BY 
  CASE from_stage
    WHEN 'purchase_order' THEN 1
    WHEN 'ip_number' THEN 2
    WHEN 'lc_opening' THEN 3
    WHEN 'lc_shared_with_supplier' THEN 4
    WHEN 'invoice' THEN 5
  END;
