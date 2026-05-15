-- Add CC emails column to bank_communication table
-- This allows storing multiple stakeholder email addresses for carbon copy functionality

-- Add cc_emails column as text array
ALTER TABLE public.bank_communication
ADD COLUMN IF NOT EXISTS cc_emails text[];

-- Add comment to document the column
COMMENT ON COLUMN public.bank_communication.cc_emails IS 'Array of email addresses to CC on bank communications (stakeholders)';

-- Example usage:
-- INSERT INTO bank_communication (shipment_id, bank_id, bank_contact_id, sent_by, email_subject, email_body, cc_emails, status)
-- VALUES ('shipment-uuid', 'bank-uuid', 'contact-uuid', 'user-uuid', 'Subject', 'Body', ARRAY['stakeholder1@example.com', 'stakeholder2@example.com'], 'sent');

-- Query to test:
-- SELECT id, email_subject, cc_emails FROM bank_communication WHERE cc_emails IS NOT NULL;
