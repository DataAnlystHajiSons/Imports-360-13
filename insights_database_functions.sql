-- ================================================
-- INSIGHTS SECTION DATABASE FUNCTIONS
-- Execute these functions in your Supabase SQL editor
-- ================================================

-- Function to get critical alerts
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
  -- Overdue shipments
  SELECT 
    'overdue' as type,
    'Shipment ' || s.reference_code || ' overdue' as title,
    'Expected delivery: ' || EXTRACT(DAY FROM (NOW() - s.created_at))::text || ' days ago' as subtitle,
    s.reference_code,
    CASE 
      WHEN EXTRACT(DAY FROM (NOW() - s.created_at)) > 7 THEN 'critical'
      WHEN EXTRACT(DAY FROM (NOW() - s.created_at)) > 3 THEN 'high'
      ELSE 'medium'
    END as priority,
    s.created_at
  FROM shipment s
  JOIN stage_details sd ON s.current_stage = sd.stage_name
  WHERE 
    s.status = 'active' 
    AND EXTRACT(DAY FROM (NOW() - s.created_at)) > sd.expected_duration_days
  ORDER BY EXTRACT(DAY FROM (NOW() - s.created_at)) DESC
  LIMIT 3
  
  UNION ALL
  
  -- Expiring LCs
  SELECT 
    'lc_expiring' as type,
    'LC expiring in ' || EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW()))::text || ' days' as title,
    lc.lc_number || ' requires attention' as subtitle,
    s.reference_code,
    CASE 
      WHEN EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) <= 2 THEN 'critical'
      WHEN EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) <= 5 THEN 'high'
      ELSE 'medium'
    END as priority,
    bc.created_at
  FROM letter_of_credit lc
  JOIN shipment s ON lc.shipment_id = s.id
  JOIN bank_charges bc ON s.id = bc.shipment_id
  WHERE 
    bc.lc_issuance_date + INTERVAL '30 days' <= NOW() + INTERVAL '7 days'
    AND s.status = 'active'
  ORDER BY EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW())) ASC
  LIMIT 2
  
  UNION ALL
  
  -- Pending documentation
  SELECT 
    'pending_docs' as type,
    'Documentation pending' as title,
    COUNT(s.id)::text || ' shipments await clearance docs' as subtitle,
    '' as reference_code,
    'medium' as priority,
    MAX(s.created_at) as created_at
  FROM shipment s
  LEFT JOIN document d ON s.id = d.shipment_id
  WHERE 
    s.status = 'active'
    AND s.current_stage IN ('non_negotiable_docs', 'original_docs', 'send_to_clearing_agent')
    AND d.id IS NULL
  GROUP BY s.current_stage
  HAVING COUNT(s.id) > 0
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get business warnings
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
  -- Supplier capacity warnings
  SELECT 
    'supplier_capacity' as type,
    'Supplier availability low' as title,
    sup.name || ' capacity at ' || ROUND(COUNT(DISTINCT s.id) * 100.0 / 10, 0)::text || '%' as subtitle,
    '' as reference_code,
    'warning' as priority,
    MAX(s.created_at) as created_at
  FROM supplier sup
  JOIN product_variety pv ON sup.id = pv.supplier_id
  JOIN shipment_products sp ON pv.id = sp.product_variety_id
  JOIN shipment s ON sp.shipment_id = s.id
  WHERE s.status = 'active'
  GROUP BY sup.id, sup.name
  HAVING COUNT(DISTINCT s.id) >= 7
  ORDER BY COUNT(DISTINCT s.id) DESC
  LIMIT 1
  
  UNION ALL
  
  -- Stage bottlenecks
  SELECT 
    'stage_bottleneck' as type,
    'Stage bottleneck detected' as title,
    COUNT(*)::text || ' shipments in ' || REPLACE(s.current_stage::text, '_', ' ') as subtitle,
    '' as reference_code,
    'warning' as priority,
    MAX(s.updated_at) as created_at
  FROM shipment s
  WHERE s.status = 'active'
  GROUP BY s.current_stage
  HAVING COUNT(*) > 3
  ORDER BY COUNT(*) DESC
  LIMIT 1
  
  UNION ALL
  
  -- Missing shipment details
  SELECT 
    'missing_details' as type,
    'Supplier details missing' as title,
    COUNT(s.id)::text || ' shipments need supplier information' as subtitle,
    '' as reference_code,
    'warning' as priority,
    MAX(s.created_at) as created_at
  FROM shipment s
  LEFT JOIN supplier_shipment_details ssd ON s.id = ssd.shipment_id
  WHERE 
    s.status = 'active'
    AND s.current_stage = 'shipment_details_from_supplier'
    AND ssd.id IS NULL
  GROUP BY s.current_stage
  HAVING COUNT(s.id) > 0
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get business insights
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
  -- Performance insights
  SELECT 
    'performance' as type,
    CASE 
      WHEN improvement_percentage > 0 THEN 'Efficiency improved ' || improvement_percentage::text || '%'
      WHEN improvement_percentage < 0 THEN 'Efficiency declined ' || ABS(improvement_percentage)::text || '%'
      ELSE 'Performance stable'
    END as title,
    'Processing time compared to last month' as subtitle,
    '' as reference_code,
    CASE 
      WHEN improvement_percentage > 0 THEN 'positive'
      WHEN improvement_percentage < 0 THEN 'neutral'
      ELSE 'neutral'
    END as priority,
    NOW() as created_at
  WHERE current_month_count > 0 OR previous_month_count > 0
  
  UNION ALL
  
  -- Top performing suppliers
  SELECT 
    'top_supplier' as type,
    'Top performer: ' || sup.name as title,
    ROUND(COUNT(CASE WHEN s.status = 'completed' THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0), 0)::text || '% completion rate' as subtitle,
    '' as reference_code,
    'positive' as priority,
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
  
  UNION ALL
  
  -- Seasonal insights
  SELECT 
    'seasonal' as type,
    'Peak season preparation' as title,
    'Historical data shows ' || ROUND(AVG(monthly_count) * 1.4, 0)::text || ' shipments expected next month' as subtitle,
    '' as reference_code,
    'neutral' as priority,
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
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get insights counts
CREATE OR REPLACE FUNCTION get_insights_counts()
RETURNS TABLE (
  alerts_count bigint,
  warnings_count bigint,
  insights_count bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COUNT(*) FROM get_critical_alerts()) as alerts_count,
    (SELECT COUNT(*) FROM get_business_warnings()) as warnings_count,
    (SELECT COUNT(*) FROM get_business_insights()) as insights_count;
