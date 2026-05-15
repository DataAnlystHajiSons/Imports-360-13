-- ============================================
-- Smart Document Management System
-- ============================================
-- Documents don't block stages, but are required for shipment completion
-- Required documents based on Mode of Transport + Inco-term

BEGIN;

-- Step 1: Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_document_shipment_id ON document(shipment_id);
CREATE INDEX IF NOT EXISTS idx_document_doc_type ON document(doc_type);
CREATE INDEX IF NOT EXISTS idx_document_uploaded_at ON document(shipment_id, uploaded_at DESC);

-- Step 2: Add metadata and status to document table
ALTER TABLE document 
ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'archived', 'deleted', 'replaced')),
ADD COLUMN IF NOT EXISTS file_size BIGINT,
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Step 3: Create document categories
CREATE TABLE IF NOT EXISTS document_category (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  icon TEXT,
  sort_order INTEGER DEFAULT 0
);

-- Seed categories
INSERT INTO document_category (name, description, icon, sort_order) VALUES
('Commercial', 'Invoices, quotes, purchase orders', 'fa-file-invoice', 1),
('Shipping', 'Bills of lading, packing lists', 'fa-ship', 2),
('Banking', 'LC, bank documents', 'fa-university', 3),
('Customs', 'Customs and duty documents', 'fa-passport', 4),
('Certificates', 'Quality, origin certificates', 'fa-certificate', 5),
('Insurance', 'Insurance documents', 'fa-shield-alt', 6),
('Clearing', 'Clearing agent documents', 'fa-file-contract', 7),
('Transport', 'Transport and delivery docs', 'fa-truck', 8),
('Other', 'Miscellaneous documents', 'fa-folder', 9)
ON CONFLICT (name) DO NOTHING;

-- Step 4: Add category to document
ALTER TABLE document 
ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES document_category(id);

-- Step 5: Create required documents configuration table
-- Based on mode_of_transport and inco_term
CREATE TABLE IF NOT EXISTS required_document_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mode_of_transport TEXT NOT NULL CHECK (mode_of_transport IN ('sea', 'air', 'land', 'rail', 'multimodal')),
  inco_term TEXT CHECK (inco_term IN ('EXW', 'FCA', 'CPT', 'FOB', 'CFR', 'CIF', 'DDP')),
  doc_type TEXT NOT NULL,
  doc_name TEXT NOT NULL,
  description TEXT,
  category_id UUID REFERENCES document_category(id),
  is_mandatory BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(mode_of_transport, inco_term, doc_type)
);

-- Step 6: Seed required documents based on mode and inco-term
-- Documents required for ALL shipments (regardless of mode/inco-term)
INSERT INTO required_document_config (mode_of_transport, inco_term, doc_type, doc_name, description, is_mandatory) VALUES
-- Common for all
('sea', NULL, 'commercial_invoice', 'Commercial Invoice', 'Final invoice for goods', true),
('air', NULL, 'commercial_invoice', 'Commercial Invoice', 'Final invoice for goods', true),
('sea', NULL, 'packing_list', 'Packing List', 'Detailed packing list', true),
('air', NULL, 'packing_list', 'Packing List', 'Detailed packing list', true),
('sea', NULL, 'certificate_of_origin', 'Certificate of Origin', 'Origin certificate', false),
('air', NULL, 'certificate_of_origin', 'Certificate of Origin', 'Origin certificate', false),

-- SEA - Specific documents
('sea', NULL, 'bill_of_lading', 'Bill of Lading (B/L)', 'Ocean bill of lading', true),
('sea', NULL, 'arrival_notice', 'Arrival Notice', 'Vessel arrival notification', true),

-- AIR - Specific documents  
('air', NULL, 'airway_bill', 'Air Waybill (AWB)', 'Air waybill', true),

-- FOB specific (buyer arranges shipping)
('sea', 'FOB', 'freight_booking_confirmation', 'Freight Booking', 'Freight forwarder booking', true),
('sea', 'FOB', 'insurance_certificate', 'Insurance Certificate', 'Cargo insurance', true),

