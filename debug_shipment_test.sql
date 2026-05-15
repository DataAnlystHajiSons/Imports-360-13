-- ============================================================================
-- DEBUG SCRIPT: Test Shipment Stage Requirements
-- ============================================================================
-- Replace 'YOUR_SHIPMENT_ID' with your actual shipment UUID

-- Step 1: Check current backend function definition
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'stage_requirements_met';

-- Step 2: Check shipment products and their commodities
SELECT 
    s.id as shipment_id,
    s.reference_code,
    s.current_stage,
    sp.product_variety_id,
    pv.product_name,
    pv.variety_name,
    pv.commodity
FROM public.shipment s
JOIN public.shipment_products sp ON s.id = sp.shipment_id
JOIN public.product_variety pv ON sp.product_variety_id = pv.id
WHERE s.id = 'YOUR_SHIPMENT_ID'::uuid;

-- Step 3: Check if seed products exist in forecast for 2025
SELECT 
    'Seed Products in Forecast' as check_type,
    f.id as forecast_id,
    f.product_variety_id,
    f.date_of_sowing,
    f.enlistment_status,
    pv.product_name,
    pv.variety_name,
    pv.commodity,
    EXTRACT(YEAR FROM f.date_of_sowing) as sowing_year
FROM public.forecast f
JOIN public.product_variety pv ON f.product_variety_id = pv.id
WHERE f.product_variety_id IN (
    SELECT sp.product_variety_id 
    FROM public.shipment_products sp
    JOIN public.product_variety pv2 ON sp.product_variety_id = pv2.id
    WHERE sp.shipment_id = 'YOUR_SHIPMENT_ID'::uuid
    AND pv2.commodity = 'Seed'
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

-- Step 5: Check if commodity field exists and what values it has
SELECT DISTINCT commodity, COUNT(*) as count
FROM public.product_variety
WHERE commodity IS NOT NULL
GROUP BY commodity
ORDER BY commodity;

-- Step 6: Test advance_stage function call (DO NOT RUN - Just for reference)
-- SELECT public.advance_stage('YOUR_SHIPMENT_ID'::uuid, 'enlistment_verification'::public.stage, '{"test": true}'::jsonb);

-- Step 7: Check current shipment stage and any related checklist data
SELECT 
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    s.created_at
FROM public.shipment s
WHERE s.id = 'YOUR_SHIPMENT_ID'::uuid;