-- Create clearing_agent_communication table for tracking email communications with clearing agents
-- Similar to bank_communication but for clearing agents

CREATE TABLE IF NOT EXISTS public.clearing_agent_communication (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shipment_id uuid NOT NULL,
  clearing_agent_id uuid NOT NULL,
  sent_by uuid NOT NULL,
  sent_at timestamp with time zone DEFAULT now(),
  email_subject text,
  email_body text,
  cc_emails text[], -- Array of email addresses to CC (stakeholders)
  status text,
  CONSTRAINT clearing_agent_communication_pkey PRIMARY KEY (id),
  CONSTRAINT clearing_agent_communication_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE,
  CONSTRAINT clearing_agent_communication_clearing_agent_id_fkey FOREIGN KEY (clearing_agent_id) REFERENCES public.clearing_agent(id) ON DELETE CASCADE,
  CONSTRAINT clearing_agent_communication_sent_by_fkey FOREIGN KEY (sent_by) REFERENCES public.app_user(id)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_clearing_agent_communication_shipment_id 
ON public.clearing_agent_communication(shipment_id);

CREATE INDEX IF NOT EXISTS idx_clearing_agent_communication_clearing_agent_id 
ON public.clearing_agent_communication(clearing_agent_id);

-- Add comment to document the table
COMMENT ON TABLE public.clearing_agent_communication IS 'Stores email communications sent to clearing agents for shipments';
COMMENT ON COLUMN public.clearing_agent_communication.cc_emails IS 'Array of email addresses to CC on clearing agent communications (stakeholders)';

-- Create junction table for document attachments (similar to bank_communication_documents)
CREATE TABLE IF NOT EXISTS public.clearing_agent_communication_documents (
  communication_id uuid NOT NULL,
  document_id uuid NOT NULL,
  CONSTRAINT clearing_agent_communication_documents_pkey PRIMARY KEY (communication_id, document_id),
  CONSTRAINT clearing_agent_comm_docs_communication_id_fkey FOREIGN KEY (communication_id) REFERENCES public.clearing_agent_communication(id) ON DELETE CASCADE,
  CONSTRAINT clearing_agent_comm_docs_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.document(id) ON DELETE CASCADE
);

-- Add comment
COMMENT ON TABLE public.clearing_agent_communication_documents IS 'Junction table linking clearing agent communications to document attachments';

-- Grant necessary permissions (adjust based on your RLS policies)
-- ALTER TABLE public.clearing_agent_communication ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.clearing_agent_communication_documents ENABLE ROW LEVEL SECURITY;
