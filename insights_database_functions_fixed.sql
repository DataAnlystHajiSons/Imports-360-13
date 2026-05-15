-- ================================================
-- FIXED INSIGHTS SECTION DATABASE FUNCTIONS
-- Execute these functions in your Supabase SQL editor
-- ================================================

-- Function to get critical alerts (FIXED)
CREATE OR REPLACE FUNCTION get_critical_alerts()
RETURNS TABLE (
  type text,
  title text,
  subtitle text,
  reference_code text,
  priority text,
  created_at timestamp with time zone
) AS $$
BEGIN
  RETURN QUERY
  (
    -- Overdue shipments
    SELECT 
      'overdue'::text as type,
      ('Shipment ' || s.reference_code || ' overdue')::text as title,
      ('Expected delivery: ' || EXTRACT(DAY FROM (NOW() - s.created_at))::text || ' days ago')::text as subtitle,
      s.reference_code::text,
      CASE 
        WHEN EXTRACT(DAY FROM (NOW() - s.created_at)) > 7 THEN 'critical'::text
        WHEN EXTRACT(DAY FROM (NOW() - s.created_at)) > 3 THEN 'high'::text
        ELSE 'medium'::text
      END as priority,
      s.created_at
    FROM shipment s
    JOIN stage_details sd ON s.current_stage = sd.stage_name
    WHERE 
      s.status = 'active' 
      AND EXTRACT(DAY FROM (NOW() - s.created_at)) > sd.expected_duration_days
    ORDER BY EXTRACT(DAY FROM (NOW() - s.created_at)) DESC
    LIMIT 3
  )
  
  UNION ALL
  
  (
    -- Expiring LCs
    SELECT 
      'lc_expiring'::text as type,
      ('LC expiring in ' || EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW()))::text || ' days')::text as title,
      (lc.lc_number || ' requires attention')::text as subtitle,
      s.reference_code::text,
      CASE 
        WHEN EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) <= 2 THEN 'critical'::text
        WHEN EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) <= 5 THEN 'high'::text
        ELSE 'medium'::text
      END as priority,
      bc.created_at
    FROM letter_of_credit lc
    JOIN shipment s ON lc.shipment_id = s.id
    JOIN bank_charges bc ON s.id = bc.shipment_id
    WHERE 
      bc.lc_issuance_date IS NOT NULL
      AND bc.lc_issuance_date + INTERVAL '30 days' <= NOW() + INTERVAL '7 days'
      AND s.status = 'active'
    ORDER BY EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) ASC
    LIMIT 2
  )
  
  UNION ALL
  
  (
    -- Pending documentation
    SELECT DISTINCT
      'pending_docs'::text as type,
      'Documentation pending'::text as title,
      (COUNT(s.id) OVER() || ' shipments await clearance docs')::text as subtitle,
      ''::text as reference_code,
      'medium'::text as priority,
      MAX(s.created_at) OVER() as created_at
    FROM shipment s
    LEFT JOIN document d ON s.id = d.shipment_id
    WHERE 
      s.status = 'active'
      AND s.current_stage IN ('non_negotiable_docs', 'original_docs', 'send_to_clearing_agent')
      AND d.id IS NULL
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql;

-- Function to get business warnings (FIXED)
CREATE OR REPLACE FUNCTION get_business_warnings()
RETURNS TABLE (
  type text,
  title text,
  subtitle text,
  reference_code text,
  priority text,
  created_at timestamp with time zone
) AS $$
BEGIN
  RETURN QUERY
  (
    -- Supplier capacity warnings
    SELECT 
      'supplier_capacity'::text as type,
      'Supplier availability low'::text as title,
      (sup.name || ' capacity at ' || ROUND(COUNT(DISTINCT s.id) * 100.0 / 10, 0)::text || '%')::text as subtitle,
      ''::text as reference_code,
      'warning'::text as priority,
      MAX(s.created_at) as created_at
    FROM supplier sup
    JOIN product_variety pv ON sup.id = pv.supplier_id
    JOIN shipment_products sp ON pv.id = sp.product_variety_id
    JOIN shipment s ON sp.shipment_id = s.id
    WHERE s.status = 'active'
    GROUP BY sup.id, sup.name
    HAVING COUNT(DISTINCT s.id) >= 5
    ORDER BY COUNT(DISTINCT s.id) DESC
    LIMIT 1
  )
  
  UNION ALL
  
  (
    -- Stage bottlenecks
    SELECT 
      'stage_bottleneck'::text as type,
      'Stage bottleneck detected'::text as title,
      (COUNT(*)::text || ' shipments in ' || REPLACE(s.current_stage::text, '_', ' ') || ' (' || sd.responsible_department || ')')::text as subtitle,
      ''::text as reference_code,
      'warning'::text as priority,
      MAX(s.created_at) as created_at
    FROM shipment s
    JOIN stage_details sd ON s.current_stage = sd.stage_name
    WHERE s.status = 'active'
    GROUP BY s.current_stage, sd.responsible_department
    HAVING COUNT(*) > 3
    ORDER BY COUNT(*) DESC
    LIMIT 1
  )
  
  UNION ALL
  
  (
    -- Missing shipment details
    SELECT 
      'missing_details'::text as type,
      'Supplier details missing'::text as title,
      (COUNT(s.id)::text || ' shipments need supplier information')::text as subtitle,
      ''::text as reference_code,
      'warning'::text as priority,
      MAX(s.created_at) as created_at
    FROM shipment s
    LEFT JOIN supplier_shipment_details ssd ON s.id = ssd.shipment_id
    WHERE 
      s.status = 'active'
      AND s.current_stage = 'shipment_details_from_supplier'
      AND ssd.id IS NULL
    GROUP BY s.current_stage
    HAVING COUNT(s.id) > 0
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql;

-- Function to get business insights (FIXED)
CREATE OR REPLACE FUNCTION get_business_insights()
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
  FROM shipment s
  WHERE s.status = 'completed'
    AND s.updated_at >= DATE_TRUNC('month', NOW());
    
  SELECT COUNT(*) INTO previous_month_count
  FROM shipment s
  WHERE s.status = 'completed'
    AND s.updated_at >= DATE_TRUNC('month', NOW() - INTERVAL '1 month')
    AND s.updated_at < DATE_TRUNC('month', NOW());
    
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
    FROM supplier sup
    JOIN product_variety pv ON sup.id = pv.supplier_id
    JOIN shipment_products sp ON pv.id = sp.product_variety_id
    JOIN shipment s ON sp.shipment_id = s.id
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
      FROM shipment
      WHERE created_at >= NOW() - INTERVAL '12 months'
      GROUP BY DATE_TRUNC('month', created_at)
    ) monthly_stats
    HAVING AVG(monthly_count) > 0
    LIMIT 1
  );
