-- Fix RLS issues for the public quote submission form
-- This securely allows the frontend to fetch only the details it needs, and allows inserting a quote.

-- 1. Create a secure function to fetch the query details (bypasses RLS safely for a specific UUID)
CREATE OR REPLACE FUNCTION get_freight_quote_details(p_freight_query_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_freight_query RECORD;
    v_shipment RECORD;
    v_products JSONB;
    v_existing_quote RECORD;
    v_result JSONB;
BEGIN
    -- 1. Check existing quote
    SELECT id, name_of_your_company, received_at 
    INTO v_existing_quote
    FROM freight_quote_response 
    WHERE freight_query_id = p_freight_query_id 
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'existing_quote', jsonb_build_object(
                'name_of_your_company', v_existing_quote.name_of_your_company,
                'received_at', v_existing_quote.received_at
            )
        );
    END IF;

    -- 2. Get freight query
    SELECT * INTO v_freight_query
    FROM freight_query
    WHERE id = p_freight_query_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Freight query not found');
    END IF;

    -- 3. Get shipment
    SELECT id, reference_code INTO v_shipment
    FROM shipment
    WHERE id = v_freight_query.shipment_id;

    -- 4. Get products
    SELECT jsonb_agg(
        jsonb_build_object(
            'quantity', sp.quantity,
            'unit', sp.unit,
            'product_name', pv.product_name,
            'variety_name', pv.variety_name,
            'commodity_name', c.name
        )
    ) INTO v_products
    FROM shipment_products sp
    LEFT JOIN product_variety pv ON sp.product_variety_id = pv.id
    LEFT JOIN commodity c ON pv.commodity_id = c.id
    WHERE sp.shipment_id = v_freight_query.shipment_id;

    -- 5. Build result
    v_result := jsonb_build_object(
        'freight_query', row_to_json(v_freight_query)::jsonb,
        'shipment', row_to_json(v_shipment)::jsonb,
        'products', COALESCE(v_products, '[]'::jsonb)
    );

    RETURN v_result;
END;
$$;

-- 2. Allow anonymous users to submit (INSERT) quotes
DROP POLICY IF EXISTS "Allow anon insert on freight_quote_response" ON freight_quote_response;
CREATE POLICY "Allow anon insert on freight_quote_response" 
ON freight_quote_response FOR INSERT TO anon 
WITH CHECK (true);
