
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

-- Phase 2: Data Visualization and Trends

-- Function to get shipment status distribution
CREATE OR REPLACE FUNCTION public.get_shipment_status_distribution()
RETURNS TABLE(status text, shipment_count bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.status,
        COUNT(s.id)
    FROM
        public.shipment s
    GROUP BY
        s.status;
END;
$$ LANGUAGE plpgsql;

-- Function to get monthly shipment creation for the last 12 months
CREATE OR REPLACE FUNCTION public.get_monthly_shipment_creation()
RETURNS TABLE(month text, shipment_count bigint) AS $$
BEGIN
    RETURN QUERY
    WITH months AS (
        SELECT to_char(generate_series(
            (NOW() - interval '11 months'),
            NOW(),
            '1 month'::interval
        ), 'YYYY-MM') AS month
    )
    SELECT
        m.month,
        COUNT(s.id)
    FROM
        months m
    LEFT JOIN
        public.shipment s ON to_char(s.created_at, 'YYYY-MM') = m.month
    GROUP BY
        m.month
    ORDER BY
        m.month;
END;
$$ LANGUAGE plpgsql;

-- Function to get average duration for each stage
CREATE OR REPLACE FUNCTION public.get_average_stage_duration()
RETURNS TABLE(stage public.stage, avg_duration_days numeric) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        from_stage as stage,
        COALESCE(AVG(EXTRACT(EPOCH FROM (lead(created_at) OVER (PARTITION BY shipment_id ORDER BY created_at))) - EXTRACT(EPOCH FROM created_at)) / 86400, 0)
    FROM 
        public.audit_log
    GROUP BY
        from_stage;
END;
$$ LANGUAGE plpgsql;

-- Phase 3: Actionable Insights

-- Function to get shipments with upcoming deadlines
CREATE OR REPLACE FUNCTION public.get_shipments_with_upcoming_deadlines()
RETURNS TABLE(shipment_id uuid, reference_code text, deadline_type text, due_date date) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id,
        s.reference_code,
        'Payment Due' AS deadline_type,
        od.payment_date AS due_date
    FROM
        public.shipment s
    JOIN
        public.original_docs od ON s.id = od.shipment_id
    WHERE
        od.payment_date >= NOW()::date AND od.payment_date <= (NOW() + interval '14 days')::date
    UNION
    SELECT
        s.id,
        s.reference_code,
        'LC Expiry' AS deadline_type,
        lc.expiry_date AS due_date
    FROM
        public.shipment s
    JOIN
        public.letter_of_credit lc ON s.id = lc.shipment_id
    WHERE
        lc.expiry_date >= NOW()::date AND lc.expiry_date <= (NOW() + interval '14 days')::date;
END;
$$ LANGUAGE plpgsql;

-- Function to get shipments needing attention
CREATE OR REPLACE FUNCTION public.get_shipments_needing_attention()
RETURNS TABLE(shipment_id uuid, reference_code text, current_stage public.stage) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id,
        s.reference_code,
        s.current_stage
    FROM
        public.shipment s
    WHERE
        s.current_stage IN ('proforma', 'purchase_order', 'lc_opening', 'freight_query');
END;
$$ LANGUAGE plpgsql;

-- View for recent dashboard events
CREATE OR REPLACE VIEW public.v_recent_dashboard_events AS
SELECT
    al.id,
    al.created_at,
    s.reference_code,
    au.full_name AS actor_name,
    al.action,
    al.from_stage,
    al.to_stage
FROM
    public.audit_log al
JOIN
    public.shipment s ON al.shipment_id = s.id
LEFT JOIN
    public.app_user au ON al.actor_id = au.id
ORDER BY
    al.created_at DESC
LIMIT 10;
