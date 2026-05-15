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
