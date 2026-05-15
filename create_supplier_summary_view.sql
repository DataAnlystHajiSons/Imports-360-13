CREATE OR REPLACE VIEW public.v_supplier_shipment_summary AS
SELECT 
    s.id,
    s.name,
    s.contact_email,
    s.contact_phone,
    (SELECT json_agg(cp.*) FROM public.contact_person cp WHERE cp.supplier_id = s.id) AS contact_persons,
    (SELECT json_agg(so.*) FROM public.supplier_office so WHERE so.supplier_id = s.id) AS supplier_offices,
    COUNT(DISTINCT sh.id) AS total_shipments,
    COUNT(DISTINCT CASE WHEN sh.status = 'active' THEN sh.id END) AS active_shipments,
    COUNT(DISTINCT CASE WHEN sh.status = 'completed' THEN sh.id END) AS completed_shipments
FROM 
    public.supplier s
LEFT JOIN 
    public.product_variety pv ON s.id = pv.supplier_id
LEFT JOIN 
    public.shipment_products sp ON pv.id = sp.product_variety_id
LEFT JOIN 
    public.shipment sh ON sp.shipment_id = sh.id
GROUP BY 
    s.id;