-- CFR specific (seller pays freight)
('sea', 'CFR', 'freight_invoice', 'Freight Invoice', 'Freight charges invoice', true),
('sea', 'CFR', 'insurance_certificate', 'Insurance Certificate', 'Cargo insurance', true),

-- CIF specific (seller pays freight + insurance)
('sea', 'CIF', 'freight_invoice', 'Freight Invoice', 'Freight charges invoice', true),
('sea', 'CIF', 'insurance_policy', 'Insurance Policy', 'Full insurance policy', true),

-- EXW specific (buyer handles everything)
('sea', 'EXW', 'collection_receipt', 'Collection Receipt', 'Proof of collection from supplier', true),
('air', 'EXW', 'collection_receipt', 'Collection Receipt', 'Proof of collection from supplier', true),

-- FCA specific
('air', 'FCA', 'carrier_receipt', 'Carrier Receipt', 'Proof of handover to carrier', true),

-- DDP specific (seller delivers to destination)
('sea', 'DDP', 'delivery_receipt', 'Delivery Receipt', 'Proof of delivery', true),
('air', 'DDP', 'delivery_receipt', 'Delivery Receipt', 'Proof of delivery', true),

-- Customs documents (for all imports)
('sea', NULL, 'goods_declaration', 'Goods Declaration', 'Customs declaration form', true),
('air', NULL, 'goods_declaration', 'Goods Declaration', 'Customs declaration form', true),
('sea', NULL, 'duty_payment_receipt', 'Duty Payment', 'Customs duty payment proof', true),
('air', NULL, 'duty_payment_receipt', 'Duty Payment', 'Customs duty payment proof', true),

-- Banking documents (if LC payment)
('sea', NULL, 'letter_of_credit', 'Letter of Credit', 'Bank LC document', false),
('air', NULL, 'letter_of_credit', 'Letter of Credit', 'Bank LC document', false),

-- Clearing documents
('sea', NULL, 'release_order', 'Release Order', 'Port/customs release order', true),
('air', NULL, 'release_order', 'Release Order', 'Airport/customs release order', true)
ON CONFLICT (mode_of_transport, inco_term, doc_type) DO NOTHING;

-- Step 7: Create function to get required documents for a shipment
CREATE OR REPLACE FUNCTION get_required_documents(p_shipment_id uuid)
RETURNS TABLE (
  doc_type TEXT,
  doc_name TEXT,
  description TEXT,
  is_mandatory BOOLEAN,
  is_uploaded BOOLEAN,
  uploaded_at TIMESTAMP WITH TIME ZONE,
  category TEXT
) AS $$
DECLARE
  v_mode TEXT;
  v_inco_term TEXT;
BEGIN
  -- Get shipment details
  SELECT mode_of_transport, inco_term 
  INTO v_mode, v_inco_term
  FROM shipment 
  WHERE id = p_shipment_id;
  
  RETURN QUERY
  SELECT 
    rdc.doc_type,
    rdc.doc_name,
    rdc.description,
    rdc.is_mandatory,
    EXISTS(
      SELECT 1 FROM document d 
      WHERE d.shipment_id = p_shipment_id 
      AND d.doc_type = rdc.doc_type 
      AND d.status = 'active'
    ) as is_uploaded,
    d.uploaded_at,
    dc.name as category
  FROM required_document_config rdc
  LEFT JOIN document_category dc ON dc.id = rdc.category_id
  LEFT JOIN document d ON d.shipment_id = p_shipment_id 
    AND d.doc_type = rdc.doc_type 
    AND d.status = 'active'
  WHERE rdc.mode_of_transport = v_mode
    AND (rdc.inco_term IS NULL OR rdc.inco_term = v_inco_term)
  ORDER BY rdc.is_mandatory DESC, rdc.doc_name;
END;
$$ LANGUAGE plpgsql STABLE;

-- Step 8: Create function to check if shipment can be completed
CREATE OR REPLACE FUNCTION can_complete_shipment(p_shipment_id uuid)
RETURNS TABLE (
  can_complete BOOLEAN,
  missing_mandatory_docs INTEGER,
  missing_doc_list TEXT[]
) AS $$
DECLARE
  v_mode TEXT;
  v_inco_term TEXT;
  v_missing_count INTEGER;
  v_missing_list TEXT[];
