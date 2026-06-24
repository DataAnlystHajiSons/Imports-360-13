-- 13_fix_revision_rls_policy.sql
-- Fix the RLS policy and RPC function for negotiated quote revisions

-- 1. Fix the RLS Policy to allow relocking (setting is_unlocked = false)
DROP POLICY IF EXISTS "Allow anon update on unlocked quotes" ON public.freight_quote_response;

CREATE POLICY "Allow anon update on unlocked quotes"
ON public.freight_quote_response 
FOR UPDATE TO anon
USING (is_unlocked = true)
WITH CHECK (true); -- Allows the updated row to have is_unlocked = false (relocked)

-- 1b. Add SELECT policy to allow anonymous clients to see quotes (PostgREST UPDATE requires SELECT visibility)
DROP POLICY IF EXISTS "Allow anon select on freight_quote_response" ON public.freight_quote_response;

CREATE POLICY "Allow anon select on freight_quote_response"
ON public.freight_quote_response
FOR SELECT TO anon
USING (true);

-- 2. Make the RPC more robust by checking v_existing_quote.id IS NOT NULL instead of FOUND
CREATE OR REPLACE FUNCTION public.get_freight_quote_details(p_freight_query_id UUID)
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
    SELECT *
    INTO v_existing_quote
    FROM freight_quote_response
    WHERE freight_query_id = p_freight_query_id;

    -- 2. Fetch query details
    SELECT *
    INTO v_freight_query
    FROM freight_query
    WHERE id = p_freight_query_id;

    IF v_freight_query.id IS NULL THEN
        RETURN NULL;
    END IF;

    -- 3. Fetch shipment details
    SELECT *
    INTO v_shipment
    FROM shipment
    WHERE id = v_freight_query.shipment_id;

    -- 4. Fetch products
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'product_variety_id', sp.product_variety_id,
                'quantity', sp.quantity,
                'rate', sp.rate,
                'unit', sp.unit,
                'variety_name', pv.variety_name,
                'commodity_name', c.name
            )
        ), '[]'::jsonb
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

    -- If it IS unlocked, pass the previous quote data so we can pre-fill
    IF v_existing_quote.id IS NOT NULL AND COALESCE(v_existing_quote.is_unlocked, false) = true THEN
         v_result := jsonb_set(v_result, '{unlocked_quote}', row_to_json(v_existing_quote)::jsonb);
    END IF;

    RETURN v_result;
END;
$$;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
