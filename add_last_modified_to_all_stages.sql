-- Add last modified (updated_at, updated_by) tracking to all shipment stage tables
-- This allows us to track when each stage was last modified and by whom

BEGIN;

-- =============================================
-- STEP 1: Add columns to tables that don't have them
-- =============================================

-- Proforma Invoice
ALTER TABLE proforma_invoice 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES app_user(id),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Purchase Order
ALTER TABLE purchase_order 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES app_user(id),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Commercial Invoice
ALTER TABLE commercial_invoice 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES app_user(id),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Letter of Credit
ALTER TABLE letter_of_credit 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES app_user(id),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Non-Negotiable Docs
ALTER TABLE non_negotiable_docs 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES app_user(id),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Original Docs
ALTER TABLE original_docs 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES app_user(id),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Warehouse Arrival
ALTER TABLE warehouse_arrival 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Under Clearing Agent
ALTER TABLE under_clearing_agent 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Release Orders
ALTER TABLE release_orders 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES app_user(id),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Docs to Clearing Agent
ALTER TABLE docs_to_clearing_agent 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES app_user(id),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Supplier Shipment Details
ALTER TABLE supplier_shipment_details 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Clearing Agent Bill
ALTER TABLE clearing_agent_bill 
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- FBR Duty
ALTER TABLE fbr_duty 
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- Costing
ALTER TABLE costing 
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES app_user(id);

-- =============================================
-- STEP 2: Create trigger function to auto-update updated_at
-- =============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- STEP 3: Create triggers for all stage tables
-- =============================================

-- Proforma Invoice
DROP TRIGGER IF EXISTS update_proforma_invoice_updated_at ON proforma_invoice;
CREATE TRIGGER update_proforma_invoice_updated_at
    BEFORE UPDATE ON proforma_invoice
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Purchase Order
DROP TRIGGER IF EXISTS update_purchase_order_updated_at ON purchase_order;
CREATE TRIGGER update_purchase_order_updated_at
    BEFORE UPDATE ON purchase_order
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Commercial Invoice
DROP TRIGGER IF EXISTS update_commercial_invoice_updated_at ON commercial_invoice;
CREATE TRIGGER update_commercial_invoice_updated_at
    BEFORE UPDATE ON commercial_invoice
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Letter of Credit
DROP TRIGGER IF EXISTS update_letter_of_credit_updated_at ON letter_of_credit;
CREATE TRIGGER update_letter_of_credit_updated_at
    BEFORE UPDATE ON letter_of_credit
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- IP Number
DROP TRIGGER IF EXISTS update_ip_number_updated_at ON ip_number;
CREATE TRIGGER update_ip_number_updated_at
    BEFORE UPDATE ON ip_number
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Non-Negotiable Docs
DROP TRIGGER IF EXISTS update_non_negotiable_docs_updated_at ON non_negotiable_docs;
CREATE TRIGGER update_non_negotiable_docs_updated_at
    BEFORE UPDATE ON non_negotiable_docs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Original Docs
DROP TRIGGER IF EXISTS update_original_docs_updated_at ON original_docs;
CREATE TRIGGER update_original_docs_updated_at
    BEFORE UPDATE ON original_docs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Bank Charges
DROP TRIGGER IF EXISTS update_bank_charges_updated_at ON bank_charges;
CREATE TRIGGER update_bank_charges_updated_at
    BEFORE UPDATE ON bank_charges
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insurance
DROP TRIGGER IF EXISTS update_insurance_updated_at ON insurance;
CREATE TRIGGER update_insurance_updated_at
    BEFORE UPDATE ON insurance
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Freight Forwarder Bill
DROP TRIGGER IF EXISTS update_freight_forwarder_bill_updated_at ON freight_forwarder_bill;
CREATE TRIGGER update_freight_forwarder_bill_updated_at
    BEFORE UPDATE ON freight_forwarder_bill
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- FBR Duty
DROP TRIGGER IF EXISTS update_fbr_duty_updated_at ON fbr_duty;
CREATE TRIGGER update_fbr_duty_updated_at
    BEFORE UPDATE ON fbr_duty
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Bility
DROP TRIGGER IF EXISTS update_bility_updated_at ON bility;
CREATE TRIGGER update_bility_updated_at
    BEFORE UPDATE ON bility
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Clearing Agent Bill
DROP TRIGGER IF EXISTS update_clearing_agent_bill_updated_at ON clearing_agent_bill;
CREATE TRIGGER update_clearing_agent_bill_updated_at
    BEFORE UPDATE ON clearing_agent_bill
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Warehouse Arrival
DROP TRIGGER IF EXISTS update_warehouse_arrival_updated_at ON warehouse_arrival;
CREATE TRIGGER update_warehouse_arrival_updated_at
    BEFORE UPDATE ON warehouse_arrival
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Under Clearing Agent
DROP TRIGGER IF EXISTS update_under_clearing_agent_updated_at ON under_clearing_agent;
CREATE TRIGGER update_under_clearing_agent_updated_at
    BEFORE UPDATE ON under_clearing_agent
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Gate Out
DROP TRIGGER IF EXISTS update_gate_out_updated_at ON gate_out;
CREATE TRIGGER update_gate_out_updated_at
    BEFORE UPDATE ON gate_out
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Bills
DROP TRIGGER IF EXISTS update_bills_updated_at ON bills;
CREATE TRIGGER update_bills_updated_at
    BEFORE UPDATE ON bills
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Costing
DROP TRIGGER IF EXISTS update_costing_updated_at ON costing;
CREATE TRIGGER update_costing_updated_at
    BEFORE UPDATE ON costing
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Release Orders
DROP TRIGGER IF EXISTS update_release_orders_updated_at ON release_orders;
CREATE TRIGGER update_release_orders_updated_at
    BEFORE UPDATE ON release_orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Docs to Clearing Agent
DROP TRIGGER IF EXISTS update_docs_to_clearing_agent_updated_at ON docs_to_clearing_agent;
CREATE TRIGGER update_docs_to_clearing_agent_updated_at
    BEFORE UPDATE ON docs_to_clearing_agent
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Supplier Shipment Details
DROP TRIGGER IF EXISTS update_supplier_shipment_details_updated_at ON supplier_shipment_details;
CREATE TRIGGER update_supplier_shipment_details_updated_at
    BEFORE UPDATE ON supplier_shipment_details
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- STEP 4: Verify the changes
-- =============================================

-- Check which tables have updated_at columns
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND column_name IN ('updated_at', 'updated_by', 'created_at', 'created_by')
AND table_name IN (
    'proforma_invoice', 'purchase_order', 'commercial_invoice', 'letter_of_credit',
    'ip_number', 'non_negotiable_docs', 'original_docs', 'bank_charges',
    'insurance', 'freight_forwarder_bill', 'fbr_duty', 'bility',
    'clearing_agent_bill', 'warehouse_arrival', 'under_clearing_agent',
    'gate_out', 'bills', 'costing', 'release_orders', 'docs_to_clearing_agent',
    'supplier_shipment_details'
)
ORDER BY table_name, column_name;

-- Check triggers
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND trigger_name LIKE '%updated_at%'
ORDER BY event_object_table;

COMMIT;

-- =============================================
-- NOTES:
-- =============================================
-- 1. All stage tables now have updated_at and updated_by columns
-- 2. Triggers automatically update updated_at on every UPDATE
-- 3. Frontend needs to pass updated_by (user ID) when updating records
-- 4. created_at is set once when record is first created
-- 5. created_by should be set when creating records