BEGIN
  -- Get shipment details
  SELECT mode_of_transport, inco_term 
  INTO v_mode, v_inco_term
  FROM shipment 
  WHERE id = p_shipment_id;
  
  -- Count missing mandatory documents
  SELECT 
    COUNT(*),
    ARRAY_AGG(rdc.doc_name)
  INTO v_missing_count, v_missing_list
  FROM required_document_config rdc
  WHERE rdc.mode_of_transport = v_mode
    AND (rdc.inco_term IS NULL OR rdc.inco_term = v_inco_term)
    AND rdc.is_mandatory = true
    AND NOT EXISTS (
      SELECT 1 FROM document d 
      WHERE d.shipment_id = p_shipment_id 
      AND d.doc_type = rdc.doc_type 
      AND d.status = 'active'
    );
  
  RETURN QUERY
  SELECT 
    (v_missing_count = 0) as can_complete,
    v_missing_count as missing_mandatory_docs,
    v_missing_list as missing_doc_list;
END;
$$ LANGUAGE plpgsql STABLE;

-- Step 9: Create view for shipment document summary
CREATE OR REPLACE VIEW v_shipment_document_summary AS
SELECT 
  s.id as shipment_id,
  s.reference_code,
  s.mode_of_transport,
  s.inco_term,
  s.current_stage,
  COUNT(DISTINCT d.id) as total_uploaded,
  COUNT(DISTINCT CASE WHEN rdc.is_mandatory THEN rdc.doc_type END) as total_mandatory_required,
  COUNT(DISTINCT CASE WHEN rdc.is_mandatory AND d.id IS NOT NULL THEN rdc.doc_type END) as mandatory_uploaded,
  CASE 
    WHEN COUNT(DISTINCT CASE WHEN rdc.is_mandatory THEN rdc.doc_type END) = 0 THEN 100
    ELSE (COUNT(DISTINCT CASE WHEN rdc.is_mandatory AND d.id IS NOT NULL THEN rdc.doc_type END)::FLOAT / 
          COUNT(DISTINCT CASE WHEN rdc.is_mandatory THEN rdc.doc_type END) * 100)::INTEGER 
  END as completion_percentage,
  COUNT(DISTINCT CASE WHEN rdc.is_mandatory THEN rdc.doc_type END) = 
    COUNT(DISTINCT CASE WHEN rdc.is_mandatory AND d.id IS NOT NULL THEN rdc.doc_type END) as can_complete
FROM shipment s
LEFT JOIN required_document_config rdc ON rdc.mode_of_transport = s.mode_of_transport
  AND (rdc.inco_term IS NULL OR rdc.inco_term = s.inco_term)
LEFT JOIN document d ON d.shipment_id = s.id 
  AND d.doc_type = rdc.doc_type 
  AND d.status = 'active'
GROUP BY s.id, s.reference_code, s.mode_of_transport, s.inco_term, s.current_stage;

-- Step 10: Grant permissions
GRANT SELECT ON v_shipment_document_summary TO authenticated;
GRANT EXECUTE ON FUNCTION get_required_documents(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION can_complete_shipment(uuid) TO authenticated;

COMMIT;

-- Verification and examples
SELECT '✅ Smart document system created!' as result;

-- Example: Check what documents are required for a sea/FOB shipment
SELECT 'Required docs for SEA + FOB:' as info;
SELECT doc_name, is_mandatory, description 
FROM required_document_config 
WHERE mode_of_transport = 'sea' 
  AND (inco_term IS NULL OR inco_term = 'FOB')
ORDER BY is_mandatory DESC, doc_name;

-- Example: Check what documents are required for air/FCA shipment
SELECT 'Required docs for AIR + FCA:' as info;
SELECT doc_name, is_mandatory, description 
FROM required_document_config 
WHERE mode_of_transport = 'air' 
  AND (inco_term IS NULL OR inco_term = 'FCA')
ORDER BY is_mandatory DESC, doc_name;
