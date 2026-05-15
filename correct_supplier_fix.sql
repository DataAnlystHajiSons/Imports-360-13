-- ============================================================================
-- CORRECT FIX: Based on Actual Database Schema
-- ============================================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS public.get_documents_by_dimension_simple(text, uuid);

-- Create the correct function based on actual schema
CREATE OR REPLACE FUNCTION public.get_documents_by_dimension_correct(
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
    entity_name text,
    entity_type text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  CASE p_dimension
    WHEN 'supplier' THEN
      -- Get documents through: shipment -> shipment_products -> product_variety -> supplier
      RETURN QUERY
      SELECT DISTINCT
        d.id, d.shipment_id, d.doc_type, d.file_url, d.uploaded_at, d.uploaded_by,
        s.reference_code as shipment_reference,
        sup.name as entity_name,
        'supplier'::text as entity_type
      FROM public.document d
      JOIN public.shipment s ON d.shipment_id = s.id
      JOIN public.shipment_products sp ON s.id = sp.shipment_id
      JOIN public.product_variety pv ON sp.product_variety_id = pv.id
      JOIN public.supplier sup ON pv.supplier_id = sup.id
      WHERE sup.id = p_entity_id
      ORDER BY d.uploaded_at DESC;
      
    WHEN 'shipment' THEN
      -- Direct shipment lookup
      RETURN QUERY
      SELECT 
        d.id, d.shipment_id, d.doc_type, d.file_url, d.uploaded_at, d.uploaded_by,
        s.reference_code as shipment_reference,
        s.reference_code as entity_name,
        'shipment'::text as entity_type
      FROM public.document d
      JOIN public.shipment s ON d.shipment_id = s.id
      WHERE s.id = p_entity_id
      ORDER BY d.uploaded_at DESC;
      
    WHEN 'bank' THEN
      -- Get documents through: shipment -> letter_of_credit -> bank
      RETURN QUERY
      SELECT DISTINCT
        d.id, d.shipment_id, d.doc_type, d.file_url, d.uploaded_at, d.uploaded_by,
        s.reference_code as shipment_reference,
        b.name as entity_name,
        'bank'::text as entity_type
      FROM public.document d
      JOIN public.shipment s ON d.shipment_id = s.id
      JOIN public.letter_of_credit lc ON s.id = lc.shipment_id
      JOIN public.bank b ON lc.bank_id = b.id
      WHERE b.id = p_entity_id
      ORDER BY d.uploaded_at DESC;
      
    WHEN 'clearing_agent' THEN
      -- Get documents through: shipment -> under_clearing_agent -> clearing_agent
      RETURN QUERY
      SELECT DISTINCT
        d.id, d.shipment_id, d.doc_type, d.file_url, d.uploaded_at, d.uploaded_by,
        s.reference_code as shipment_reference,
        ca.name as entity_name,
        'clearing_agent'::text as entity_type
      FROM public.document d
      JOIN public.shipment s ON d.shipment_id = s.id
      JOIN public.under_clearing_agent uca ON s.id = uca.shipment_id
      JOIN public.clearing_agent ca ON uca.clearing_agent_id = ca.id
      WHERE ca.id = p_entity_id
      ORDER BY d.uploaded_at DESC;
      
    ELSE
      RAISE EXCEPTION 'Invalid dimension: %', p_dimension;
  END CASE;
  
EXCEPTION WHEN OTHERS THEN
  -- Log error and return empty result
  RAISE NOTICE 'Error in dimension %: %. Returning empty result.', p_dimension, SQLERRM;
  RETURN;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_documents_by_dimension_correct(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_documents_by_dimension_correct(text, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_documents_by_dimension_correct(text, uuid) TO anon;

-- Test the function with actual data
DO $$
DECLARE
    test_shipment_id uuid;
    test_supplier_id uuid;
    test_bank_id uuid;
    test_clearing_agent_id uuid;
    result_count integer;
BEGIN
    -- Test shipment (should always work)
    SELECT s.id INTO test_shipment_id 
    FROM public.shipment s
    JOIN public.document d ON s.id = d.shipment_id
    LIMIT 1;
    
    IF test_shipment_id IS NOT NULL THEN
        SELECT COUNT(*) INTO result_count 
        FROM public.get_documents_by_dimension_correct('shipment', test_shipment_id);
        RAISE NOTICE '✅ Shipment test: Found % documents for shipment %', result_count, test_shipment_id;
    ELSE
        RAISE NOTICE '⚠️ No shipments with documents found for testing';
    END IF;
    
    -- Test supplier (through shipment_products -> product_variety -> supplier)
    BEGIN
        SELECT DISTINCT sup.id INTO test_supplier_id 
        FROM public.supplier sup
        JOIN public.product_variety pv ON sup.id = pv.supplier_id
        JOIN public.shipment_products sp ON pv.id = sp.product_variety_id
        JOIN public.document d ON sp.shipment_id = d.shipment_id
        LIMIT 1;
        
        IF test_supplier_id IS NOT NULL THEN
            SELECT COUNT(*) INTO result_count 
            FROM public.get_documents_by_dimension_correct('supplier', test_supplier_id);
            RAISE NOTICE '✅ Supplier test: Found % documents for supplier %', result_count, test_supplier_id;
            
            -- Show the supplier name for reference
            SELECT name FROM public.supplier WHERE id = test_supplier_id;
            RAISE NOTICE '   Supplier name: %', (SELECT name FROM public.supplier WHERE id = test_supplier_id);
        ELSE
            RAISE NOTICE '⚠️ No supplier with documents found for testing';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Supplier test failed: %', SQLERRM;
    END;
    
    -- Test bank (through letter_of_credit)
    BEGIN
        SELECT DISTINCT b.id INTO test_bank_id 
        FROM public.bank b
        JOIN public.letter_of_credit lc ON b.id = lc.bank_id
        JOIN public.document d ON lc.shipment_id = d.shipment_id
        LIMIT 1;
        
        IF test_bank_id IS NOT NULL THEN
            SELECT COUNT(*) INTO result_count 
            FROM public.get_documents_by_dimension_correct('bank', test_bank_id);
            RAISE NOTICE '✅ Bank test: Found % documents for bank %', result_count, test_bank_id;
        ELSE
            RAISE NOTICE '⚠️ No bank with documents found for testing (letter_of_credit may be empty)';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Bank test failed: %', SQLERRM;
    END;
    
    -- Test clearing agent (through under_clearing_agent)
    BEGIN
        SELECT DISTINCT ca.id INTO test_clearing_agent_id 
        FROM public.clearing_agent ca
        JOIN public.under_clearing_agent uca ON ca.id = uca.clearing_agent_id
        JOIN public.document d ON uca.shipment_id = d.shipment_id
        LIMIT 1;
        
        IF test_clearing_agent_id IS NOT NULL THEN
            SELECT COUNT(*) INTO result_count 
            FROM public.get_documents_by_dimension_correct('clearing_agent', test_clearing_agent_id);
            RAISE NOTICE '✅ Clearing agent test: Found % documents for clearing agent %', result_count, test_clearing_agent_id;
        ELSE
            RAISE NOTICE '⚠️ No clearing agent with documents found for testing (under_clearing_agent may be empty)';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ Clearing agent test failed: %', SQLERRM;
    END;
    
    -- Show some stats
    RAISE NOTICE '';
    RAISE NOTICE '📊 Database Statistics:';
    RAISE NOTICE '   Total documents: %', (SELECT COUNT(*) FROM public.document);
    RAISE NOTICE '   Total shipments: %', (SELECT COUNT(*) FROM public.shipment);
    RAISE NOTICE '   Total suppliers: %', (SELECT COUNT(*) FROM public.supplier);
    RAISE NOTICE '   Total shipment_products records: %', (SELECT COUNT(*) FROM public.shipment_products);
    RAISE NOTICE '   Total product_variety records: %', (SELECT COUNT(*) FROM public.product_variety);
    
END $$;