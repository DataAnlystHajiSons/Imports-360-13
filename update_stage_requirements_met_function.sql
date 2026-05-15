
CREATE OR REPLACE FUNCTION public.stage_requirements_met(
  p_shipment_id uuid,
  p_to_stage public.stage
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  shipment_rec record;
  has_seed_commodity BOOLEAN := FALSE;
  seed_commodity_id uuid;
BEGIN
  -- Get the shipment record
  SELECT * INTO shipment_rec
  FROM public.shipment
  WHERE id = p_shipment_id;

  -- Check if shipment has any products from "Seed" commodity
  SELECT c.id INTO seed_commodity_id
  FROM public.commodity c
  WHERE LOWER(c.name) = 'seed'
  LIMIT 1;

  IF seed_commodity_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 
      FROM public.shipment_products sp
      JOIN public.product_variety pv ON sp.product_variety_id = pv.id
      WHERE sp.shipment_id = p_shipment_id 
      AND pv.commodity_id = seed_commodity_id
    ) INTO has_seed_commodity;
  END IF;

  CASE p_to_stage
    WHEN 'enlistment_verification' THEN
      -- If no seed commodity, auto-advance. If has seed commodity, check forecast requirement
      IF NOT has_seed_commodity THEN
        RETURN TRUE; -- No seed commodity, skip forecast stage
      ELSE
        -- Check if seed commodity product is in forecast for current year
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
END;
$$;
