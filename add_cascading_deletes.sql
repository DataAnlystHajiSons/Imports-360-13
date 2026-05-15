-- This script adds cascading deletes to foreign key constraints referencing the shipment table.
-- This ensures that when a shipment is deleted, all its related data is also deleted.

-- Direct dependencies on shipment table

ALTER TABLE public.audit_log DROP CONSTRAINT IF EXISTS audit_log_shipment_id_fkey;
ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.availability_confirmation DROP CONSTRAINT IF EXISTS availability_confirmation_shipment_id_fkey;
ALTER TABLE public.availability_confirmation ADD CONSTRAINT availability_confirmation_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.bank_charges DROP CONSTRAINT IF EXISTS bank_charges_shipment_id_fkey;
ALTER TABLE public.bank_charges ADD CONSTRAINT bank_charges_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.bank_endorsement DROP CONSTRAINT IF EXISTS bank_endorsement_shipment_id_fkey;
ALTER TABLE public.bank_endorsement ADD CONSTRAINT bank_endorsement_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.bility DROP CONSTRAINT IF EXISTS bility_shipment_id_fkey;
ALTER TABLE public.bility ADD CONSTRAINT bility_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.bills DROP CONSTRAINT IF EXISTS bills_shipment_id_fkey;
ALTER TABLE public.bills ADD CONSTRAINT bills_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.clearing_agent_bill DROP CONSTRAINT IF EXISTS clearing_agent_bill_shipment_id_fkey;
ALTER TABLE public.clearing_agent_bill ADD CONSTRAINT clearing_agent_bill_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.commercial_invoice DROP CONSTRAINT IF EXISTS commercial_invoice_shipment_id_fkey;
ALTER TABLE public.commercial_invoice ADD CONSTRAINT commercial_invoice_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.docs_to_clearing_agent DROP CONSTRAINT IF EXISTS docs_to_clearing_agent_shipment_id_fkey;
ALTER TABLE public.docs_to_clearing_agent ADD CONSTRAINT docs_to_clearing_agent_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.document DROP CONSTRAINT IF EXISTS document_shipment_id_fkey;
ALTER TABLE public.document ADD CONSTRAINT document_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.enlistment_verification DROP CONSTRAINT IF EXISTS enlistment_verification_shipment_id_fkey;
ALTER TABLE public.enlistment_verification ADD CONSTRAINT enlistment_verification_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.fbr_duty DROP CONSTRAINT IF EXISTS fbr_duty_shipment_id_fkey;
ALTER TABLE public.fbr_duty ADD CONSTRAINT fbr_duty_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.freight_forwarder_bill DROP CONSTRAINT IF EXISTS freight_forwarder_bill_shipment_id_fkey;
ALTER TABLE public.freight_forwarder_bill ADD CONSTRAINT freight_forwarder_bill_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.freight_query DROP CONSTRAINT IF EXISTS freight_query_shipment_id_fkey;
ALTER TABLE public.freight_query ADD CONSTRAINT freight_query_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.gate_out DROP CONSTRAINT IF EXISTS gate_out_shipment_id_fkey;
ALTER TABLE public.gate_out ADD CONSTRAINT gate_out_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.insurance DROP CONSTRAINT IF EXISTS insurance_shipment_id_fkey;
ALTER TABLE public.insurance ADD CONSTRAINT insurance_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.ip_number DROP CONSTRAINT IF EXISTS ip_number_shipment_id_fkey;
ALTER TABLE public.ip_number ADD CONSTRAINT ip_number_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.lc_share DROP CONSTRAINT IF EXISTS lc_share_shipment_id_fkey;
ALTER TABLE public.lc_share ADD CONSTRAINT lc_share_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.letter_of_credit DROP CONSTRAINT IF EXISTS letter_of_credit_shipment_id_fkey;
ALTER TABLE public.letter_of_credit ADD CONSTRAINT letter_of_credit_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.non_negotiable_docs DROP CONSTRAINT IF EXISTS non_negotiable_docs_shipment_id_fkey;
ALTER TABLE public.non_negotiable_docs ADD CONSTRAINT non_negotiable_docs_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.original_docs DROP CONSTRAINT IF EXISTS original_docs_shipment_id_fkey;
ALTER TABLE public.original_docs ADD CONSTRAINT original_docs_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.proforma_invoice DROP CONSTRAINT IF EXISTS proforma_invoice_shipment_id_fkey;
ALTER TABLE public.proforma_invoice ADD CONSTRAINT proforma_invoice_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.purchase_order DROP CONSTRAINT IF EXISTS purchase_order_shipment_id_fkey;
ALTER TABLE public.purchase_order ADD CONSTRAINT purchase_order_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.release_orders DROP CONSTRAINT IF EXISTS release_order_shipment_id_fkey;
ALTER TABLE public.release_orders ADD CONSTRAINT release_order_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.shipment_awarded DROP CONSTRAINT IF EXISTS shipment_awarded_shipment_fkey;
ALTER TABLE public.shipment_awarded ADD CONSTRAINT shipment_awarded_shipment_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.shipment_products DROP CONSTRAINT IF EXISTS shipment_products_shipment_id_fkey;
ALTER TABLE public.shipment_products ADD CONSTRAINT shipment_products_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.supplier_shipment_details DROP CONSTRAINT IF EXISTS supplier_shipment_details_shipment_id_fkey;
ALTER TABLE public.supplier_shipment_details ADD CONSTRAINT supplier_shipment_details_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.transporter DROP CONSTRAINT IF EXISTS transporter_shipment_id_fkey;
ALTER TABLE public.transporter ADD CONSTRAINT transporter_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.under_clearing_agent DROP CONSTRAINT IF EXISTS under_clearing_agent_shipment_id_fkey;
ALTER TABLE public.under_clearing_agent ADD CONSTRAINT under_clearing_agent_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

