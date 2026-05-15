-- Drop the existing view first
DROP VIEW IF EXISTS public.v_forecast_with_order_status;

-- Recreate the view with new columns
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
    pv.unit,
    s.name AS supplier_name,
    COALESCE(
        (
            SELECT SUM(sp.quantity)
            FROM public.shipment_products sp
            WHERE sp.product_variety_id = f.product_variety_id
        ), 0
    ) AS ordered_qty,
    (f.forecast_qty - COALESCE(
        (
            SELECT SUM(sp.quantity)
            FROM public.shipment_products sp
            WHERE sp.product_variety_id = f.product_variety_id
        ), 0
    )) AS remaining_qty,
    EXISTS (
        SELECT 1
        FROM public.shipment_products sp
        WHERE sp.product_variety_id = f.product_variety_id
    ) AS order_status
FROM
    public.forecast f
    LEFT JOIN public.product_variety pv ON f.product_variety_id = pv.id
    LEFT JOIN public.supplier s ON pv.supplier_id = s.id;