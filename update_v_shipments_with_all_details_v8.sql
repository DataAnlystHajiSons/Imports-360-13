DROP VIEW IF EXISTS public.v_shipments_with_all_details CASCADE;

CREATE OR REPLACE VIEW public.v_shipments_with_all_details AS
SELECT
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    s.type,
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
    (SELECT jsonb_agg(jsonb_build_object('product_name', pv.product_name, 'variety_name', pv.variety_name, 'supplier', jsonb_build_object('name', sup.name))) FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id) AS product_variety,
    (
        -- Calculate overall progress based on data presence across ALL 24 stage tables
        (CASE WHEN EXISTS (SELECT 1 FROM public.forecast f JOIN public.shipment_products sp ON f.product_variety_id = sp.product_variety_id WHERE sp.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.enlistment_verification ev WHERE ev.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.availability_confirmation ac WHERE ac.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.purchase_order po WHERE po.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.proforma_invoice pi WHERE pi.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.ip_number ip WHERE ip.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.letter_of_credit lc2 WHERE lc2.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.bank_debit_advice bda WHERE bda.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.commercial_invoice ci WHERE ci.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.supplier_shipment_details ssd WHERE ssd.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.freight_query fq WHERE fq.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.shipment_awarded sa WHERE sa.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.non_negotiable_docs nnd WHERE nnd.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.bank_endorsement be WHERE be.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.original_docs od WHERE od.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.docs_to_clearing_agent dtca2 WHERE dtca2.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.good_declaration gd WHERE gd.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.under_clearing_agent uca WHERE uca.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.warehouse_arrival wa WHERE wa.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.release_orders ro WHERE ro.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.gate_out go WHERE go.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.transporter t WHERE t.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.document d WHERE d.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.costing cst WHERE cst.shipment_id = s.id) THEN 1 ELSE 0 END)
    ) AS completed_milestones_count,
    24 AS total_milestones_count
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
