-- This migration adds Row Level Security (RLS) policies to the new bank-related tables.
-- These policies are required for the front-end application to be able to query the tables.

-- 1. Enable RLS on new tables.
-- It's safe to run this even if RLS is already enabled.
ALTER TABLE public.bank_contact ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_communication ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_communication_documents ENABLE ROW LEVEL SECURITY;

-- 2. Create policies for the 'bank' table.
-- This policy allows any authenticated user to perform all actions (SELECT, INSERT, UPDATE, DELETE).
DROP POLICY IF EXISTS "Allow full access for authenticated users" ON public.bank;
CREATE POLICY "Allow full access for authenticated users" ON public.bank
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 3. Create policies for the 'bank_contact' table.
DROP POLICY IF EXISTS "Allow full access for authenticated users" ON public.bank_contact;
CREATE POLICY "Allow full access for authenticated users" ON public.bank_contact
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 4. Create policies for the 'bank_communication' table.
DROP POLICY IF EXISTS "Allow full access for authenticated users" ON public.bank_communication;
CREATE POLICY "Allow full access for authenticated users" ON public.bank_communication
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 5. Create policies for the 'bank_communication_documents' table.
DROP POLICY IF EXISTS "Allow full access for authenticated users" ON public.bank_communication_documents;
CREATE POLICY "Allow full access for authenticated users" ON public.bank_communication_documents
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 6. Ensure the 'document' table has a SELECT policy for authenticated users.
DROP POLICY IF EXISTS "Allow authenticated users to read documents" ON public.document;
CREATE POLICY "Allow authenticated users to read documents" ON public.document
FOR SELECT USING (auth.role() = 'authenticated');
