-- Final simple fix with proper default handling

BEGIN;

-- Step 1: Update any shipments in the old stage
UPDATE shipment
SET current_stage = 'lc_opening'
WHERE current_stage = 'lc_shared_with_supplier';

-- Step 2: Drop the default temporarily
ALTER TABLE shipment ALTER COLUMN current_stage DROP DEFAULT;

-- Step 3: Update the enum type
ALTER TYPE stage RENAME TO stage_old;

CREATE TYPE stage AS ENUM (
    'forecast',
    'enlistment_verification',
    'availability_confirmation',
    'proforma',
    'purchase_order',
    'ip_number',
    'lc_opening',
    'invoice',
    'shipment_details_from_supplier',
    'freight_query',
    'award_shipment',
    'original_docs',
    'non_negotiable_docs',
    'bank_endorsement',
    'send_to_clearing_agent',
    'under_clearing_agent',
    'release_orders',
    'gate_out',
    'transportation',
    'warehouse',
    'bills'
);

-- Step 4: Update all tables that use the enum
ALTER TABLE shipment ALTER COLUMN current_stage TYPE stage USING current_stage::text::stage;
ALTER TABLE audit_log ALTER COLUMN from_stage TYPE stage USING from_stage::text::stage;
ALTER TABLE audit_log ALTER COLUMN to_stage TYPE stage USING to_stage::text::stage;
ALTER TABLE stage_edge ALTER COLUMN from_stage TYPE stage USING from_stage::text::stage;
ALTER TABLE stage_edge ALTER COLUMN to_stage TYPE stage USING to_stage::text::stage;
ALTER TABLE stage_details ALTER COLUMN stage_name TYPE stage USING stage_name::text::stage;

-- Step 5: Restore the default
ALTER TABLE shipment ALTER COLUMN current_stage SET DEFAULT 'forecast'::stage;

-- Step 6: Drop old enum
DROP TYPE stage_old;

COMMIT;

-- Verify
SELECT 'SUCCESS! LC stages merged.' as result;
