-- Migration: 25_add_contract_collection_shipment_types.sql
-- Description: Add 'Contract' and 'Collection' to shipment_type enum and support them in get_next_shipment_reference

-- Step 1: Add 'Contract' and 'Collection' to shipment_type enum
-- Note: ALTER TYPE ... ADD VALUE cannot run inside a transaction block in PostgreSQL.
ALTER TYPE public.shipment_type ADD VALUE IF NOT EXISTS 'Contract';
ALTER TYPE public.shipment_type ADD VALUE IF NOT EXISTS 'Collection';

-- Step 2: Update get_next_shipment_reference function to support new shipment types
CREATE OR REPLACE FUNCTION public.get_next_shipment_reference(p_shipment_type public.shipment_type)
RETURNS TEXT AS $$
DECLARE
    last_ref_code TEXT;
    last_num INT;
    next_num INT;
    prefix TEXT;
    starting_num INT;
BEGIN
    IF p_shipment_type = 'DP' THEN
        prefix := 'D-';
        starting_num := 630;
    ELSIF p_shipment_type = 'LC' THEN
        prefix := 'L-';
        starting_num := 711;
    ELSIF p_shipment_type = 'Contract' THEN
        prefix := 'C-';
        starting_num := 101;
    ELSIF p_shipment_type = 'Collection' THEN
        prefix := 'COL-';
        starting_num := 101;
    ELSE
        -- Fallback for other shipment types
        RETURN p_shipment_type || '-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS');
    END IF;

    SELECT reference_code INTO last_ref_code
    FROM public.shipment
    WHERE type = p_shipment_type AND reference_code ~ (prefix || '[0-9]+$')
    ORDER BY CAST(SUBSTRING(reference_code FROM (LENGTH(prefix) + 1)) AS INTEGER) DESC
    LIMIT 1;

    IF last_ref_code IS NULL THEN
        next_num := starting_num;
    ELSE
        last_num := CAST(SUBSTRING(last_ref_code FROM (LENGTH(prefix) + 1)) AS INTEGER);
        next_num := last_num + 1;
    END IF;

    RETURN prefix || next_num;
END;
$$ LANGUAGE plpgsql;
