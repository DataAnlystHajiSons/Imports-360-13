-- First, drop the existing view to avoid column name/type conflicts during replacement.
DROP VIEW IF EXISTS public.v_forecast_with_order_status;

-- Now, create the new version of the view with the correct columns and calculations.
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