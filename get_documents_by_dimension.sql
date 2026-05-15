CREATE OR REPLACE FUNCTION get_documents_by_dimension(
  p_dimension TEXT,
  p_entity_id UUID
)
RETURNS SETOF document AS $$
BEGIN
  IF p_dimension = 'supplier' THEN
    RETURN QUERY
    SELECT d.*
    FROM document d
    JOIN shipment s ON d.shipment_id = s.id
    JOIN shipment_products sp ON s.id = sp.shipment_id
    JOIN product_variety pv ON sp.product_variety_id = pv.id
    WHERE pv.supplier_id = p_entity_id;
  ELSIF p_dimension = 'shipment' THEN
    RETURN QUERY
    SELECT d.*
    FROM document d
    WHERE d.shipment_id = p_entity_id;
  ELSIF p_dimension = 'bank' THEN
    RETURN QUERY
    SELECT d.*
    FROM document d
    JOIN shipment s ON d.shipment_id = s.id
    JOIN letter_of_credit lc ON s.id = lc.shipment_id
    WHERE lc.bank_id = p_entity_id;
  ELSIF p_dimension = 'clearing_agent' THEN
    RETURN QUERY
    SELECT d.*
    FROM document d
    JOIN shipment s ON d.shipment_id = s.id
    JOIN docs_to_clearing_agent dtca ON s.id = dtca.shipment_id
    WHERE dtca.clearing_agent_id = p_entity_id;
  END IF;
END;
$$ LANGUAGE plpgsql;