-- ============================================
-- Recreate v_forecast_with_order_status View
-- ============================================
-- This view was dropped during LC stage merge and needs to be recreated

-- Drop the view if it exists
DROP VIEW IF EXISTS public.v_forecast_with_order_status CASCADE;

-- Create the view with all necessary columns and calculations
CREATE VIEW public.v_forecast_with_order_status AS
SELECT
    f.id,
    f.year,
    f.product_variety_id,
    f.forecast_qty,
    f.created_at,
    f.date_of_sowing,
    f.dos_alert_sent,
    f.enlistment_status,
    COALESCE(ordered.ordered_qty, 0) AS ordered_qty,
    (f.forecast_qty - COALESCE(ordered.ordered_qty, 0)) AS remaining_qty,
    (ordered.ordered_qty > 0) AS order_status
FROM
    public.forecast f
LEFT JOIN (
    SELECT
        sp.product_variety_id,
        SUM(sp.quantity) AS ordered_qty
    FROM
        public.shipment_products sp
    GROUP BY
        sp.product_variety_id
) AS ordered ON f.product_variety_id = ordered.product_variety_id;

-- Grant permissions
GRANT SELECT ON public.v_forecast_with_order_status TO authenticated;

-- Verification
SELECT '✅ View v_forecast_with_order_status recreated successfully!' as result;

-- Show sample data
SELECT 
    id,
    year,
    product_variety_id,
    forecast_qty,
    ordered_qty,
    remaining_qty,
    order_status,
    enlistment_status
FROM public.v_forecast_with_order_status
LIMIT 3;
