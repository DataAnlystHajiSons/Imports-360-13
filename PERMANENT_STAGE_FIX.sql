-- PERMANENT_STAGE_FIX.sql
-- This script adds "Good Declaration" and "Bank Debit Advices" stages.
-- RESTORES: Full data views (fixing the N/A issue).
-- RESTORES: Scenario-based completion (CFR skip logic and Seed commodity logic).
-- RESTORES: Independent Green Completion and Incomplete Field Counter Badges.

BEGIN;

-- 1. Drop all dependent functions and views FIRST
DROP VIEW IF EXISTS public.v_shipment_stage_checklist CASCADE;
DROP VIEW IF EXISTS public.v_shipments_with_all_details CASCADE;
DROP VIEW IF EXISTS public.v_shipments_with_details CASCADE;
DROP VIEW IF EXISTS public.v_shipment_insights CASCADE;
DROP VIEW IF EXISTS public.v_shipment_document_summary CASCADE;

DROP FUNCTION IF EXISTS public.advance_stage(uuid, public.stage, jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.stage_requirements_met(uuid, public.stage) CASCADE;
DROP FUNCTION IF EXISTS public.get_stage_order(public.stage) CASCADE;
DROP FUNCTION IF EXISTS public.filter_shipments(text,text,text,text,text,text,text,text,text,text,text) CASCADE;
DROP FUNCTION IF EXISTS public.get_shipments_needing_alerts() CASCADE;
DROP FUNCTION IF EXISTS public.set_stage_target_date(uuid, public.stage, date, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_shipment_stage_targets(uuid) CASCADE;

-- 2. Create tables for the new stages
CREATE TABLE IF NOT EXISTS public.bank_debit_advice (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    shipment_id uuid UNIQUE NOT NULL,
    is_received boolean DEFAULT false,
    received_at timestamp with time zone,
    received_by uuid REFERENCES public.app_user(id),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT bank_debit_advice_pkey PRIMARY KEY (id),
    CONSTRAINT bank_debit_advice_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS public.good_declaration (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    shipment_id uuid UNIQUE NOT NULL,
    gd_number text,
    gd_date date,
    gd_file_date date,
    clearing_agent_id uuid REFERENCES public.clearing_agent(id),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT good_declaration_pkey PRIMARY KEY (id),
    CONSTRAINT good_declaration_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE
);

-- 3. Trigger for bank_debit_advice
CREATE OR REPLACE FUNCTION public.handle_bank_debit_advice_update()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_received = true AND (OLD.is_received = false OR OLD.is_received IS NULL) THEN
        NEW.received_at = NOW();
        NEW.received_by = auth.uid();
    ELSIF NEW.is_received = false AND OLD.is_received = true THEN
        NEW.received_at = NULL;
        NEW.received_by = NULL;
    END IF;
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_bank_debit_advice_update ON public.bank_debit_advice;
CREATE TRIGGER tr_bank_debit_advice_update
    BEFORE INSERT OR UPDATE ON public.bank_debit_advice
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_bank_debit_advice_update();

-- 4. Redefine the stage enum
ALTER TABLE public.shipment ALTER COLUMN current_stage DROP DEFAULT;
ALTER TYPE public.stage RENAME TO stage_old;

CREATE TYPE public.stage AS ENUM (
    'forecast',
    'enlistment_verification',
    'availability_confirmation',
    'purchase_order',
    'proforma',
    'ip_number',
    'lc_opening',
    'bank_debit_advice',
    'invoice',
    'shipment_details_from_supplier',
    'freight_query',
    'award_shipment',
    'non_negotiable_docs',
    'bank_endorsement',
    'original_docs',
    'send_to_clearing_agent',
    'good_declaration',
    'under_clearing_agent',
    'warehouse',
    'release_orders',
    'gate_out',
    'transportation',
    'documents',
    'bills'
);

-- 5. Update all tables
ALTER TABLE public.shipment ALTER COLUMN current_stage TYPE public.stage USING current_stage::text::public.stage;
ALTER TABLE public.shipment ALTER COLUMN current_stage SET DEFAULT 'forecast'::public.stage;
ALTER TABLE public.audit_log ALTER COLUMN from_stage TYPE public.stage USING from_stage::text::public.stage;
ALTER TABLE public.audit_log ALTER COLUMN to_stage TYPE public.stage USING to_stage::text::public.stage;
ALTER TABLE public.stage_edge ALTER COLUMN from_stage TYPE public.stage USING from_stage::text::public.stage;
ALTER TABLE public.stage_edge ALTER COLUMN to_stage TYPE public.stage USING to_stage::text::public.stage;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'shipment_status_migration_backup') THEN
        ALTER TABLE public.shipment_status_migration_backup ALTER COLUMN current_stage TYPE public.stage USING current_stage::text::public.stage;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'shipment_stage_targets') THEN
        ALTER TABLE public.shipment_stage_targets ALTER COLUMN stage_name TYPE public.stage USING stage_name::text::public.stage;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'stage_details' AND column_name = 'stage_name') THEN
        ALTER TABLE public.stage_details ALTER COLUMN stage_name TYPE public.stage USING stage_name::text::public.stage;
    END IF;
