-- Fix for non_negotiable_docs.uploaded_by
ALTER TABLE public.non_negotiable_docs ADD CONSTRAINT non_negotiable_docs_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.app_user(id);

-- Fix for original_docs.uploaded_by
ALTER TABLE public.original_docs ADD CONSTRAINT original_docs_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.app_user(id);

-- Fix for bank_endorsement.updated_by
ALTER TABLE public.bank_endorsement ADD CONSTRAINT bank_endorsement_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.app_user(id);

-- Fix for gate_out.updated_by
ALTER TABLE public.gate_out ADD CONSTRAINT gate_out_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.app_user(id);

-- Fix for transporter.updated_by
ALTER TABLE public.transporter ADD CONSTRAINT transporter_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.app_user(id);

-- Fix for warehouse_arrival.updated_by
ALTER TABLE public.warehouse_arrival ADD CONSTRAINT warehouse_arrival_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.app_user(id);

-- Fix for bills.updated_by
ALTER TABLE public.bills ADD CONSTRAINT bills_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.app_user(id);
