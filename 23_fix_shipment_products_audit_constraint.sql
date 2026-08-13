-- 23_fix_shipment_products_audit_constraint.sql
-- This migration fixes the CHECK constraints on shipment_products_audit table to allow the 'modified' action used by the refactored audit trigger.

BEGIN;

-- 1. Drop old constraints
ALTER TABLE public.shipment_products_audit DROP CONSTRAINT IF EXISTS shipment_products_audit_action_check;
ALTER TABLE public.shipment_products_audit DROP CONSTRAINT IF EXISTS shipment_products_audit_check;

-- 2. Re-add updated action check constraint to include 'modified'
ALTER TABLE public.shipment_products_audit
ADD CONSTRAINT shipment_products_audit_action_check
CHECK (action IN ('added', 'removed', 'quantity_changed', 'unit_changed', 'rate_changed', 'amount_changed', 'modified'));

-- 3. Re-add updated column integrity check constraint to allow 'modified' with new values
ALTER TABLE public.shipment_products_audit
ADD CONSTRAINT shipment_products_audit_check
CHECK (
  (action = 'added' AND new_quantity IS NOT NULL) OR
  (action = 'removed' AND old_quantity IS NOT NULL) OR
  (action = 'modified' AND new_quantity IS NOT NULL) OR
  (action IN ('quantity_changed', 'unit_changed', 'rate_changed', 'amount_changed'))
);

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';

COMMIT;
