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
        -- Calculate overall progress based on the exact strict criteria defined in v_shipment_stage_checklist
        (CASE WHEN chk.forecast_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.enlistment_verification_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.availability_confirmation_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.purchase_order_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.proforma_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.ip_number_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.lc_opening_done THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.bank_debit_advice bda WHERE bda.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN chk.invoice_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.shipment_details_from_supplier_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.freight_query_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.award_shipment_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.non_negotiable_docs_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.bank_endorsement_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.original_docs_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.send_to_clearing_agent_done THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.good_declaration gd WHERE gd.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN chk.under_clearing_agent_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.warehouse_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.release_orders_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.gate_out_done THEN 1 ELSE 0 END) +
        (CASE WHEN chk.transportation_done THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.document d WHERE d.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN chk.bills_done THEN 1 ELSE 0 END)
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
    public.clearing_agent ca ON dtca.clearing_agent_id = ca.id
LEFT JOIN
    public.v_shipment_stage_checklist chk ON s.id = chk.shipment_id;
