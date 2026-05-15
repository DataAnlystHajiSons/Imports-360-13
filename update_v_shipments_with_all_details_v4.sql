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
    (SELECT pv.commodity FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as commodity,
    (SELECT sup.id FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id LIMIT 1) as supplier_id,
    (SELECT sup.name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id LIMIT 1) AS supplier_name,
    ca.id as clearing_agent_id,
    ca.name as clearing_agent_name,
    b.id as bank_id,
    b.name as bank_name,
    lc.lc_number,
    (SELECT jsonb_agg(jsonb_build_object('product_name', pv.product_name, 'variety_name', pv.variety_name, 'supplier', jsonb_build_object('name', sup.name))) FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id) AS product_variety
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
