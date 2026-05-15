-- Fix: Audit Trigger Blocking Shipment Deletion
-- The shipment_products_audit table has a foreign key to shipment that prevents cascading deletes

-- ============================================
-- OPTION 1: Make audit foreign key SET NULL (Recommended)
-- ============================================
-- This allows audit records to remain even after shipment is deleted

ALTER TABLE public.shipment_products_audit 
DROP CONSTRAINT IF EXISTS shipment_products_audit_shipment_id_fkey;

ALTER TABLE public.shipment_products_audit 
ADD CONSTRAINT shipment_products_audit_shipment_id_fkey 
FOREIGN KEY (shipment_id) 
REFERENCES public.shipment(id) 
ON DELETE SET NULL;

-- Make shipment_id nullable if it isn't already
ALTER TABLE public.shipment_products_audit 
ALTER COLUMN shipment_id DROP NOT NULL;

-- Verify the fix
SELECT 
  constraint_name,
  table_name,
  (SELECT delete_rule 
   FROM information_schema.referential_constraints rc 
   WHERE rc.constraint_name = tc.constraint_name) as delete_rule
FROM information_schema.table_constraints tc
WHERE constraint_name = 'shipment_products_audit_shipment_id_fkey';

-- Expected: delete_rule = 'SET NULL'

-- ============================================
-- Test the deletion now
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '✅ Audit table foreign key fixed!';
  RAISE NOTICE '📌 Audit records will be preserved with NULL shipment_id when shipments are deleted.';
  RAISE NOTICE '🎯 Try deleting your test shipment again now.';
END $$;
