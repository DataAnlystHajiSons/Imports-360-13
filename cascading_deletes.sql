-- This script will update the foreign key constraints to automatically delete related data when a shipment is deleted.

-- audit_log
ALTER TABLE public.audit_log DROP CONSTRAINT audit_log_shipment_id_fkey;
ALTER TABLE public.audit_log ADD CONSTRAINT audit_log_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- availability_confirmation
ALTER TABLE public.availability_confirmation DROP CONSTRAINT availability_confirmation_shipment_id_fkey;
ALTER TABLE public.availability_confirmation ADD CONSTRAINT availability_confirmation_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- bank_endorsement
ALTER TABLE public.bank_endorsement DROP CONSTRAINT bank_endorsement_shipment_id_fkey;
ALTER TABLE public.bank_endorsement ADD CONSTRAINT bank_endorsement_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- bills
ALTER TABLE public.bills DROP CONSTRAINT bills_shipment_id_fkey;
ALTER TABLE public.bills ADD CONSTRAINT bills_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- commercial_invoice
ALTER TABLE public.commercial_invoice DROP CONSTRAINT commercial_invoice_shipment_id_fkey;
ALTER TABLE public.commercial_invoice ADD CONSTRAINT commercial_invoice_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- docs_to_clearing_agent
ALTER TABLE public.docs_to_clearing_agent DROP CONSTRAINT docs_to_clearing_agent_shipment_id_fkey;
ALTER TABLE public.docs_to_clearing_agent ADD CONSTRAINT docs_to_clearing_agent_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- document
ALTER TABLE public.document DROP CONSTRAINT document_shipment_id_fkey;
ALTER TABLE public.document ADD CONSTRAINT document_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- enlistment_verification
ALTER TABLE public.enlistment_verification DROP CONSTRAINT enlistment_verification_shipment_id_fkey;
ALTER TABLE public.enlistment_verification ADD CONSTRAINT enlistment_verification_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- freight_query
ALTER TABLE public.freight_query DROP CONSTRAINT freight_query_shipment_id_fkey;
ALTER TABLE public.freight_query ADD CONSTRAINT freight_query_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- gate_out
ALTER TABLE public.gate_out DROP CONSTRAINT gate_out_shipment_id_fkey;
ALTER TABLE public.gate_out ADD CONSTRAINT gate_out_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- ip_number
ALTER TABLE public.ip_number DROP CONSTRAINT ip_number_shipment_id_fkey;
ALTER TABLE public.ip_number ADD CONSTRAINT ip_number_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- lc_share
ALTER TABLE public.lc_share DROP CONSTRAINT lc_share_shipment_id_fkey;
ALTER TABLE public.lc_share ADD CONSTRAINT lc_share_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- letter_of_credit
ALTER TABLE public.letter_of_credit DROP CONSTRAINT letter_of_credit_shipment_id_fkey;
ALTER TABLE public.letter_of_credit ADD CONSTRAINT letter_of_credit_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- non_negotiable_docs
ALTER TABLE public.non_negotiable_docs DROP CONSTRAINT non_negotiable_docs_shipment_id_fkey;
ALTER TABLE public.non_negotiable_docs ADD CONSTRAINT non_negotiable_docs_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- original_docs
ALTER TABLE public.original_docs DROP CONSTRAINT original_docs_shipment_id_fkey;
ALTER TABLE public.original_docs ADD CONSTRAINT original_docs_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- proforma_invoice
ALTER TABLE public.proforma_invoice DROP CONSTRAINT proforma_invoice_shipment_id_fkey;
ALTER TABLE public.proforma_invoice ADD CONSTRAINT proforma_invoice_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- purchase_order
ALTER TABLE public.purchase_order DROP CONSTRAINT purchase_order_shipment_id_fkey;
ALTER TABLE public.purchase_order ADD CONSTRAINT purchase_order_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- release_orders
ALTER TABLE public.release_orders DROP CONSTRAINT release_order_shipment_id_fkey;
ALTER TABLE public.release_orders ADD CONSTRAINT release_order_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- shipment_awarded
ALTER TABLE public.shipment_awarded DROP CONSTRAINT shipment_awarded_shipment_fkey;
ALTER TABLE public.shipment_awarded ADD CONSTRAINT shipment_awarded_shipment_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- supplier_shipment_details
ALTER TABLE public.supplier_shipment_details DROP CONSTRAINT supplier_shipment_details_shipment_id_fkey;
ALTER TABLE public.supplier_shipment_details ADD CONSTRAINT supplier_shipment_details_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- transporter
ALTER TABLE public.transporter DROP CONSTRAINT transporter_shipment_id_fkey;
ALTER TABLE public.transporter ADD CONSTRAINT transporter_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- under_clearing_agent
ALTER TABLE public.under_clearing_agent DROP CONSTRAINT under_clearing_agent_shipment_id_fkey;
ALTER TABLE public.under_clearing_agent ADD CONSTRAINT under_clearing_agent_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;

-- warehouse_arrival
ALTER TABLE public.warehouse_arrival DROP CONSTRAINT warehouse_arrival_shipment_id_fkey;
ALTER TABLE public.warehouse_arrival ADD CONSTRAINT warehouse_arrival_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE;
