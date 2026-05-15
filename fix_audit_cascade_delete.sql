-- Fix: Make audit records CASCADE delete when shipment is deleted
-- When a shipment is deleted, all its audit history will also be deleted

-- ============================================
-- Fix shipment_products_audit
-- ============================================
ALTER TABLE public.shipment_products_audit 
DROP CONSTRAINT IF EXISTS shipment_products_audit_shipment_id_fkey;

ALTER TABLE public.shipment_products_audit 
ADD CONSTRAINT shipment_products_audit_shipment_id_fkey 
FOREIGN KEY (shipment_id) 
REFERENCES public.shipment(id) 
ON DELETE CASCADE;

-- ============================================
-- Verify the fix
-- ============================================
SELECT 
  tc.constraint_name,
  tc.table_name,
  rc.delete_rule,
  CASE 
    WHEN rc.delete_rule = 'CASCADE' THEN '✅ FIXED - Will delete audit records'
    ELSE '❌ Not fixed yet'
  END as status
FROM information_schema.table_constraints tc
JOIN information_schema.referential_constraints rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_name = 'shipment_products_audit_shipment_id_fkey';

-- ============================================
-- Check for other audit tables that might need the same fix
-- ============================================
SELECT 
  tc.table_name,
  tc.constraint_name,
  ccu.table_name AS references_table,
  rc.delete_rule,
  CASE 
    WHEN tc.table_name LIKE '%audit%' AND rc.delete_rule != 'CASCADE' THEN '⚠️  NEEDS FIX'
    WHEN tc.table_name LIKE '%audit%' AND rc.delete_rule = 'CASCADE' THEN '✅ OK'
    ELSE '—'
  END as audit_status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND ccu.table_name = 'shipment'
  AND tc.table_name LIKE '%audit%'
ORDER BY tc.table_name;

-- ============================================
-- Success message
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '✅ Audit table CASCADE delete has been configured!';
  RAISE NOTICE '🗑️  When you delete a shipment, all audit records will be deleted too.';
  RAISE NOTICE '🎯 Try deleting your test shipment now.';
END $$;
