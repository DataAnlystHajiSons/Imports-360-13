-- Function to get supplier shipment statistics
DROP FUNCTION IF EXISTS get_supplier_shipment_stats(UUID);

CREATE OR REPLACE FUNCTION get_supplier_shipment_stats(supplier_id UUID)
RETURNS TABLE(
    total_shipments BIGINT,
    active_shipments BIGINT,
    completed_shipments BIGINT,
    on_time_shipments BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_shipments,
        COUNT(*) FILTER (WHERE s.status NOT IN ('completed', 'cancelled')) as active_shipments,
        COUNT(*) FILTER (WHERE s.status = 'completed') as completed_shipments,
        COUNT(*) FILTER (WHERE s.status = 'completed' AND s.current_stage = 'bills') as on_time_shipments
    FROM shipment s
    INNER JOIN shipment_products sp ON s.id = sp.shipment_id
    INNER JOIN product_variety pv ON sp.product_variety_id = pv.id
    WHERE pv.supplier_id = get_supplier_shipment_stats.supplier_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;