-- ============================================================================
-- DEBUG SCRIPT v2: Test Shipment Stage Requirements (Fixed for commodity_id)
-- ============================================================================
-- Replace 'YOUR_SHIPMENT_ID' with your actual shipment UUID

-- Step 1: Check shipment products and their commodities (CORRECTED)
SELECT 
    s.id as shipment_id,
    s.reference_code,
    s.current_stage,
    sp.product_variety_id,
    pv.product_name,
    pv.variety_name,
    pv.commodity_id,
    c.name as commodity_name
FROM public.shipment s
JOIN public.shipment_products sp ON s.id = sp.shipment_id
JOIN public.product_variety pv ON sp.product_variety_id = pv.id
JOIN public.commodity c ON pv.commodity_id = c.id
WHERE s.id = 'YOUR_SHIPMENT_ID'::uuid;

-- Step 2: Check available commodities in system
SELECT DISTINCT c.id, c.name, COUNT(*) as product_count
FROM public.commodity c
JOIN public.product_variety pv ON c.id = pv.commodity_id
GROUP BY c.id, c.name
ORDER BY c.name;

-- Step 3: Check if seed products exist in forecast for 2025 (CORRECTED)
SELECT 
    'Seed Products in Forecast' as check_type,
    f.id as forecast_id,
    f.product_variety_id,
    f.date_of_sowing,
    f.enlistment_status,
    pv.product_name,
    pv.variety_name,
    c.name as commodity_name,
    EXTRACT(YEAR FROM f.date_of_sowing) as sowing_year
FROM public.forecast f
JOIN public.product_variety pv ON f.product_variety_id = pv.id
JOIN public.commodity c ON pv.commodity_id = c.id
WHERE f.product_variety_id IN (
    SELECT sp.product_variety_id 
    FROM public.shipment_products sp
    JOIN public.product_variety pv2 ON sp.product_variety_id = pv2.id
    JOIN public.commodity c2 ON pv2.commodity_id = c2.id
    WHERE sp.shipment_id = 'YOUR_SHIPMENT_ID'::uuid
    AND (
        UPPER(c2.name) = 'SEED' OR 
        UPPER(c2.name) = 'SEEDS' OR
        c2.name ILIKE '%seed%'
    )
)
AND EXTRACT(YEAR FROM f.date_of_sowing) = 2025;

-- Step 4: Test stage requirements function directly
SELECT 
    'Stage Requirements Test' as test_type,
    'enlistment_verification' as target_stage,
    public.stage_requirements_met('YOUR_SHIPMENT_ID'::uuid, 'enlistment_verification'::public.stage) as requirements_met;

SELECT 
    'Stage Requirements Test' as test_type,
    'availability_confirmation' as target_stage,
    public.stage_requirements_met('YOUR_SHIPMENT_ID'::uuid, 'availability_confirmation'::public.stage) as requirements_met;

-- Step 5: Check current shipment details
SELECT 
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    s.created_at
FROM public.shipment s
WHERE s.id = 'YOUR_SHIPMENT_ID'::uuid;

-- Step 6: Manual test of seed product detection logic
SELECT 
    sp.product_variety_id,
    pv.product_name,
    pv.variety_name,
    c.name as commodity_name,
    CASE 
        WHEN UPPER(c.name) = 'SEED' OR UPPER(c.name) = 'SEEDS' OR c.name ILIKE '%seed%' 
        THEN 'IS_SEED_PRODUCT' 
        ELSE 'NOT_SEED_PRODUCT' 
    END as seed_classification
FROM public.shipment_products sp
JOIN public.product_variety pv ON sp.product_variety_id = pv.id
JOIN public.commodity c ON pv.commodity_id = c.id
WHERE sp.shipment_id = 'YOUR_SHIPMENT_ID'::uuid;