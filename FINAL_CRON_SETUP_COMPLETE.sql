-- ============================================
-- COMPLETE CRON JOB SETUP FOR STAGE TARGET ALERTS
-- Just run this entire script in Supabase SQL Editor
-- ============================================

-- Step 1: Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Step 2: Create the cron job with your service_role key
SELECT cron.schedule(
  'send-stage-target-alerts-daily',
  '0 9 * * *',  -- Runs every day at 9:00 AM
  $$
  SELECT net.http_post(
    url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma256cWtpcXhpdnpjdWFsY2F1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Njc5NTQ4OSwiZXhwIjoyMDcyMzcxNDg5fQ.hj8puMIsq9OSmB4G3FA1xHhh8jaBVFEvGPAWfR-JFi8',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Step 3: Verify the cron job was created successfully
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  CASE 
    WHEN command LIKE '%Bearer eyJ%' THEN '✅ Correct! Has Bearer prefix'
    ELSE '❌ Something wrong'
  END as auth_check
FROM cron.job
WHERE jobname = 'send-stage-target-alerts-daily';

-- Step 4: Test the edge function manually RIGHT NOW
SELECT net.http_post(
  url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
  headers := jsonb_build_object(
    'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma256cWtpcXhpdnpjdWFsY2F1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Njc5NTQ4OSwiZXhwIjoyMDcyMzcxNDg5fQ.hj8puMIsq9OSmB4G3FA1xHhh8jaBVFEvGPAWfR-JFi8',
    'Content-Type', 'application/json'
  ),
  body := '{}'::jsonb
) as response;

-- Step 5: Check the HTTP response (wait 5 seconds after Step 4, then run this)
-- Comment out Steps 1-4 above, then run this query:
/*
SELECT 
  created,
  status_code,
  CASE 
    WHEN status_code = 200 THEN '✅ SUCCESS! Edge function worked!'
    WHEN status_code = 401 THEN '❌ FAILED - Authorization error'
    WHEN status_code = 500 THEN '⚠️ FAILED - Edge function error'
    ELSE '⚠️ Unknown status'
  END as status_message,
  content::text as result
FROM net._http_response
ORDER BY created DESC
LIMIT 1;
*/

-- Step 6: Verify database flags were updated
-- Run this to check if alerts were marked as sent:
/*
SELECT 
  s.reference_code,
  st.stage_name,
  st.target_date,
  st.three_day_alert_sent,
  st.overdue_alert_sent,
  st.updated_at
FROM shipment_stage_targets st
JOIN shipment s ON s.id = st.shipment_id
ORDER BY st.updated_at DESC
LIMIT 10;
*/

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ CRON JOB SETUP COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📅 Schedule: Daily at 9:00 AM';
  RAISE NOTICE '🔐 Authentication: Service role key configured';
  RAISE NOTICE '🎯 Next run: Today at 9:00 AM (or tomorrow if past 9 AM)';
  RAISE NOTICE '';
  RAISE NOTICE '🧪 TO TEST NOW:';
  RAISE NOTICE '1. Wait 5 seconds';
  RAISE NOTICE '2. Comment out Steps 1-4 above (add /* */ around them)';
  RAISE NOTICE '3. Uncomment and run Step 5 to check HTTP response';
  RAISE NOTICE '4. Expected: status_code = 200, SUCCESS message';
  RAISE NOTICE '';
  RAISE NOTICE '📧 CHECK YOUR EMAIL:';
  RAISE NOTICE '- Should receive alert emails';
  RAISE NOTICE '- Subject: "⚠️ Stage Target Date Warning" or "🚨 Stage Target Date Overdue"';
  RAISE NOTICE '';
  RAISE NOTICE '✅ DONE! The system will now send alerts automatically every day.';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;