END;
$$ LANGUAGE plpgsql;

-- Simple function to test basic data retrieval
CREATE OR REPLACE FUNCTION get_simple_alerts()
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
  FROM shipment 
  WHERE status = 'active'
  
  UNION ALL
  
  SELECT 
    'completed_shipments'::text as alert_type,
    'Completed shipments this month'::text as message,
    COUNT(*)::integer as count_value
  FROM shipment 
  WHERE status = 'completed' 
    AND updated_at >= DATE_TRUNC('month', NOW())
  
  UNION ALL
  
  SELECT 
    'total_suppliers'::text as alert_type,
    'Total suppliers in system'::text as message,
    COUNT(*)::integer as count_value
  FROM supplier;
END;
$$ LANGUAGE plpgsql;

-- Create a simplified view for quick access
CREATE OR REPLACE VIEW v_dashboard_summary AS
SELECT 
  (SELECT COUNT(*) FROM shipment WHERE status = 'active') as active_shipments,
  (SELECT COUNT(*) FROM shipment WHERE status = 'completed') as completed_shipments,
  (SELECT COUNT(*) FROM supplier) as total_suppliers,
  (SELECT COUNT(*) FROM shipment WHERE status = 'active' AND created_at < NOW() - INTERVAL '7 days') as potentially_overdue;

-- Grant permissions (uncomment and adjust role as needed)
-- GRANT EXECUTE ON FUNCTION get_critical_alerts() TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_business_warnings() TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_business_insights() TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_simple_alerts() TO authenticated;
-- GRANT SELECT ON v_dashboard_summary TO authenticated;