END;
$$ LANGUAGE plpgsql;

-- Create a view for quick shipment overview
CREATE OR REPLACE VIEW v_shipment_insights AS
SELECT 
  s.id,
  s.reference_code,
  s.current_stage,
  s.status,
  s.created_at,
  s.updated_at,
  EXTRACT(DAY FROM (NOW() - s.created_at)) as days_since_created,
  sd.expected_duration_days,
  sd.responsible_team,
  CASE 
    WHEN EXTRACT(DAY FROM (NOW() - s.created_at)) > sd.expected_duration_days THEN true
    ELSE false
  END as is_overdue,
  sup.name as supplier_name,
  lc.lc_number,
  bc.lc_issuance_date,
  CASE 
    WHEN bc.lc_issuance_date IS NOT NULL THEN 
      bc.lc_issuance_date + INTERVAL '30 days'
    ELSE NULL
  END as lc_expiry_date,
  CASE 
    WHEN bc.lc_issuance_date IS NOT NULL THEN 
      EXTRACT(DAY FROM ((bc.lc_issuance_date + INTERVAL '30 days') - NOW()))
    ELSE NULL
  END as days_to_lc_expiry
FROM shipment s
LEFT JOIN stage_details sd ON s.current_stage = sd.stage_name
LEFT JOIN shipment_products sp ON s.id = sp.shipment_id
LEFT JOIN product_variety pv ON sp.product_variety_id = pv.id
LEFT JOIN supplier sup ON pv.supplier_id = sup.id
LEFT JOIN letter_of_credit lc ON s.id = lc.shipment_id
LEFT JOIN bank_charges bc ON s.id = bc.shipment_id;

-- Grant necessary permissions (adjust role name as needed)
-- GRANT EXECUTE ON FUNCTION get_critical_alerts() TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_business_warnings() TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_business_insights() TO authenticated;
-- GRANT EXECUTE ON FUNCTION get_insights_counts() TO authenticated;
-- GRANT SELECT ON v_shipment_insights TO authenticated;