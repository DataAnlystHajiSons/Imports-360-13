-- 19_fix_insights_updated_at_column.sql
-- This migration fixes the get_business_insights() and get_simple_alerts() RPC functions by replacing the non-existent 'updated_at' column on 'shipment' table with 'created_at'.

BEGIN;

-- 1. Recreate get_business_insights() with correct columns
CREATE OR REPLACE FUNCTION public.get_business_insights()
RETURNS TABLE (
  type text,
  title text,
  subtitle text,
  reference_code text,
  priority text,
  created_at timestamp with time zone
) AS $$
DECLARE
  current_month_count integer;
  previous_month_count integer;
  improvement_percentage numeric;
BEGIN
  -- Calculate performance improvement
  SELECT COUNT(*) INTO current_month_count
  FROM public.shipment s
  WHERE s.status = 'completed'
    AND s.created_at >= DATE_TRUNC('month', NOW());
    
  SELECT COUNT(*) INTO previous_month_count
  FROM public.shipment s
  WHERE s.status = 'completed'
    AND s.created_at >= DATE_TRUNC('month', NOW() - INTERVAL '1 month')
    AND s.created_at < DATE_TRUNC('month', NOW());
    
  improvement_percentage := CASE 
    WHEN previous_month_count > 0 THEN 
      ROUND(((current_month_count - previous_month_count) * 100.0 / previous_month_count), 0)
    ELSE 0
  END;

  RETURN QUERY
  (
    -- Performance insights
    SELECT 
      'performance'::text as type,
      CASE 
        WHEN improvement_percentage > 0 THEN ('Efficiency improved ' || improvement_percentage::text || '%')::text
        WHEN improvement_percentage < 0 THEN ('Efficiency declined ' || ABS(improvement_percentage)::text || '%')::text
        ELSE 'Performance stable'::text
      END as title,
      'Processing time compared to last month'::text as subtitle,
      ''::text as reference_code,
      CASE 
        WHEN improvement_percentage > 0 THEN 'positive'::text
        WHEN improvement_percentage < 0 THEN 'neutral'::text
        ELSE 'neutral'::text
      END as priority,
      NOW() as created_at
    WHERE current_month_count > 0 OR previous_month_count > 0
  )
  
  UNION ALL
  
  (
    -- Top performing suppliers
    SELECT 
      'top_supplier'::text as type,
      ('Top performer: ' || sup.name)::text as title,
      (ROUND(COUNT(CASE WHEN s.status = 'completed' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 0)::text || '% completion rate')::text as subtitle,
      ''::text as reference_code,
      'positive'::text as priority,
      MAX(s.created_at) as created_at
    FROM public.supplier sup
    JOIN public.product_variety pv ON sup.id = pv.supplier_id
    JOIN public.shipment_products sp ON pv.id = sp.product_variety_id
    JOIN public.shipment s ON sp.shipment_id = s.id
    WHERE s.created_at >= NOW() - INTERVAL '3 months'
    GROUP BY sup.id, sup.name
    HAVING COUNT(*) >= 2
    ORDER BY COUNT(CASE WHEN s.status = 'completed' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0) DESC
    LIMIT 1
  )
  
  UNION ALL
  
  (
    -- Seasonal insights
    SELECT 
      'seasonal'::text as type,
      'Peak season preparation'::text as title,
      ('Historical data shows ' || COALESCE(ROUND(AVG(monthly_count) * 1.4, 0), 0)::text || ' shipments expected next month')::text as subtitle,
      ''::text as reference_code,
      'neutral'::text as priority,
      NOW() as created_at
    FROM (
      SELECT 
        DATE_TRUNC('month', created_at) as month,
        COUNT(*) as monthly_count
      FROM public.shipment
      WHERE created_at >= NOW() - INTERVAL '12 months'
      GROUP BY DATE_TRUNC('month', created_at)
    ) monthly_stats
    HAVING AVG(monthly_count) > 0
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql STABLE;


-- 2. Recreate get_simple_alerts() with correct columns
CREATE OR REPLACE FUNCTION public.get_simple_alerts()
RETURNS TABLE (
  alert_type text,
  message text,
  count_value integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    'active_shipments'::text as alert_type,
    'Active shipments in system'::text as message,
    COUNT(*)::integer as count_value
  FROM public.shipment 
  WHERE status = 'active'
  
  UNION ALL
  
  SELECT 
    'completed_shipments'::text as alert_type,
    'Completed shipments this month'::text as message,
    COUNT(*)::integer as count_value
  FROM public.shipment 
  WHERE status = 'completed' 
    AND created_at >= DATE_TRUNC('month', NOW())
  
  UNION ALL
  
  SELECT 
    'total_suppliers'::text as alert_type,
    'Total suppliers in system'::text as message,
    COUNT(*)::integer as count_value
  FROM public.supplier;
END;
$$ LANGUAGE plpgsql STABLE;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';

COMMIT;
