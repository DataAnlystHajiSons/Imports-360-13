CREATE OR REPLACE FUNCTION get_product_yoy_history(p_product_variety_id uuid)
RETURNS json AS $$
DECLARE
    result json;
BEGIN
    WITH forecast_history AS (
        SELECT
            year,
            SUM(forecast_qty) as total_forecast
        FROM
            public.forecast
        WHERE
            product_variety_id = p_product_variety_id
        GROUP BY
            year
    ),
    ordered_history AS (
        SELECT
            EXTRACT(YEAR FROM s.created_at)::integer as year,
            SUM(sp.quantity) as total_ordered
        FROM
            public.shipment_products sp
        JOIN
            public.shipment s ON sp.shipment_id = s.id
        WHERE
            sp.product_variety_id = p_product_variety_id
        GROUP BY
            EXTRACT(YEAR FROM s.created_at)
    )
    SELECT
        json_agg(
            json_build_object(
                'year', COALESCE(fh.year, oh.year),
                'forecast_qty', COALESCE(fh.total_forecast, 0),
                'ordered_qty', COALESCE(oh.total_ordered, 0)
            )
            ORDER BY COALESCE(fh.year, oh.year) ASC
        )
    INTO
        result
    FROM
        forecast_history fh
    FULL OUTER JOIN
        ordered_history oh ON fh.year = oh.year;

    RETURN COALESCE(result, '[]'::json);
END;
$$ LANGUAGE plpgsql;
