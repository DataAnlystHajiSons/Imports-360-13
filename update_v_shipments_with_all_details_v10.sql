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
        -- Calculate overall progress based on the EXACT strict criteria defined in the tracker's STAGE_CONFIG javascript
        (CASE WHEN EXISTS (SELECT 1 FROM public.forecast t JOIN public.shipment_products sp ON t.product_variety_id = sp.product_variety_id WHERE sp.shipment_id = s.id AND t.year IS NOT NULL AND t.forecast_qty IS NOT NULL AND t.date_of_sowing IS NOT NULL AND t.enlistment_status IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.enlistment_verification t WHERE t.shipment_id = s.id AND t.verified IS NOT NULL AND t.verification_notes IS NOT NULL AND t.verification_notes::text <> '' AND t.verified_at IS NOT NULL AND t.verifier_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.availability_confirmation t WHERE t.shipment_id = s.id AND t.available IS NOT NULL AND t.notes IS NOT NULL AND t.notes::text <> '' AND t.confirmed_at IS NOT NULL AND t.confirmed_by IS NOT NULL AND t.supplier_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.purchase_order t WHERE t.shipment_id = s.id AND t.po_number IS NOT NULL AND t.po_number::text <> '' AND t.po_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.proforma_invoice t WHERE t.shipment_id = s.id AND t.proforma_number IS NOT NULL AND t.proforma_number::text <> '' AND t.proforma_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.ip_number t WHERE t.shipment_id = s.id AND t.issued_date IS NOT NULL AND t.references IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.letter_of_credit t WHERE t.shipment_id = s.id AND t.lc_number IS NOT NULL AND t.lc_number::text <> '' AND t.opened_date IS NOT NULL AND t.lc_shared_date IS NOT NULL AND t.notes IS NOT NULL AND t.notes::text <> '' AND t.bank_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.bank_debit_advice t WHERE t.shipment_id = s.id AND t.is_received IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.commercial_invoice t WHERE t.shipment_id = s.id AND t.invoice_number IS NOT NULL AND t.invoice_number::text <> '' AND t.invoice_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.supplier_shipment_details t WHERE t.shipment_id = s.id AND t.readiness_date IS NOT NULL AND t.address IS NOT NULL AND t.address::text <> '' AND t.origin IS NOT NULL AND t.origin::text <> '' AND t.transport IS NOT NULL AND t.inco_terms IS NOT NULL AND t.container_type IS NOT NULL AND t.cartons_count IS NOT NULL AND t.gross_weight IS NOT NULL AND t.net_weight IS NOT NULL AND t.length IS NOT NULL AND t.width IS NOT NULL AND t.height IS NOT NULL AND t.details_received_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.freight_query t WHERE t.shipment_id = s.id AND t.logistics_company_id IS NOT NULL AND t.sent_at IS NOT NULL AND t.term IS NOT NULL AND t.shipment_from IS NOT NULL AND t.shipment_from::text <> '' AND t.destination IS NOT NULL AND t.destination::text <> '' AND t.origin IS NOT NULL AND t.origin::text <> '' AND t.readiness_date IS NOT NULL AND t.gross_weight IS NOT NULL AND t.net_weight IS NOT NULL AND t.chargeable_weight IS NOT NULL AND t.no_of_cartoons IS NOT NULL AND t.pick_up_address IS NOT NULL AND t.pick_up_address::text <> '' AND t.remarks IS NOT NULL AND t.remarks::text <> '') THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.shipment_awarded t WHERE t.shipment_id = s.id AND t.awarded IS NOT NULL AND t.notes IS NOT NULL AND t.notes::text <> '' AND t.freight_quote_response_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.non_negotiable_docs t WHERE t.shipment_id = s.id AND t.status IS NOT NULL AND t.sended_at IS NOT NULL AND t.uploaded_by IS NOT NULL AND t.bank_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.bank_endorsement t WHERE t.shipment_id = s.id AND t.endorsed IS NOT NULL AND t.endorsed_at IS NOT NULL AND t.updated_by IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.original_docs t WHERE t.shipment_id = s.id AND t.status IS NOT NULL AND t.status::text <> '' AND t.received_at IS NOT NULL AND t.bl_date IS NOT NULL AND t.uploaded_by IS NOT NULL AND t.shipping_company IS NOT NULL AND t.shipping_company::text <> '' AND t.tracking_number IS NOT NULL AND t.tracking_number::text <> '' AND t.shipping_guarantee_applied_date IS NOT NULL AND t.shipping_guarantee_received_date IS NOT NULL AND t.dispatch_date IS NOT NULL AND t.arrival_at_bank IS NOT NULL AND t.due_date IS NOT NULL AND t.payment_date IS NOT NULL AND t.bank_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.docs_to_clearing_agent t WHERE t.shipment_id = s.id AND t.name IS NOT NULL AND t.name::text <> '' AND t.shipping_company IS NOT NULL AND t.shipping_company::text <> '' AND t.tracking_number IS NOT NULL AND t.tracking_number::text <> '' AND t.sended_at IS NOT NULL AND t.expected_arrival_date IS NOT NULL AND t.clearing_agent_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.good_declaration t WHERE t.shipment_id = s.id AND t.gd_number IS NOT NULL AND t.gd_number::text <> '' AND t.gd_date IS NOT NULL AND t.gd_file_date IS NOT NULL AND t.clearing_agent_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.under_clearing_agent t WHERE t.shipment_id = s.id AND t.is_received IS NOT NULL AND t.receiving_date IS NOT NULL AND t.destuffed_date IS NOT NULL AND t.frsd_application_date IS NOT NULL AND t.duty_payment_date IS NOT NULL AND t.sampling_date IS NOT NULL AND t.do_date IS NOT NULL AND t.clearing_agent_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.warehouse_arrival t WHERE t.shipment_id = s.id AND t.warehouse_id IS NOT NULL AND t.arrival_date IS NOT NULL AND t.gr_no IS NOT NULL AND t.gr_no::text <> '' AND t.updated_by IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.release_orders t WHERE t.shipment_id = s.id AND t.dpp_ro_number IS NOT NULL AND t.dpp_ro_number::text <> '' AND t.dpp_date IS NOT NULL AND t.fscrd_ro_number IS NOT NULL AND t.fscrd_ro_number::text <> '' AND t.fscrd_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.gate_out t WHERE t.shipment_id = s.id AND t.is_gate_out IS NOT NULL AND t.gate_out_date IS NOT NULL AND t.updated_by IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.transporter t WHERE t.shipment_id = s.id AND t.transporter_name IS NOT NULL AND t.transporter_name::text <> '' AND t.bilti_number IS NOT NULL AND t.bilti_number::text <> '' AND t.bilti_date IS NOT NULL AND t.no_of_pieces IS NOT NULL AND t.updated_by IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.document d WHERE d.shipment_id = s.id) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.costing t WHERE t.shipment_id = s.id AND t.final_payment IS NOT NULL AND t.invoice_charges IS NOT NULL AND t.exchange_rate IS NOT NULL AND t.ip_charges IS NOT NULL AND t.bank_contract_opening_charges IS NOT NULL AND t.shipping_guarantee IS NOT NULL AND t.fbr_duty IS NOT NULL AND t.forwarder_charges IS NOT NULL AND t.clearing_charges IS NOT NULL AND t.local_transporter IS NOT NULL AND t.port_charges IS NOT NULL AND t.final_payment_charges IS NOT NULL AND t.total IS NOT NULL AND t.total_cost IS NOT NULL AND t.oh_perc IS NOT NULL AND t.qty IS NOT NULL AND t.per_unit_rate IS NOT NULL) THEN 1 ELSE 0 END)
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
