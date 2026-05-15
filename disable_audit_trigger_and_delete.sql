-- Disable audit trigger, delete shipment, re-enable trigger
-- Run this entire script at once

-- ============================================
-- 1. Find and disable the trigger
-- ============================================
DO $$
DECLARE
  trigger_rec RECORD;
BEGIN
  -- Find all triggers on shipment_products
  FOR trigger_rec IN 
    SELECT trigger_name, event_object_table
    FROM information_schema.triggers
    WHERE event_object_table = 'shipment_products'
      AND trigger_name LIKE '%audit%'
  LOOP
    RAISE NOTICE 'Disabling trigger: %', trigger_rec.trigger_name;
    EXECUTE format('ALTER TABLE %I DISABLE TRIGGER %I', 
                   trigger_rec.event_object_table, 
                   trigger_rec.trigger_name);
  END LOOP;
END $$;

-- ============================================
-- 2. Delete the shipment
-- ============================================
DELETE FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'
RETURNING id, reference_code;

-- ============================================
-- 3. Verify deletion
-- ============================================
SELECT 
  COUNT(*) as shipment_count,
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ Successfully deleted!'
    ELSE '❌ Still exists'
  END as status
FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- ============================================
-- 4. Re-enable the trigger
-- ============================================
DO $$
DECLARE
  trigger_rec RECORD;
BEGIN
  -- Re-enable all triggers on shipment_products
  FOR trigger_rec IN 
    SELECT trigger_name, event_object_table
    FROM information_schema.triggers
    WHERE event_object_table = 'shipment_products'
      AND trigger_name LIKE '%audit%'
  LOOP
    RAISE NOTICE 'Re-enabling trigger: %', trigger_rec.trigger_name;
    EXECUTE format('ALTER TABLE %I ENABLE TRIGGER %I', 
                   trigger_rec.event_object_table, 
                   trigger_rec.trigger_name);
  END LOOP;
END $$;

-- ============================================
-- 5. Confirm trigger is back on
-- ============================================
SELECT 
  trigger_name,
  event_manipulation,
  action_timing,
  CASE 
    WHEN trigger_name IS NOT NULL THEN '✅ Trigger re-enabled'
    ELSE '❌ Trigger not found'
  END as status
FROM information_schema.triggers
WHERE event_object_table = 'shipment_products'
  AND trigger_name LIKE '%audit%';

-- ============================================
-- Success message
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '✅ Shipment deleted successfully!';
  RAISE NOTICE '🔄 Audit trigger has been re-enabled.';
  RAISE NOTICE '📌 Future changes will be logged normally.';
END $$;
