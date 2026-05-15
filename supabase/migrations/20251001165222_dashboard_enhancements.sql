
-- Phase 1: Dashboard Enhancements

-- View to get top suppliers by active shipments
CREATE OR REPLACE VIEW public.v_top_suppliers_by_active_shipments AS
SELECT
    s.name AS supplier_name,
    COUNT(sh.id) AS active_shipments_count
FROM
    public.supplier s
JOIN
    public.product_variety pv ON s.id = pv.supplier_id
JOIN
    public.shipment_products sp ON pv.id = sp.product_variety_id
JOIN
    public.shipment sh ON sp.shipment_id = sh.id
WHERE
    sh.status = 'active'
GROUP BY
    s.name
ORDER BY
    active_shipments_count DESC
LIMIT 3;

-- Function to get shipment creation trend for the last 7 days
CREATE OR REPLACE FUNCTION public.get_shipment_trend_7_days()
RETURNS TABLE(day date, shipment_count bigint) AS $$
BEGIN
    RETURN QUERY
    WITH days AS (
        SELECT generate_series(
            (NOW() - interval '6 days')::date,
            NOW()::date,
            '1 day'::interval
        )::date AS day
    )
    SELECT
        d.day,
        COUNT(s.id)
    FROM
        days d
    LEFT JOIN
        public.shipment s ON s.created_at::date = d.day
    GROUP BY
        d.day
    ORDER BY
        d.day;
END;
$$ LANGUAGE plpgsql;

-- Function to get average shipment duration
CREATE OR REPLACE FUNCTION public.get_average_shipment_duration()
RETURNS numeric AS $$
DECLARE
    avg_duration numeric;
BEGIN
    SELECT
        AVG(EXTRACT(EPOCH FROM (al.created_at - s.created_at))) / 86400 -- in days
    INTO
        avg_duration
    FROM
        public.shipment s
    JOIN
        public.audit_log al ON s.id = al.shipment_id
    WHERE
        s.status = 'completed' AND al.to_stage = 'bills';

    RETURN COALESCE(avg_duration, 0);
END;
$$ LANGUAGE plpgsql;
