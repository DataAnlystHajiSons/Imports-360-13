-- Fix required_document_config table to match actual doc_types used in the application
-- The issue: doc_types in config have trailing spaces and don't match the dropdown values

BEGIN;

-- First, let's see what's currently in the table
-- Run this separately first to check:
-- SELECT doc_type, doc_name, is_mandatory FROM required_document_config ORDER BY doc_name;

-- Delete all existing configs (we'll re-insert with correct values)
DELETE FROM required_document_config;

-- Insert corrected required documents with proper doc_type values
-- These values match the dropdown options in shipment_tracker.html

-- Documents required for ALL shipments (regardless of mode/inco-term)
INSERT INTO required_document_config (mode_of_transport, inco_term, doc_type, doc_name, description, is_mandatory) VALUES
-- Common for all modes
('sea', NULL, 'commercial_invoice', 'Commercial Invoice', 'Final invoice for goods', true),
('air', NULL, 'commercial_invoice', 'Commercial Invoice', 'Final invoice for goods', true),
('sea', NULL, 'packing_list', 'Packing List', 'Detailed packing list', true),
('air', NULL, 'packing_list', 'Packing List', 'Detailed packing list', true),
('sea', NULL, 'certificate_of_origin', 'Certificate of Origin', 'Origin certificate', false),
('air', NULL, 'certificate_of_origin', 'Certificate of Origin', 'Origin certificate', false),

-- SEA - Specific documents
('sea', NULL, 'bill_of_lading', 'Bill of Lading (B/L)', 'Ocean bill of lading', true),

-- AIR - Specific documents
('air', NULL, 'air_waybill', 'Air Waybill (AWB)', 'Air freight document', true),

-- Purchase Documents
('sea', NULL, 'proforma_invoice', 'Proforma Invoice', 'Initial invoice/quote', true),
('air', NULL, 'proforma_invoice', 'Proforma Invoice', 'Initial invoice/quote', true),
('sea', NULL, 'purchase_order', 'Purchase Order', 'PO document', true),
('air', NULL, 'purchase_order', 'Purchase Order', 'PO document', true),

-- Financial Documents
('sea', NULL, 'letter_of_credit', 'Letter of Credit', 'Bank LC document', false),
('air', NULL, 'letter_of_credit', 'Letter of Credit', 'Bank LC document', false),
('sea', NULL, 'insurance_certificate', 'Insurance Certificate', 'Cargo insurance', false),
('air', NULL, 'insurance_certificate', 'Insurance Certificate', 'Cargo insurance', false),
('sea', NULL, 'bank_charges', 'Bank Charges', 'Bank fee documentation', false),
('air', NULL, 'bank_charges', 'Bank Charges', 'Bank fee documentation', false),

-- Customs Documents
('sea', NULL, 'ip_number', 'IP Number', 'Import permit number', true),
('air', NULL, 'ip_number', 'IP Number', 'Import permit number', true),
('sea', NULL, 'customs_declaration', 'Customs Declaration', 'Customs declaration form', true),
('air', NULL, 'customs_declaration', 'Customs Declaration', 'Customs declaration form', true),
('sea', NULL, 'release_order', 'Release Order', 'Port/customs release order', true),
('air', NULL, 'release_order', 'Release Order', 'Airport/customs release order', true),

-- Other common documents
('sea', NULL, 'other', 'Other Document', 'Miscellaneous documents', false),
('air', NULL, 'other', 'Other Document', 'Miscellaneous documents', false)

ON CONFLICT (mode_of_transport, inco_term, doc_type) DO UPDATE SET
  doc_name = EXCLUDED.doc_name,
  description = EXCLUDED.description,
  is_mandatory = EXCLUDED.is_mandatory;

-- Verify the fix
SELECT 
  mode_of_transport,
  doc_type,
  doc_name,
  is_mandatory,
  LENGTH(doc_type) as doc_type_length  -- Should NOT have trailing spaces
FROM required_document_config
ORDER BY mode_of_transport, is_mandatory DESC, doc_name;

COMMIT;

-- After running this, test by:
-- 1. Refresh the shipment tracker page
-- 2. Open Documents modal
-- 3. Check if completion percentage updates correctly
