-- Fix supplier_payments foreign key to allow cascading delete
-- This resolves the error: "Unable to delete row as it is currently referenced by a foreign key constraint"

-- Drop the existing constraint
ALTER TABLE public.supplier_payments 
DROP CONSTRAINT IF EXISTS supplier_payments_shipment_id_fkey;

-- Recreate the constraint with ON DELETE CASCADE
ALTER TABLE public.supplier_payments 
ADD CONSTRAINT supplier_payments_shipment_id_fkey 
FOREIGN KEY (shipment_id) 
REFERENCES public.shipment(id) 
ON DELETE CASCADE;

-- Verify the constraint was created
SELECT 
  tc.constraint_name, 
  tc.table_name, 
  kcu.column_name, 
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name,
  rc.delete_rule
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_name = 'supplier_payments'
  AND kcu.column_name = 'shipment_id';
