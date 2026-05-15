-- ================================================
-- SIMPLE TEST FUNCTIONS (Start with these first)
-- Execute these basic functions to test your setup
-- ================================================

-- Simple test function - start here
CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS TABLE (
  stat_name text,
  stat_value integer,
  stat_description text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    'active_shipments'::text as stat_name,
    COUNT(*)::integer as stat_value,
    'Shipments currently being processed'::text as stat_description
  FROM shipment 
  WHERE status = 'active'
  
  UNION ALL
  
  SELECT 
    'overdue_shipments'::text as stat_name,
    COUNT(*)::integer as stat_value,
    'Shipments older than 10 days'::text as stat_description
  FROM shipment 
  WHERE status = 'active' 
    AND created_at < NOW() - INTERVAL '10 days'
  
  UNION ALL
  
  SELECT 
    'completed_this_month'::text as stat_name,
    COUNT(*)::integer as stat_value,
    'Shipments completed this month'::text as stat_description
  FROM shipment 
  WHERE status = 'completed' 
    AND updated_at >= DATE_TRUNC('month', NOW());
END;
$$ LANGUAGE plpgsql;

-- Test this function first
-- SELECT * FROM get_dashboard_stats();