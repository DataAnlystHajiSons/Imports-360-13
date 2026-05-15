-- ============================================================================
-- CREATE: Enhanced Documents View for Proper Filtering
-- ============================================================================
-- This view will properly join documents with all related entities

-- First, let's check the actual shipment table structure
SELECT 'Checking shipment table structure:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'shipment' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check document table structure  
SELECT 'Checking document table structure:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'document' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Create a comprehensive documents view that joins with all related entities
CREATE OR REPLACE VIEW public.v_documents_with_entities AS
SELECT 
  d.*,
  s.reference_code as shipment_reference,
  s.status as shipment_status,
  
  -- Supplier information (if available through shipment_products -> product_variety -> supplier)
  COALESCE(sp_supplier.supplier_id, direct_supplier.id) as supplier_id,
  COALESCE(sp_supplier.supplier_name, direct_supplier.name) as supplier_name,
  
  -- Bank information (direct from shipment if column exists)
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'shipment' AND column_name = 'bank_id'
    ) THEN (
      SELECT b.id FROM bank b WHERE b.id = s.bank_id
    )
    ELSE (
      SELECT lc.bank_id FROM letter_of_credit lc WHERE lc.shipment_id = s.id LIMIT 1
    )
  END as bank_id,
  
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'shipment' AND column_name = 'bank_id'
    ) THEN (
      SELECT b.name FROM bank b WHERE b.id = s.bank_id
    )
    ELSE (
      SELECT b.name FROM letter_of_credit lc 
      JOIN bank b ON lc.bank_id = b.id 
      WHERE lc.shipment_id = s.id LIMIT 1
    )
  END as bank_name,
  
  -- Clearing agent information (direct from shipment if column exists)
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'shipment' AND column_name = 'clearing_agent_id'
    ) THEN (
      SELECT ca.id FROM clearing_agent ca WHERE ca.id = s.clearing_agent_id
    )
    ELSE (
      SELECT dtca.clearing_agent_id FROM docs_to_clearing_agent dtca 
      WHERE dtca.shipment_id = s.id LIMIT 1
    )
  END as clearing_agent_id,
  
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'shipment' AND column_name = 'clearing_agent_id'
    ) THEN (
      SELECT ca.name FROM clearing_agent ca WHERE ca.id = s.clearing_agent_id
    )
    ELSE (
      SELECT ca.name FROM docs_to_clearing_agent dtca
      JOIN clearing_agent ca ON dtca.clearing_agent_id = ca.id
      WHERE dtca.shipment_id = s.id LIMIT 1
    )
  END as clearing_agent_name

FROM public.document d
JOIN public.shipment s ON d.shipment_id = s.id

-- Left join to get supplier through shipment_products -> product_variety -> supplier
LEFT JOIN (
  SELECT 
    sp.shipment_id,
    supplier.id as supplier_id,
    supplier.name as supplier_name
  FROM public.shipment_products sp
  JOIN public.product_variety pv ON sp.product_variety_id = pv.id
  JOIN public.supplier supplier ON pv.supplier_id = supplier.id
  GROUP BY sp.shipment_id, supplier.id, supplier.name
) sp_supplier ON s.id = sp_supplier.shipment_id

-- Fallback: check if shipment has direct supplier_id column
LEFT JOIN public.supplier direct_supplier ON (
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'shipment' AND column_name = 'supplier_id'
    ) THEN s.supplier_id = direct_supplier.id
    ELSE FALSE
  END
);

-- Grant permissions on the view
GRANT SELECT ON public.v_documents_with_entities TO authenticated;
GRANT SELECT ON public.v_documents_with_entities TO service_role;
GRANT SELECT ON public.v_documents_with_entities TO anon;

-- Create an improved RPC function that uses the view
CREATE OR REPLACE FUNCTION public.get_documents_by_dimension_fixed(
    p_dimension text,
    p_entity_id uuid
) RETURNS TABLE (
    id uuid,
    shipment_id uuid,
    doc_type text,
    file_url text,
    uploaded_at timestamp with time zone,
    uploaded_by uuid,
    shipment_reference text,
    supplier_id uuid,
    supplier_name text,
    bank_id uuid,
    bank_name text,
    clearing_agent_id uuid,
    clearing_agent_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  CASE p_dimension
    WHEN 'supplier' THEN
      RETURN QUERY
      SELECT 
        v.id, v.shipment_id, v.doc_type, v.file_url, v.uploaded_at, v.uploaded_by,
        v.shipment_reference, v.supplier_id, v.supplier_name, 
        v.bank_id, v.bank_name, v.clearing_agent_id, v.clearing_agent_name
      FROM public.v_documents_with_entities v
      WHERE v.supplier_id = p_entity_id
      ORDER BY v.uploaded_at DESC;
      
    WHEN 'shipment' THEN
      RETURN QUERY
      SELECT 
        v.id, v.shipment_id, v.doc_type, v.file_url, v.uploaded_at, v.uploaded_by,
        v.shipment_reference, v.supplier_id, v.supplier_name, 
        v.bank_id, v.bank_name, v.clearing_agent_id, v.clearing_agent_name
      FROM public.v_documents_with_entities v
      WHERE v.shipment_id = p_entity_id
      ORDER BY v.uploaded_at DESC;
      
    WHEN 'bank' THEN
      RETURN QUERY
      SELECT 
        v.id, v.shipment_id, v.doc_type, v.file_url, v.uploaded_at, v.uploaded_by,
        v.shipment_reference, v.supplier_id, v.supplier_name, 
        v.bank_id, v.bank_name, v.clearing_agent_id, v.clearing_agent_name
      FROM public.v_documents_with_entities v
      WHERE v.bank_id = p_entity_id
      ORDER BY v.uploaded_at DESC;
      
    WHEN 'clearing_agent' THEN
      RETURN QUERY
      SELECT 
        v.id, v.shipment_id, v.doc_type, v.file_url, v.uploaded_at, v.uploaded_by,
        v.shipment_reference, v.supplier_id, v.supplier_name, 
        v.bank_id, v.bank_name, v.clearing_agent_id, v.clearing_agent_name
      FROM public.v_documents_with_entities v
      WHERE v.clearing_agent_id = p_entity_id
      ORDER BY v.uploaded_at DESC;
      
    ELSE
      RAISE EXCEPTION 'Invalid dimension: %', p_dimension;
  END CASE;
END;
$$;

-- Grant permissions on the function
GRANT EXECUTE ON FUNCTION public.get_documents_by_dimension_fixed(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_documents_by_dimension_fixed(text, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_documents_by_dimension_fixed(text, uuid) TO anon;

-- Test the new function
SELECT 'Testing the new function:' as test_info;

DO $$
DECLARE
    test_supplier_id uuid;
    test_shipment_id uuid;
    result_count integer;
BEGIN
    -- Test supplier dimension
    SELECT id INTO test_supplier_id FROM public.supplier LIMIT 1;
    IF test_supplier_id IS NOT NULL THEN
        SELECT COUNT(*) INTO result_count 
        FROM public.get_documents_by_dimension_fixed('supplier', test_supplier_id);
        RAISE NOTICE 'Supplier test: Found % documents for supplier %', result_count, test_supplier_id;
    END IF;
    
    -- Test shipment dimension
    SELECT id INTO test_shipment_id FROM public.shipment LIMIT 1;
    IF test_shipment_id IS NOT NULL THEN
        SELECT COUNT(*) INTO result_count 
        FROM public.get_documents_by_dimension_fixed('shipment', test_shipment_id);
        RAISE NOTICE 'Shipment test: Found % documents for shipment %', result_count, test_shipment_id;
    END IF;
END $$;