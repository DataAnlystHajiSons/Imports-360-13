-- ================================================================================= --
--                                STORAGE POLICIES                                   --
-- ================================================================================= --

-- Policy for 'shipment-docs' bucket
CREATE POLICY "Authenticated users can access shipment-docs"
ON storage.objects FOR ALL
TO authenticated
USING ( bucket_id = 'shipment-docs' );

-- Policy for 'freight-quotes' bucket
CREATE POLICY "Authenticated users can access freight-quotes"
ON storage.objects FOR ALL
TO authenticated
USING ( bucket_id = 'freight-quotes' );


-- ================================================================================= --
--                                 TABLE POLICIES                                    --
-- ================================================================================= --

-- Enable Row Level Security (RLS) and create policies for each table.
-- This allows any authenticated user to perform any action on any table.

-- alert_emails_list
ALTER TABLE public.alert_emails_list ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access alert_emails_list" ON public.alert_emails_list FOR ALL TO authenticated USING (true);

-- app_user
ALTER TABLE public.app_user ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access app_user" ON public.app_user FOR ALL TO authenticated USING (true);

-- audit_log
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access audit_log" ON public.audit_log FOR ALL TO authenticated USING (true);

-- availability_confirmation
ALTER TABLE public.availability_confirmation ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access availability_confirmation" ON public.availability_confirmation FOR ALL TO authenticated USING (true);

-- bank
ALTER TABLE public.bank ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access bank" ON public.bank FOR ALL TO authenticated USING (true);

-- bank_endorsement
ALTER TABLE public.bank_endorsement ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access bank_endorsement" ON public.bank_endorsement FOR ALL TO authenticated USING (true);

-- bills
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access bills" ON public.bills FOR ALL TO authenticated USING (true);

-- clearing_agent
ALTER TABLE public.clearing_agent ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access clearing_agent" ON public.clearing_agent FOR ALL TO authenticated USING (true);

-- commercial_invoice
ALTER TABLE public.commercial_invoice ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access commercial_invoice" ON public.commercial_invoice FOR ALL TO authenticated USING (true);

-- docs_to_clearing_agent
ALTER TABLE public.docs_to_clearing_agent ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access docs_to_clearing_agent" ON public.docs_to_clearing_agent FOR ALL TO authenticated USING (true);

-- document
ALTER TABLE public.document ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access document" ON public.document FOR ALL TO authenticated USING (true);

-- enlistment_verification
ALTER TABLE public.enlistment_verification ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access enlistment_verification" ON public.enlistment_verification FOR ALL TO authenticated USING (true);

-- forecast
ALTER TABLE public.forecast ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access forecast" ON public.forecast FOR ALL TO authenticated USING (true);

-- freight_query
ALTER TABLE public.freight_query ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access freight_query" ON public.freight_query FOR ALL TO authenticated USING (true);

-- freight_quote_response
ALTER TABLE public.freight_quote_response ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access freight_quote_response" ON public.freight_quote_response FOR ALL TO authenticated USING (true);

-- gate_out
ALTER TABLE public.gate_out ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access gate_out" ON public.gate_out FOR ALL TO authenticated USING (true);

-- ip_number
ALTER TABLE public.ip_number ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access ip_number" ON public.ip_number FOR ALL TO authenticated USING (true);

-- lc_share
ALTER TABLE public.lc_share ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access lc_share" ON public.lc_share FOR ALL TO authenticated USING (true);

-- letter_of_credit
ALTER TABLE public.letter_of_credit ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access letter_of_credit" ON public.letter_of_credit FOR ALL TO authenticated USING (true);

-- logistics_company
ALTER TABLE public.logistics_company ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access logistics_company" ON public.logistics_company FOR ALL TO authenticated USING (true);

-- non_negotiable_docs
ALTER TABLE public.non_negotiable_docs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access non_negotiable_docs" ON public.non_negotiable_docs FOR ALL TO authenticated USING (true);

-- original_docs
ALTER TABLE public.original_docs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access original_docs" ON public.original_docs FOR ALL TO authenticated USING (true);

-- product_variety
ALTER TABLE public.product_variety ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access product_variety" ON public.product_variety FOR ALL TO authenticated USING (true);

-- proforma_invoice
ALTER TABLE public.proforma_invoice ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access proforma_invoice" ON public.proforma_invoice FOR ALL TO authenticated USING (true);

-- purchase_order
ALTER TABLE public.purchase_order ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access purchase_order" ON public.purchase_order FOR ALL TO authenticated USING (true);

-- release_orders
ALTER TABLE public.release_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access release_orders" ON public.release_orders FOR ALL TO authenticated USING (true);

-- shipment
ALTER TABLE public.shipment ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access shipment" ON public.shipment FOR ALL TO authenticated USING (true);

-- shipment_awarded
ALTER TABLE public.shipment_awarded ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access shipment_awarded" ON public.shipment_awarded FOR ALL TO authenticated USING (true);

-- stage_edge
ALTER TABLE public.stage_edge ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access stage_edge" ON public.stage_edge FOR ALL TO authenticated USING (true);

-- supplier
ALTER TABLE public.supplier ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access supplier" ON public.supplier FOR ALL TO authenticated USING (true);

-- supplier_shipment_details
ALTER TABLE public.supplier_shipment_details ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access supplier_shipment_details" ON public.supplier_shipment_details FOR ALL TO authenticated USING (true);

-- transporter
ALTER TABLE public.transporter ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access transporter" ON public.transporter FOR ALL TO authenticated USING (true);

-- under_clearing_agent
ALTER TABLE public.under_clearing_agent ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access under_clearing_agent" ON public.under_clearing_agent FOR ALL TO authenticated USING (true);

-- warehouse
ALTER TABLE public.warehouse ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access warehouse" ON public.warehouse FOR ALL TO authenticated USING (true);

-- warehouse_arrival
ALTER TABLE public.warehouse_arrival ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can access warehouse_arrival" ON public.warehouse_arrival FOR ALL TO authenticated USING (true);