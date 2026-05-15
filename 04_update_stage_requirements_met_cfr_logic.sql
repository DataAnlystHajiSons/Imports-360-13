-- ========================================================================
-- Migration: Update stage_requirements_met function
-- Purpose: 
--   1. Handle merged LC stage (remove lc_shared_with_supplier)
--   2. Auto-skip stages for CFR inco-term
--   3. Update validation logic for new workflow
-- ========================================================================

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
  v_inco_term text;
BEGIN
  -- Get the shipment record with inco_term
  SELECT * INTO shipment_rec
  FROM public.shipment
  WHERE id = p_shipment_id;
  
  -- Get inco_term for CFR skip logic
  v_inco_term := shipment_rec.inco_term;

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
    -- ========================================================================
    WHEN 'enlistment_verification' THEN
      IF NOT v_has_seed_product THEN
        RAISE NOTICE 'No Seed product found. Auto-completing enlistment_verification.';
        RETURN TRUE;
      END IF;
      
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
      IF NOT v_has_seed_product THEN
        RAISE NOTICE 'No Seed product found. Auto-completing availability_confirmation.';
        RETURN TRUE;
      END IF;
      
      SELECT COALESCE(f.enlistment_status, false) INTO v_enlistment_status
      FROM public.forecast f
      WHERE f.product_variety_id = v_seed_product_variety_id
      AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
      LIMIT 1;
      
      RETURN v_enlistment_status;
      
    -- ========================================================================
    -- PROFORMA STAGE
    -- ========================================================================
    WHEN 'proforma' THEN
      IF NOT v_has_seed_product THEN
        RETURN TRUE;
      END IF;
      
      RETURN EXISTS (
        SELECT 1 FROM public.availability_confirmation ac
        WHERE ac.shipment_id = p_shipment_id AND ac.available = TRUE
      );
      
    -- ========================================================================
    -- PURCHASE ORDER STAGE
    -- ========================================================================
    WHEN 'purchase_order' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.proforma_invoice pi
        WHERE pi.shipment_id = p_shipment_id AND pi.file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- IP NUMBER STAGE
    -- ========================================================================
    WHEN 'ip_number' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.purchase_order po
        WHERE po.shipment_id = p_shipment_id AND po.po_file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- LC OPENING STAGE (MERGED: Now handles both opening and sharing)
    -- ========================================================================
    WHEN 'lc_opening' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.ip_number ip
        WHERE ip.shipment_id = p_shipment_id AND ip.file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- INVOICE STAGE (Now comes after LC opening)
    -- Requirements: LC must be opened AND shared with supplier
    -- ========================================================================
    WHEN 'invoice' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.letter_of_credit lc
        WHERE lc.shipment_id = p_shipment_id 
        AND lc.file_url IS NOT NULL
        AND lc.lc_shared = TRUE  -- New merged field
      );
      
    -- ========================================================================
    -- SHIPMENT DETAILS FROM SUPPLIER STAGE
    -- CFR SKIP LOGIC: Auto-complete if inco_term is 'CFR'
    -- ========================================================================
    WHEN 'shipment_details_from_supplier' THEN
      -- Check if CFR - if yes, auto-skip this stage
      IF v_inco_term = 'CFR' THEN
        RAISE NOTICE 'Inco-term is CFR. Auto-skipping shipment_details_from_supplier stage.';
        RETURN TRUE;
      END IF;
      
      -- Normal validation: Invoice must be uploaded
      RETURN EXISTS (
        SELECT 1 FROM public.commercial_invoice ci
        WHERE ci.shipment_id = p_shipment_id AND ci.file_url IS NOT NULL
      );
      
    -- ========================================================================
    -- FREIGHT QUERY STAGE
    -- CFR SKIP LOGIC: Auto-complete if inco_term is 'CFR'
    -- ========================================================================
    WHEN 'freight_query' THEN
      -- Check if CFR - if yes, auto-skip this stage
      IF v_inco_term = 'CFR' THEN
        RAISE NOTICE 'Inco-term is CFR. Auto-skipping freight_query stage.';
        RETURN TRUE;
      END IF;
      
      -- Normal validation: Supplier shipment details must exist
      RETURN EXISTS (
        SELECT 1 FROM public.supplier_shipment_details ssd
        WHERE ssd.shipment_id = p_shipment_id
      );
      
    -- ========================================================================
    -- AWARD SHIPMENT STAGE
    -- CFR SKIP LOGIC: Auto-complete if inco_term is 'CFR'
    -- ========================================================================
    WHEN 'award_shipment' THEN
      -- Check if CFR - if yes, auto-skip this stage
      IF v_inco_term = 'CFR' THEN
        RAISE NOTICE 'Inco-term is CFR. Auto-skipping award_shipment stage.';
        RETURN TRUE;
      END IF;
      
      -- Normal validation: Freight query must exist
      RETURN EXISTS (
        SELECT 1 FROM public.freight_query fq
        WHERE fq.shipment_id = p_shipment_id
      );
      
    -- ========================================================================
    -- ORIGINAL DOCS STAGE
    -- ========================================================================
    WHEN 'original_docs' THEN
      -- If CFR, check invoice. If not CFR, check shipment_awarded
      IF v_inco_term = 'CFR' THEN
        -- For CFR, original docs can proceed after invoice
        RETURN EXISTS (
          SELECT 1 FROM public.commercial_invoice ci
          WHERE ci.shipment_id = p_shipment_id AND ci.file_url IS NOT NULL
        );
      ELSE
        -- For non-CFR, original docs need shipment to be awarded
        RETURN EXISTS (
          SELECT 1 FROM public.shipment_awarded sa
          WHERE sa.shipment_id = p_shipment_id AND sa.awarded = TRUE
        );
      END IF;
      
    -- ========================================================================
    -- ALL REMAINING STAGES: Unchanged
    -- ========================================================================
    WHEN 'non_negotiable_docs' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.original_docs od
        WHERE od.shipment_id = p_shipment_id AND od.docs_url IS NOT NULL
      );
      
    WHEN 'bank_endorsement' THEN
      RETURN EXISTS (
        SELECT 1 FROM public.non_negotiable_docs nnd
        WHERE nnd.shipment_id = p_shipment_id AND nnd.file_url IS NOT NULL
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
      RETURN FALSE;
  END CASE;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in stage_requirements_met for shipment % to stage %: %', 
                 p_shipment_id, p_to_stage, SQLERRM;
    RETURN FALSE;
END;
$$;

-- Add comment explaining the CFR skip logic
COMMENT ON FUNCTION public.stage_requirements_met IS 
'Validates if a shipment can advance to the next stage. 
Includes special logic:
- Seed products require forecast and enlistment verification
- CFR inco-term auto-skips: shipment_details_from_supplier, freight_query, award_shipment
- Merged LC stage: lc_opening now handles both opening and sharing';

-- Migration completed
SELECT 'stage_requirements_met function updated with CFR skip logic' as migration_status;