ALTER TABLE public.warehouse_arrival DROP CONSTRAINT IF EXISTS warehouse_arrival_shipment_id_fkey;
ALTER TABLE public.warehouse_arrival ADD CONSTRAINT warehouse_arrival_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;


-- Indirect dependencies

-- When bank_charges is deleted, related amendment, bank_charge_documents, final_payment, and issuance should be deleted.
ALTER TABLE public.amendment DROP CONSTRAINT IF EXISTS amendment_bank_charges_id_fkey;
ALTER TABLE public.amendment ADD CONSTRAINT amendment_bank_charges_id_fkey FOREIGN KEY (bank_charges_id) REFERENCES public.bank_charges(id) ON DELETE CASCADE;

ALTER TABLE public.bank_charge_documents DROP CONSTRAINT IF EXISTS bank_charge_documents_bank_charges_id_fkey;
ALTER TABLE public.bank_charge_documents ADD CONSTRAINT bank_charge_documents_bank_charges_id_fkey FOREIGN KEY (bank_charges_id) REFERENCES public.bank_charges(id) ON DELETE CASCADE;

ALTER TABLE public.final_payment DROP CONSTRAINT IF EXISTS final_payment_bank_charges_id_fkey;
ALTER TABLE public.final_payment ADD CONSTRAINT final_payment_bank_charges_id_fkey FOREIGN KEY (bank_charges_id) REFERENCES public.bank_charges(id) ON DELETE CASCADE;

ALTER TABLE public.issuance DROP CONSTRAINT IF EXISTS issuance_bank_charges_id_fkey;
ALTER TABLE public.issuance ADD CONSTRAINT issuance_bank_charges_id_fkey FOREIGN KEY (bank_charges_id) REFERENCES public.bank_charges(id) ON DELETE CASCADE;

-- When clearing_agent_bill is deleted, related agency_charges, deductions, duties, payments, and receipted_port_expense should be deleted.
ALTER TABLE public.agency_charges DROP CONSTRAINT IF EXISTS agency_charges_clearing_agent_bill_id_fkey;
ALTER TABLE public.agency_charges ADD CONSTRAINT agency_charges_clearing_agent_bill_id_fkey FOREIGN KEY (clearing_agent_bill_id) REFERENCES public.clearing_agent_bill(id) ON DELETE CASCADE;

ALTER TABLE public.deductions DROP CONSTRAINT IF EXISTS deductions_clearing_agent_bill_id_fkey;
ALTER TABLE public.deductions ADD CONSTRAINT deductions_clearing_agent_bill_id_fkey FOREIGN KEY (clearing_agent_bill_id) REFERENCES public.clearing_agent_bill(id) ON DELETE CASCADE;

ALTER TABLE public.duties DROP CONSTRAINT IF EXISTS duties_clearing_agent_bill_id_fkey;
ALTER TABLE public.duties ADD CONSTRAINT duties_clearing_agent_bill_id_fkey FOREIGN KEY (clearing_agent_bill_id) REFERENCES public.clearing_agent_bill(id) ON DELETE CASCADE;

ALTER TABLE public.payments DROP CONSTRAINT IF EXISTS payments_clearing_agent_bill_id_fkey;
ALTER TABLE public.payments ADD CONSTRAINT payments_clearing_agent_bill_id_fkey FOREIGN KEY (clearing_agent_bill_id) REFERENCES public.clearing_agent_bill(id) ON DELETE CASCADE;

ALTER TABLE public.receipted_port_expense DROP CONSTRAINT IF EXISTS receipted_port_expense_clearing_agent_bill_id_fkey;
ALTER TABLE public.receipted_port_expense ADD CONSTRAINT receipted_port_expense_clearing_agent_bill_id_fkey FOREIGN KEY (clearing_agent_bill_id) REFERENCES public.clearing_agent_bill(id) ON DELETE CASCADE;

-- When freight_forwarder_bill is deleted, related charges should be deleted.
ALTER TABLE public.charges DROP CONSTRAINT IF EXISTS charges_freight_forwarder_bill_id_fkey;
ALTER TABLE public.charges ADD CONSTRAINT charges_freight_forwarder_bill_id_fkey FOREIGN KEY (freight_forwarder_bill_id) REFERENCES public.freight_forwarder_bill(id) ON DELETE CASCADE;

-- When freight_query is deleted, related freight_quote_response should be deleted.
ALTER TABLE public.freight_quote_response DROP CONSTRAINT IF EXISTS freight_quote_response_freight_query_id_fkey;
ALTER TABLE public.freight_quote_response ADD CONSTRAINT freight_quote_response_freight_query_id_fkey FOREIGN KEY (freight_query_id) REFERENCES public.freight_query(id) ON DELETE CASCADE;

-- When original_docs is deleted, related bank_endorsement should be deleted.
ALTER TABLE public.bank_endorsement DROP CONSTRAINT IF EXISTS bank_endorsement_original_docs_id_fkey;
ALTER TABLE public.bank_endorsement ADD CONSTRAINT bank_endorsement_original_docs_id_fkey FOREIGN KEY (original_docs_id) REFERENCES public.original_docs(id) ON DELETE CASCADE;

-- When under_clearing_agent is deleted, related release_orders should be deleted.
ALTER TABLE public.release_orders DROP CONSTRAINT IF EXISTS release_order_under_clearing_agent_id_fkey;
ALTER TABLE public.release_orders ADD CONSTRAINT release_order_under_clearing_agent_id_fkey FOREIGN KEY (under_clearing_agent_id) REFERENCES public.under_clearing_agent(id) ON DELETE CASCADE;
