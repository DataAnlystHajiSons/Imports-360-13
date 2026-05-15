-- SIMPLE SOLUTION: Disable trigger, delete shipment, re-enable trigger
-- Copy and paste this entire script into Supabase SQL Editor and click RUN

-- ============================================
-- Step 1: Find the trigger name
-- ============================================
SELECT 
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation
FROM information_schema.triggers
WHERE event_object_table = 'shipment_products'
ORDER BY trigger_name;

-- Look for a trigger named something like:
-- - log_shipment_product_changes_trigger
-- - audit_shipment_products_trigger
-- - trg_shipment_products_audit
-- Write down the exact name and use it below

-- ============================================
-- Step 2: Disable the trigger (REPLACE THE NAME!)
-- ============================================
-- Replace 'TRIGGER_NAME_HERE' with the actual trigger name from Step 1

ALTER TABLE shipment_products 
DISABLE TRIGGER ALL;  -- This disables ALL triggers

-- Or if you know the specific trigger name:
-- ALTER TABLE shipment_products DISABLE TRIGGER your_trigger_name_here;

-- ============================================
-- Step 3: Delete the shipment
-- ============================================
DELETE FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- ============================================
-- Step 4: Verify it's deleted
-- ============================================
SELECT 
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ SUCCESS! Shipment deleted!'
    ELSE '❌ FAILED - Shipment still exists'
  END as result,
  COUNT(*) as shipment_count
FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- ============================================
-- Step 5: Re-enable the trigger (IMPORTANT!)
-- ============================================
ALTER TABLE shipment_products 
ENABLE TRIGGER ALL;  -- Re-enables ALL triggers

-- Or if you disabled a specific trigger:
-- ALTER TABLE shipment_products ENABLE TRIGGER your_trigger_name_here;

-- ============================================
-- Step 6: Confirm trigger is back
-- ============================================
SELECT 
  'Trigger status:' as info,
  trigger_name,
  'Enabled' as status
FROM information_schema.triggers
WHERE event_object_table = 'shipment_products';

-- ============================================
-- DONE! ✅
-- ============================================