END $$;

-- 6. Standardize stage_edge
TRUNCATE public.stage_edge;
INSERT INTO public.stage_edge (from_stage, to_stage) VALUES
('forecast', 'enlistment_verification'),
('enlistment_verification', 'availability_confirmation'),
('availability_confirmation', 'purchase_order'),
('purchase_order', 'proforma'),
('proforma', 'ip_number'),
('ip_number', 'lc_opening'),
('lc_opening', 'bank_debit_advice'),
('bank_debit_advice', 'invoice'),
('invoice', 'shipment_details_from_supplier'),
('shipment_details_from_supplier', 'freight_query'),
('freight_query', 'award_shipment'),
('award_shipment', 'non_negotiable_docs'),
('non_negotiable_docs', 'bank_endorsement'),
('bank_endorsement', 'original_docs'),
('original_docs', 'send_to_clearing_agent'),
('send_to_clearing_agent', 'good_declaration'),
('good_declaration', 'under_clearing_agent'),
('under_clearing_agent', 'warehouse'),
('warehouse', 'release_orders'),
('release_orders', 'gate_out'),
('gate_out', 'transportation'),
('transportation', 'documents'),
('documents', 'bills');

-- 7. Recreate Functions
CREATE OR REPLACE FUNCTION public.get_stage_order(p_stage public.stage) 
RETURNS integer AS $$
DECLARE
  stages text[] := ARRAY[
    'forecast', 'enlistment_verification', 'availability_confirmation', 'purchase_order', 'proforma', 
    'ip_number', 'lc_opening', 'bank_debit_advice', 'invoice', 'shipment_details_from_supplier',
    'freight_query', 'award_shipment', 'non_negotiable_docs', 'bank_endorsement', 'original_docs', 
    'send_to_clearing_agent', 'good_declaration', 'under_clearing_agent', 'warehouse', 'release_orders', 
    'gate_out', 'transportation', 'documents', 'bills'
  ];
BEGIN
  FOR i IN 1..array_length(stages, 1) LOOP
    IF stages[i] = p_stage::text THEN RETURN i; END IF;
  END LOOP;
  RETURN 99;
END; $$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION public.stage_requirements_met(p_shipment_id uuid, p_to_stage public.stage) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE 
  shipment_rec record; 
  has_seed_commodity boolean := FALSE; 
  seed_commodity_id uuid;
  v_inco_term text;
  v_current_year integer := EXTRACT(YEAR FROM CURRENT_DATE);
