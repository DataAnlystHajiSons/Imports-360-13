-- Complete Cascading Deletes Fix
-- This script adds ON DELETE CASCADE to all tables that reference shipment but were missing from the original cascading deletes scripts
-- Run this in Supabase SQL Editor to fix the foreign key constraint issues

-- ============================================
-- 1. supplier_payments (MAIN FIX FOR CURRENT ERROR)
-- ============================================
ALTER TABLE public.supplier_payments 
DROP CONSTRAINT IF EXISTS supplier_payments_shipment_id_fkey;

ALTER TABLE public.supplier_payments 
ADD CONSTRAINT supplier_payments_shipment_id_fkey 
FOREIGN KEY (shipment_id) 
REFERENCES public.shipment(id) 
ON DELETE CASCADE;

-- ============================================
-- 2. shipment_stage_targets (Stage Target Dates feature)
-- ============================================
ALTER TABLE public.shipment_stage_targets
DROP CONSTRAINT IF EXISTS shipment_stage_targets_shipment_id_fkey;

ALTER TABLE public.shipment_stage_targets
ADD CONSTRAINT shipment_stage_targets_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- 3. bank_communication (Communication tracking)
-- ============================================
ALTER TABLE public.bank_communication
DROP CONSTRAINT IF EXISTS bank_communication_shipment_id_fkey;

ALTER TABLE public.bank_communication
ADD CONSTRAINT bank_communication_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- 4. clearing_agent_communication (Communication tracking)
-- ============================================
ALTER TABLE public.clearing_agent_communication
DROP CONSTRAINT IF EXISTS clearing_agent_communication_shipment_id_fkey;

ALTER TABLE public.clearing_agent_communication
ADD CONSTRAINT clearing_agent_communication_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- 5. warehouse_communication (Communication tracking)
-- ============================================
ALTER TABLE public.warehouse_communication
DROP CONSTRAINT IF EXISTS warehouse_communication_shipment_id_fkey;

ALTER TABLE public.warehouse_communication
ADD CONSTRAINT warehouse_communication_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- 6. bility (if not already updated)
-- ============================================
ALTER TABLE public.bility
DROP CONSTRAINT IF EXISTS bility_shipment_id_fkey;

ALTER TABLE public.bility
ADD CONSTRAINT bility_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- 7. clearing_agent_bill (if not already updated)
-- ============================================
ALTER TABLE public.clearing_agent_bill
DROP CONSTRAINT IF EXISTS clearing_agent_bill_shipment_id_fkey;

ALTER TABLE public.clearing_agent_bill
ADD CONSTRAINT clearing_agent_bill_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- 8. freight_forwarder_bill (if not already updated)
-- ============================================
ALTER TABLE public.freight_forwarder_bill
DROP CONSTRAINT IF EXISTS freight_forwarder_bill_shipment_id_fkey;

ALTER TABLE public.freight_forwarder_bill
ADD CONSTRAINT freight_forwarder_bill_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- 9. fbr_duty (if not already updated)
-- ============================================
ALTER TABLE public.fbr_duty
DROP CONSTRAINT IF EXISTS fbr_duty_shipment_id_fkey;

ALTER TABLE public.fbr_duty
ADD CONSTRAINT fbr_duty_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- 10. insurance (if not already updated)
-- ============================================
ALTER TABLE public.insurance
DROP CONSTRAINT IF EXISTS insurance_shipment_id_fkey;

ALTER TABLE public.insurance
ADD CONSTRAINT insurance_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- 11. bank_charges (if not already updated)
-- ============================================
ALTER TABLE public.bank_charges
DROP CONSTRAINT IF EXISTS bank_charges_shipment_id_fkey;

ALTER TABLE public.bank_charges
ADD CONSTRAINT bank_charges_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- 12. shipment_products (if not already updated)
-- ============================================
ALTER TABLE public.shipment_products
DROP CONSTRAINT IF EXISTS shipment_products_shipment_id_fkey;

ALTER TABLE public.shipment_products
ADD CONSTRAINT shipment_products_shipment_id_fkey
FOREIGN KEY (shipment_id)
REFERENCES public.shipment(id)
ON DELETE CASCADE;

-- ============================================
-- VERIFICATION QUERY
-- ============================================
-- Run this to verify all constraints are properly set with CASCADE
SELECT 
  tc.table_name, 
  tc.constraint_name, 
  kcu.column_name,
  rc.delete_rule,
  CASE 
    WHEN rc.delete_rule = 'CASCADE' THEN '✅ OK'
    ELSE '❌ NEEDS FIX'
  END as status
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
  AND ccu.table_name = 'shipment'
  AND ccu.column_name = 'id'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '✅ All cascading delete constraints have been updated!';
  RAISE NOTICE '📌 You can now delete test shipments without foreign key errors.';
  RAISE NOTICE '⚠️  WARNING: Deleting a shipment will now permanently delete ALL related data.';
END $$;
