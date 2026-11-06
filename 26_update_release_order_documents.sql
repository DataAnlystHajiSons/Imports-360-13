-- Migration: 26_update_release_order_documents.sql
-- Description: Update release orders in required_document_config to separate FSRD and DPP requirements

BEGIN;

-- 1. Update existing generic release_order configs to FSRD
UPDATE public.required_document_config
SET doc_type = 'release_order_fsrd',
    doc_name = 'Release Order (FSRD)',
    description = 'FSRD release order'
WHERE doc_type = 'release_order';

-- 2. Insert DPP release order configs for sea and air
INSERT INTO public.required_document_config (mode_of_transport, inco_term, doc_type, doc_name, description, is_mandatory)
SELECT 'sea', NULL, 'release_order_dpp', 'Release Order (DPP)', 'DPP release order', true
WHERE NOT EXISTS (
  SELECT 1 FROM public.required_document_config WHERE mode_of_transport = 'sea' AND doc_type = 'release_order_dpp'
);

INSERT INTO public.required_document_config (mode_of_transport, inco_term, doc_type, doc_name, description, is_mandatory)
SELECT 'air', NULL, 'release_order_dpp', 'Release Order (DPP)', 'DPP release order', true
WHERE NOT EXISTS (
  SELECT 1 FROM public.required_document_config WHERE mode_of_transport = 'air' AND doc_type = 'release_order_dpp'
);

COMMIT;
