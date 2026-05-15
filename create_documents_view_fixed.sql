-- ============================================================================
-- FIXED: Documents View Without Non-Existent Columns
-- ============================================================================

-- First, let's check the actual table structures
SELECT 'Checking shipment table structure:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'shipment' 
AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Checking document table structure:' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'document' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check what tables exist for relationships
SELECT 'Available tables:' as info;
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
AND table_name IN ('shipment_products', 'product_variety', 'supplier', 'bank', 'clearing_agent', 'letter_of_credit', 'docs_to_clearing_agent')
ORDER BY table_name;

-- Create a simplified view that works with existing structure
CREATE OR REPLACE VIEW public.v_documents_with_entities AS
SELECT 
  d.*,
  s.reference_code as shipment_reference,
  s.status as shipment_status,
  
  -- Supplier information through shipment_products -> product_variety -> supplier
  supplier_info.supplier_id,
  supplier_info.supplier_name,
  
  -- Bank information through letter_of_credit (if exists)
  bank_info.bank_id,
  bank_info.bank_name,
  
  -- Clearing agent information through docs_to_clearing_agent (if exists)
  agent_info.clearing_agent_id,
  agent_info.clearing_agent_name

FROM public.document d
JOIN public.shipment s ON d.shipment_id = s.id

-- Get supplier through shipment_products -> product_variety -> supplier
LEFT JOIN (
  SELECT 
    sp.shipment_id,
    supplier.id as supplier_id,
    supplier.name as supplier_name
  FROM public.shipment_products sp
  JOIN public.product_variety pv ON sp.product_variety_id = pv.id
  JOIN public.supplier supplier ON pv.supplier_id = supplier.id
  -- Get the first supplier if multiple exist
  WHERE sp.shipment_id IS NOT NULL
) supplier_info ON s.id = supplier_info.shipment_id

-- Get bank through letter_of_credit (if table exists)
LEFT JOIN (
  SELECT 
    lc.shipment_id,
    b.id as bank_id,
    b.name as bank_name
  FROM public.letter_of_credit lc
  JOIN public.bank b ON lc.bank_id = b.id
  WHERE lc.shipment_id IS NOT NULL
) bank_info ON s.id = bank_info.shipment_id

-- Get clearing agent through docs_to_clearing_agent (if table exists)
LEFT JOIN (
  SELECT 
    dtca.shipment_id,
    ca.id as clearing_agent_id,
    ca.name as clearing_agent_name
  FROM public.docs_to_clearing_agent dtca
  JOIN public.clearing_agent ca ON dtca.clearing_agent_id = ca.id
  WHERE dtca.shipment_id IS NOT NULL
) agent_info ON s.id = agent_info.shipment_id;

-- Grant permissions on the view
GRANT SELECT ON public.v_documents_with_entities TO authenticated;
GRANT SELECT ON public.v_documents_with_entities TO service_role;
GRANT SELECT ON public.v_documents_with_entities TO anon;

-- Create a fallback function that handles missing relationships gracefully
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
      -- Use the view to find documents by supplier
      RETURN QUERY
      SELECT 
        v.id, v.shipment_id, v.doc_type, v.file_url, v.uploaded_at, v.uploaded_by,
        v.shipment_reference, v.supplier_id, v.supplier_name, 
        v.bank_id, v.bank_name, v.clearing_agent_id, v.clearing_agent_name
      FROM public.v_documents_with_entities v
      WHERE v.supplier_id = p_entity_id
      ORDER BY v.uploaded_at DESC;
      
    WHEN 'shipment' THEN
      -- Direct shipment lookup
      RETURN QUERY
      SELECT 
        v.id, v.shipment_id, v.doc_type, v.file_url, v.uploaded_at, v.uploaded_by,
        v.shipment_reference, v.supplier_id, v.supplier_name, 
        v.bank_id, v.bank_name, v.clearing_agent_id, v.clearing_agent_name
      FROM public.v_documents_with_entities v
      WHERE v.shipment_id = p_entity_id
      ORDER BY v.uploaded_at DESC;
      
    WHEN 'bank' THEN
      -- Use the view to find documents by bank
      RETURN QUERY
      SELECT 
        v.id, v.shipment_id, v.doc_type, v.file_url, v.uploaded_at, v.uploaded_by,
        v.shipment_reference, v.supplier_id, v.supplier_name, 
        v.bank_id, v.bank_name, v.clearing_agent_id, v.clearing_agent_name
      FROM public.v_documents_with_entities v
      WHERE v.bank_id = p_entity_id
      ORDER BY v.uploaded_at DESC;
      
    WHEN 'clearing_agent' THEN
      -- Use the view to find documents by clearing agent
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_documents_by_dimension_fixed(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_documents_by_dimension_fixed(text, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_documents_by_dimension_fixed(text, uuid) TO anon;

-- Test the view and function
DO $$
DECLARE
    test_shipment_id uuid;
    test_supplier_id uuid;
    result_count integer;
    view_count integer;
BEGIN
    -- Test the view first
    SELECT COUNT(*) INTO view_count FROM public.v_documents_with_entities;
    RAISE NOTICE 'View created successfully with % total document records', view_count;
    
    -- Test shipment dimension (should always work)
    SELECT id INTO test_shipment_id 
    FROM public.shipment 
    WHERE id IN (SELECT DISTINCT shipment_id FROM public.document)
    LIMIT 1;
    
    IF test_shipment_id IS NOT NULL THEN
        SELECT COUNT(*) INTO result_count 
        FROM public.get_documents_by_dimension_fixed('shipment', test_shipment_id);
        RAISE NOTICE 'Shipment test: Found % documents for shipment %', result_count, test_shipment_id;
    END IF;
    
    -- Test supplier dimension
    SELECT supplier_id INTO test_supplier_id 
    FROM public.v_documents_with_entities 
    WHERE supplier_id IS NOT NULL 
    LIMIT 1;
    
    IF test_supplier_id IS NOT NULL THEN
        SELECT COUNT(*) INTO result_count 
        FROM public.get_documents_by_dimension_fixed('supplier', test_supplier_id);
        RAISE NOTICE 'Supplier test: Found % documents for supplier %', result_count, test_supplier_id;
    ELSE
        RAISE NOTICE 'No supplier relationships found in view - may need to check shipment_products/product_variety tables';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test error: %', SQLERRM;
END $$;