-- Migration to enhance bank communication capabilities.
-- Adds tables for bank contacts, communication logs, and document associations.

-- 1. Enhance the existing `bank` table with more details.
ALTER TABLE public.bank
ADD COLUMN branch_name text,
ADD COLUMN branch_address text,
ADD COLUMN swift_code text,
ADD COLUMN created_at timestamp with time zone DEFAULT now(),
ADD COLUMN updated_at timestamp with time zone DEFAULT now();

-- 2. Create a new table to store specific contacts for each bank.
CREATE TABLE public.bank_contact (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    bank_id uuid NOT NULL,
    contact_name text,
    contact_email text NOT NULL,
    contact_phone text,
    department text, -- e.g., 'Trade Finance', 'LC Department'
    is_primary boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT bank_contact_pkey PRIMARY KEY (id),
    CONSTRAINT bank_contact_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES public.bank(id) ON DELETE CASCADE
);

-- 3. Create a table to log all email communications with banks.
CREATE TABLE public.bank_communication (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    shipment_id uuid NOT NULL,
    bank_id uuid NOT NULL,
    bank_contact_id uuid, -- Optional, in case email is sent to a generic bank address
    sent_by uuid NOT NULL, -- FK to app_user
    sent_at timestamp with time zone DEFAULT now(),
    email_subject text,
    email_body text,
    status text, -- e.g., 'sent', 'failed', 'delivered', 'opened'
    CONSTRAINT bank_communication_pkey PRIMARY KEY (id),
    CONSTRAINT bank_communication_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE,
    CONSTRAINT bank_communication_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES public.bank(id),
    CONSTRAINT bank_communication_bank_contact_id_fkey FOREIGN KEY (bank_contact_id) REFERENCES public.bank_contact(id),
    CONSTRAINT bank_communication_sent_by_fkey FOREIGN KEY (sent_by) REFERENCES public.app_user(id)
);

-- 4. Create a join table to link multiple documents to a single communication.
CREATE TABLE public.bank_communication_documents (
    communication_id uuid NOT NULL,
    document_id uuid NOT NULL,
    CONSTRAINT bank_communication_documents_pkey PRIMARY KEY (communication_id, document_id),
    CONSTRAINT bank_communication_documents_communication_id_fkey FOREIGN KEY (communication_id) REFERENCES public.bank_communication(id) ON DELETE CASCADE,
    CONSTRAINT bank_communication_documents_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.document(id) ON DELETE CASCADE
);
