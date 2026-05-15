-- ============================================================================
-- UPDATE: stage_requirements_met function for Forecast-based Auto-Advancement
-- ============================================================================
-- This updates the existing function to implement the requested logic:
-- 1. Forecast stage: Check if product exists in forecast table for current year
-- 2. Enlistment verification: Check if enlistment_status is true in forecast table

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
  v_product_variety_id uuid;
  v_forecast_exists boolean;
  v_enlistment_status boolean;
BEGIN
  -- Get the shipment record
  SELECT * INTO shipment_rec
  FROM public.shipment
  WHERE id = p_shipment_id;

  -- Get current year for forecast validation
  v_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
  
  -- Get the first product variety from shipment
  SELECT sp.product_variety_id INTO v_product_variety_id
  FROM public.shipment_products sp
  WHERE sp.shipment_id = p_shipment_id
  LIMIT 1;

  CASE p_to_stage
    -- ========================================================================
    -- FORECAST STAGE: Always allow (starting stage)
    -- ========================================================================
    WHEN 'forecast' THEN
      RETURN TRUE;
      
    -- ========================================================================
    -- ENLISTMENT VERIFICATION STAGE
    -- NEW LOGIC: Check if product exists in forecast table for current year
    -- ========================================================================
    WHEN 'enlistment_verification' THEN
      -- Check if product variety exists in forecast for current year
      IF v_product_variety_id IS NULL THEN
        RETURN FALSE;
      END IF;
      
      SELECT EXISTS(
        SELECT 1 FROM public.forecast f
        WHERE f.product_variety_id = v_product_variety_id
        AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
      ) INTO v_forecast_exists;
      
      RETURN v_forecast_exists;
      
    -- ========================================================================
    -- AVAILABILITY CONFIRMATION STAGE  
    -- NEW LOGIC: Check if enlistment_status is true in forecast table
    -- ========================================================================
    WHEN 'availability_confirmation' THEN
      -- Check if enlistment_status is true in forecast for current year
      IF v_product_variety_id IS NULL THEN
        RETURN FALSE;
      END IF;
      
      SELECT COALESCE(f.enlistment_status, false) INTO v_enlistment_status
      FROM public.forecast f
      WHERE f.product_variety_id = v_product_variety_id
      AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
      LIMIT 1;
      
      RETURN v_enlistment_status;
      
    -- ========================================================================
    -- ALL OTHER STAGES: Keep existing logic unchanged
    -- ========================================================================
    WHEN 'purchase_order' THEN
      -- Advance only when the boolean field is true
      RETURN EXISTS (
        SELECT 1 FROM public.availability_confirmation ac
        WHERE ac.shipment_id = p_shipment_id AND ac.available = TRUE
      );
    WHEN 'proforma' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.purchase_order po
        WHERE po.shipment_id = p_shipment_id AND po.po_file_url IS NOT NULL
      );
    WHEN 'invoice' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.proforma_invoice pi
        WHERE pi.shipment_id = p_shipment_id AND pi.file_url IS NOT NULL
      );
    WHEN 'ip_number' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.commercial_invoice ci
        WHERE ci.shipment_id = p_shipment_id AND ci.file_url IS NOT NULL
      );
    WHEN 'lc_opening' THEN
      -- Advance only when the required document has been uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.ip_number ip
        WHERE ip.shipment_id = p_shipment_id AND ip.file_url IS NOT NULL
      );
    WHEN 'lc_shared_with_supplier' THEN
      -- Advance only when the required document has been uploaded
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
        WHERE nnd.shipment_id = p_shipment_id AND nnd.docs_url IS NOT NULL
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
$$;