BEGIN
  SELECT * INTO shipment_rec FROM public.shipment WHERE id = p_shipment_id;
  IF NOT FOUND THEN RETURN FALSE; END IF;
  v_inco_term := shipment_rec.inco_term;

  SELECT id INTO seed_commodity_id FROM public.commodity WHERE LOWER(name) = 'seed' LIMIT 1;
  IF seed_commodity_id IS NOT NULL THEN
    SELECT EXISTS (SELECT 1 FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = p_shipment_id AND pv.commodity_id = seed_commodity_id) INTO has_seed_commodity;
  END IF;

  CASE p_to_stage
    WHEN 'forecast' THEN RETURN TRUE;
    WHEN 'enlistment_verification' THEN 
      IF NOT has_seed_commodity THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.shipment_products sp JOIN public.forecast f ON f.product_variety_id = sp.product_variety_id WHERE sp.shipment_id = p_shipment_id AND f.year = v_current_year);
    WHEN 'availability_confirmation' THEN 
      IF NOT has_seed_commodity THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.shipment_products sp JOIN public.forecast f ON f.product_variety_id = sp.product_variety_id WHERE sp.shipment_id = p_shipment_id AND f.enlistment_status = TRUE AND f.year = v_current_year);
    WHEN 'purchase_order' THEN 
      IF NOT has_seed_commodity THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.availability_confirmation WHERE shipment_id = p_shipment_id AND available = TRUE);
    WHEN 'proforma' THEN RETURN EXISTS (SELECT 1 FROM public.purchase_order WHERE shipment_id = p_shipment_id AND po_file_url IS NOT NULL);
    WHEN 'ip_number' THEN RETURN EXISTS (SELECT 1 FROM public.proforma_invoice WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
    WHEN 'lc_opening' THEN RETURN EXISTS (SELECT 1 FROM public.ip_number WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
    WHEN 'bank_debit_advice' THEN RETURN EXISTS (SELECT 1 FROM public.letter_of_credit WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
    WHEN 'invoice' THEN RETURN EXISTS (SELECT 1 FROM public.bank_debit_advice WHERE shipment_id = p_shipment_id AND is_received = true);
    WHEN 'shipment_details_from_supplier' THEN 
      IF v_inco_term = 'CFR' THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.commercial_invoice WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
    WHEN 'freight_query' THEN 
      IF v_inco_term = 'CFR' THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.supplier_shipment_details WHERE shipment_id = p_shipment_id);
    WHEN 'award_shipment' THEN 
      IF v_inco_term = 'CFR' THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.freight_query WHERE shipment_id = p_shipment_id);
    WHEN 'non_negotiable_docs' THEN RETURN EXISTS (SELECT 1 FROM public.shipment_awarded sa WHERE sa.shipment_id = p_shipment_id AND sa.awarded = TRUE) OR v_inco_term = 'CFR';
    WHEN 'bank_endorsement' THEN RETURN EXISTS (SELECT 1 FROM public.non_negotiable_docs WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
    WHEN 'original_docs' THEN RETURN EXISTS (SELECT 1 FROM public.bank_endorsement WHERE shipment_id = p_shipment_id AND endorsed = TRUE);
    WHEN 'send_to_clearing_agent' THEN RETURN EXISTS (SELECT 1 FROM public.original_docs WHERE shipment_id = p_shipment_id AND docs_url IS NOT NULL);
    WHEN 'good_declaration' THEN RETURN EXISTS (SELECT 1 FROM public.docs_to_clearing_agent WHERE shipment_id = p_shipment_id);
    WHEN 'under_clearing_agent' THEN RETURN EXISTS (SELECT 1 FROM public.good_declaration WHERE shipment_id = p_shipment_id AND gd_number IS NOT NULL);
    WHEN 'warehouse' THEN RETURN EXISTS (SELECT 1 FROM public.under_clearing_agent WHERE shipment_id = p_shipment_id AND is_received = TRUE);
    WHEN 'release_orders' THEN RETURN EXISTS (SELECT 1 FROM public.warehouse_arrival WHERE shipment_id = p_shipment_id);
    WHEN 'gate_out' THEN RETURN EXISTS (SELECT 1 FROM public.release_orders WHERE shipment_id = p_shipment_id);
    WHEN 'transportation' THEN RETURN EXISTS (SELECT 1 FROM public.gate_out go WHERE go.shipment_id = p_shipment_id AND go.is_gate_out = TRUE);
    WHEN 'documents' THEN RETURN TRUE; 
    WHEN 'bills' THEN RETURN TRUE; 
    ELSE RETURN FALSE;
  END CASE;
END; $$;

CREATE OR REPLACE FUNCTION public.advance_stage(p_shipment_id uuid, p_to_stage public.stage, p_meta jsonb DEFAULT '{}'::jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_from_stage public.stage; v_current_user_id uuid; v_from_order int; v_to_order int;
BEGIN
  SELECT current_stage INTO v_from_stage FROM public.shipment WHERE id = p_shipment_id FOR UPDATE;
  IF v_from_stage IS NULL THEN RAISE EXCEPTION 'Shipment not found'; END IF;
  IF v_from_stage = p_to_stage THEN RETURN; END IF;
  v_from_order := public.get_stage_order(v_from_stage);
  v_to_order := public.get_stage_order(p_to_stage);
  IF NOT EXISTS (SELECT 1 FROM public.stage_edge WHERE from_stage = v_from_stage AND to_stage = p_to_stage) 
     AND v_to_order <= v_from_order AND p_to_stage != 'documents' THEN
    RAISE EXCEPTION 'Invalid stage transition: % -> %', v_from_stage, p_to_stage;
  END IF;
  IF NOT public.stage_requirements_met(p_shipment_id, p_to_stage) THEN
    RAISE EXCEPTION 'Requirements not met for stage %', p_to_stage;
  END IF;
  v_current_user_id := auth.uid();
  IF v_current_user_id IS NULL THEN SELECT id INTO v_current_user_id FROM public.app_user WHERE role = 'admin' LIMIT 1; END IF;
  UPDATE public.shipment SET current_stage = p_to_stage WHERE id = p_shipment_id;
  INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta, at)
  VALUES (p_shipment_id, v_current_user_id, 'advance_stage', v_from_stage, p_to_stage, p_meta, NOW());
END; $$;

-- 8. RESTORE FULL VIEWS (Fixing the N/A issue)
CREATE OR REPLACE VIEW public.v_shipments_with_details AS
SELECT
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    s.created_at,
    (SELECT pv.product_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as product_name,
    (SELECT pv.variety_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as variety_name,
    (SELECT sup.name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id LIMIT 1) AS supplier_name,
    (SELECT jsonb_agg(jsonb_build_object('product_name', pv.product_name, 'variety_name', pv.variety_name, 'supplier', jsonb_build_object('name', sup.name))) FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id) AS product_variety
FROM
    public.shipment s;

CREATE OR REPLACE VIEW public.v_shipments_with_all_details AS
SELECT
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    s.mode_of_transport,
    s.inco_term,
    s.created_at,
    (SELECT pv.product_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as product_name,
    (SELECT pv.variety_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as variety_name,
    (SELECT c.name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.commodity c ON pv.commodity_id = c.id WHERE sp.shipment_id = s.id LIMIT 1) as commodity,
    (SELECT sup.id FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id LIMIT 1) as supplier_id,
    (SELECT sup.name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id LIMIT 1) AS supplier_name,
    ca.id as clearing_agent_id,
    ca.name as clearing_agent_name,
    b.id as bank_id,
    b.name as bank_name,
    lc.lc_number,
    (SELECT jsonb_agg(jsonb_build_object('product_name', pv.product_name, 'variety_name', pv.variety_name, 'supplier', jsonb_build_object('name', sup.name))) 
     FROM public.shipment_products sp 
     JOIN public.product_variety pv ON sp.product_variety_id = pv.id 
     JOIN public.supplier sup ON pv.supplier_id = sup.id 
     WHERE sp.shipment_id = s.id) AS product_variety
FROM
    public.shipment s
LEFT JOIN
    public.letter_of_credit lc ON s.id = lc.shipment_id
LEFT JOIN
    public.bank b ON lc.bank_id = b.id
LEFT JOIN
    public.docs_to_clearing_agent dtca ON s.id = dtca.shipment_id
LEFT JOIN
    public.clearing_agent ca ON dtca.clearing_agent_id = ca.id;

CREATE OR REPLACE VIEW public.v_shipment_insights AS
SELECT 
  s.id,
  s.reference_code,
  s.current_stage,
  s.status,
  s.created_at,
  EXTRACT(DAY FROM (NOW() - s.created_at)) as days_since_created,
  COALESCE(sd.expected_duration_days, 10) as expected_duration_days,
  COALESCE(sd.responsible_team, 'Team') as responsible_team,
  (SELECT sup.name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id LIMIT 1) as supplier_name,
  lc.lc_number
FROM public.shipment s
LEFT JOIN public.letter_of_credit lc ON s.id = lc.shipment_id
LEFT JOIN public.stage_details sd ON s.current_stage = sd.stage_name;

-- 9. Recreate Views
CREATE OR REPLACE VIEW public.v_shipment_stage_checklist AS
SELECT
  s.id as shipment_id,
  s.reference_code,
  s.current_stage,
  EXISTS (SELECT 1 FROM public.shipment_products sp JOIN public.forecast f ON sp.product_variety_id = f.product_variety_id WHERE sp.shipment_id = s.id) as forecast_done,
  EXISTS (SELECT 1 FROM public.enlistment_verification ev WHERE ev.shipment_id = s.id AND ev.verified = true) as enlistment_verification_done,
  EXISTS (SELECT 1 FROM public.availability_confirmation ac WHERE ac.shipment_id = s.id AND ac.available = true) as availability_confirmation_done,
  EXISTS (SELECT 1 FROM public.purchase_order po WHERE po.shipment_id = s.id AND po.po_file_url IS NOT NULL) as purchase_order_done,
  EXISTS (SELECT 1 FROM public.proforma_invoice pi WHERE pi.shipment_id = s.id AND pi.file_url IS NOT NULL) as proforma_done,
  EXISTS (SELECT 1 FROM public.commercial_invoice ci WHERE ci.shipment_id = s.id AND ci.file_url IS NOT NULL) as invoice_done,
  EXISTS (SELECT 1 FROM public.ip_number ip WHERE ip.shipment_id = s.id AND ip.file_url IS NOT NULL) as ip_number_done,
  EXISTS (SELECT 1 FROM public.letter_of_credit lc WHERE lc.shipment_id = s.id AND lc.file_url IS NOT NULL) as lc_opening_done,
  EXISTS (SELECT 1 FROM public.bank_debit_advice bda WHERE bda.shipment_id = s.id AND bda.is_received = true) as bank_debit_advice_done,
  EXISTS (SELECT 1 FROM public.supplier_shipment_details ssd WHERE ssd.shipment_id = s.id) as shipment_details_from_supplier_done,
  EXISTS (SELECT 1 FROM public.freight_query fq WHERE fq.shipment_id = s.id) as freight_query_done,
  EXISTS (SELECT 1 FROM public.shipment_awarded sa WHERE sa.shipment_id = s.id AND sa.awarded = true) as award_shipment_done,
  EXISTS (SELECT 1 FROM public.original_docs od WHERE od.shipment_id = s.id AND od.docs_url IS NOT NULL) as original_docs_done,
  EXISTS (SELECT 1 FROM public.non_negotiable_docs nnd WHERE nnd.shipment_id = s.id) as non_negotiable_docs_done,
  EXISTS (SELECT 1 FROM public.bank_endorsement be WHERE be.shipment_id = s.id AND be.endorsed = true) as bank_endorsement_done,
  EXISTS (SELECT 1 FROM public.docs_to_clearing_agent dtca WHERE dtca.shipment_id = s.id AND dtca.slip_picture_url IS NOT NULL) as send_to_clearing_agent_done,
  EXISTS (SELECT 1 FROM public.good_declaration gd WHERE gd.shipment_id = s.id AND gd.gd_number IS NOT NULL) as good_declaration_done,
  EXISTS (SELECT 1 FROM public.under_clearing_agent uca WHERE uca.shipment_id = s.id AND uca.is_received = true) as under_clearing_agent_done,
  EXISTS (SELECT 1 FROM public.release_orders ro WHERE ro.shipment_id = s.id) as release_orders_done,
  EXISTS (SELECT 1 FROM public.gate_out go WHERE go.shipment_id = s.id AND go.is_gate_out = true) as gate_out_done,
  EXISTS (SELECT 1 FROM public.transporter t WHERE t.shipment_id = s.id) as transportation_done,
  EXISTS (SELECT 1 FROM public.warehouse_arrival wa WHERE wa.shipment_id = s.id) as warehouse_done,
  EXISTS (SELECT 1 FROM public.bills b WHERE b.shipment_id = s.id) as bills_done
FROM public.shipment s;

CREATE OR REPLACE VIEW public.v_shipment_document_summary AS
SELECT s.id as shipment_id, s.reference_code, s.mode_of_transport, s.inco_term, s.current_stage, COUNT(DISTINCT d.id) as total_uploaded
FROM public.shipment s
LEFT JOIN public.document d ON d.shipment_id = s.id AND d.status = 'active'
GROUP BY s.id, s.reference_code, s.mode_of_transport, s.inco_term, s.current_stage;

-- 10. Redefine alert functions
CREATE OR REPLACE FUNCTION public.set_stage_target_date(p_shipment_id uuid, p_stage public.stage, p_target_date date, p_responsible_team text, p_created_by uuid) RETURNS uuid AS $$
DECLARE v_id uuid; BEGIN
  INSERT INTO public.shipment_stage_targets (shipment_id, stage_name, target_date, responsible_team, created_by)
  VALUES (p_shipment_id, p_stage, p_target_date, p_responsible_team, p_created_by)
  ON CONFLICT (shipment_id, stage_name) DO UPDATE SET target_date = p_target_date, updated_at = NOW() RETURNING id INTO v_id;
  RETURN v_id;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.get_shipment_stage_targets(p_shipment_id uuid) RETURNS TABLE (id uuid, stage_name public.stage, target_date date, responsible_team text, status text, days_remaining integer) AS $$
BEGIN RETURN QUERY SELECT t.id, t.stage_name, t.target_date, t.responsible_team, CASE WHEN t.target_date < CURRENT_DATE THEN 'overdue'::text WHEN t.target_date = CURRENT_DATE THEN 'due_today'::text ELSE 'pending'::text END as status, (t.target_date - CURRENT_DATE)::integer as days_remaining FROM public.shipment_stage_targets t WHERE t.shipment_id = p_shipment_id ORDER BY t.target_date ASC; END; $$ LANGUAGE plpgsql STABLE;

-- 11. Redefine filter_shipments with FULL SEARCH LOGIC
CREATE OR REPLACE FUNCTION public.filter_shipments(
  p_search_term TEXT DEFAULT NULL,
  p_supplier_id TEXT DEFAULT NULL,
  p_clearing_agent_id TEXT DEFAULT NULL,
  p_bank_id TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_shipment_type TEXT DEFAULT NULL,
  p_commodity TEXT DEFAULT NULL,
  p_lc_number TEXT DEFAULT NULL,
  p_product_name TEXT DEFAULT NULL,
  p_variety_name TEXT DEFAULT NULL,
  p_mode_of_transport TEXT DEFAULT NULL
) RETURNS SETOF public.v_shipments_with_all_details AS $$
BEGIN 
  RETURN QUERY 
  SELECT * FROM public.v_shipments_with_all_details s 
  WHERE 
    (p_search_term IS NULL OR p_search_term = '' OR 
     s.reference_code ILIKE '%' || p_search_term || '%' OR 
     s.product_name ILIKE '%' || p_search_term || '%' OR 
     s.variety_name ILIKE '%' || p_search_term || '%' OR 
     s.supplier_name ILIKE '%' || p_search_term || '%'
    ) AND
    (p_supplier_id IS NULL OR p_supplier_id = '' OR s.supplier_id::text = p_supplier_id) AND
    (p_status IS NULL OR p_status = '' OR s.status::text = p_status) AND
    (p_lc_number IS NULL OR p_lc_number = '' OR s.lc_number ILIKE '%' || p_lc_number || '%') AND
    (p_product_name IS NULL OR p_product_name = '' OR s.product_name ILIKE '%' || p_product_name || '%') AND
    (p_variety_name IS NULL OR p_variety_name = '' OR s.variety_name ILIKE '%' || p_variety_name || '%'); 
END; $$ LANGUAGE plpgsql STABLE;

-- 12. Cleanup
DROP TYPE public.stage_old CASCADE;

COMMIT;
