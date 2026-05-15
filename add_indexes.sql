-- This script adds indexes to the database to improve query performance.

-- Indexes for the shipment table
CREATE INDEX IF NOT EXISTS idx_shipment_status ON public.shipment(status);
CREATE INDEX IF NOT EXISTS idx_shipment_type ON public.shipment(type);
CREATE INDEX IF NOT EXISTS idx_shipment_current_stage ON public.shipment(current_stage);
CREATE INDEX IF NOT EXISTS idx_shipment_reference_code ON public.shipment USING gin (to_tsvector('english', reference_code));

-- Indexes for the product_variety table
CREATE INDEX IF NOT EXISTS idx_product_variety_supplier_id ON public.product_variety(supplier_id);
CREATE INDEX IF NOT EXISTS idx_product_variety_commodity_id ON public.product_variety(commodity_id);
CREATE INDEX IF NOT EXISTS idx_product_variety_product_name ON public.product_variety USING gin (to_tsvector('english', product_name));
CREATE INDEX IF NOT EXISTS idx_product_variety_variety_name ON public.product_variety USING gin (to_tsvector('english', variety_name));

-- Index for the under_clearing_agent table
CREATE INDEX IF NOT EXISTS idx_under_clearing_agent_clearing_agent_id ON public.under_clearing_agent(clearing_agent_id);

-- Indexes for the letter_of_credit table
CREATE INDEX IF NOT EXISTS idx_letter_of_credit_bank_id ON public.letter_of_credit(bank_id);
CREATE INDEX IF NOT EXISTS idx_letter_of_credit_lc_number ON public.letter_of_credit USING gin (to_tsvector('english', lc_number));

-- Index for the commodity table
CREATE INDEX IF NOT EXISTS idx_commodity_name ON public.commodity(name);

-- Index for the supplier table
CREATE INDEX IF NOT EXISTS idx_supplier_name ON public.supplier USING gin (to_tsvector('english', name));
