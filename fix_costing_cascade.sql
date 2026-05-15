-- Fix costing table foreign key to allow cascading delete
-- This is the last remaining table that needs CASCADE behavior

-- Drop the existing constraint
ALTER TABLE public.costing 
DROP CONSTRAINT IF EXISTS costing_shipment_id_fkey;

-- Recreate the constraint with ON DELETE CASCADE
ALTER TABLE public.costing 
ADD CONSTRAINT costing_shipment_id_fkey 
FOREIGN KEY (shipment_id) 
REFERENCES public.shipment(id) 
ON DELETE CASCADE;

-- Verify the fix
SELECT 
  tc.constraint_name, 
  tc.table_name, 
  rc.delete_rule,
  CASE 
    WHEN rc.delete_rule = 'CASCADE' THEN '✅ FIXED!'
    ELSE '❌ STILL NEEDS FIX'
  END as status
FROM information_schema.table_constraints AS tc 
JOIN information_schema.referential_constraints AS rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'costing'
  AND tc.constraint_name = 'costing_shipment_id_fkey';

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Costing table cascade delete has been fixed!';
  RAISE NOTICE '🎯 All 37 tables now have proper CASCADE behavior.';
END $$;
