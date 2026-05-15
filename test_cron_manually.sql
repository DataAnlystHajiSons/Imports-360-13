-- Test Stage Target Alerts WITHOUT using cron.run_job()
-- pg_cron doesn't have a run_job() function, so we test differently

-- ============================================
-- Method 1: Execute the same command the cron job runs
-- ============================================
-- This is exactly what the cron job does, run it manually:

SELECT net.http_post(
  url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
  headers := jsonb_build_object(
    'Authorization', 'Bearer YOUR-SERVICE-ROLE-KEY-HERE',  -- ⚠️ REPLACE!
    'Content-Type', 'application/json'
  ),
  body := '{}'::jsonb
) as response;

-- Expected response:
-- response column should show request_id (a number like 12345)

-- ============================================
-- Method 2: Check the response from the edge function
-- ============================================
-- After running the above, wait a few seconds, then check:

SELECT 
  id,
  created,
  status_code,
  content
FROM net._http_response
ORDER BY created DESC
LIMIT 5;

-- Expected:
-- status_code: 200 (success!)
-- content: should show {"success":true,"alertsSent":X}

-- If status_code is 401: You need to replace YOUR-SERVICE-ROLE-KEY-HERE with your actual key
-- If status_code is 500: Check edge function logs in Supabase Dashboard

-- ============================================
-- Method 3: Verify the cron job is scheduled
-- ============================================
SELECT 
  jobid,
  jobname,
  schedule,
  command,
  nodename,
  active
FROM cron.job
WHERE jobname = 'send-stage-target-alerts-daily';

-- Expected:
-- jobname: send-stage-target-alerts-daily
-- schedule: 0 9 * * *
-- active: true
-- command: SELECT net.http_post(url := 'https://...

-- ============================================
-- Method 4: Check when the job will run next
-- ============================================
SELECT 
  jobname,
  schedule,
  CASE 
    WHEN schedule = '0 9 * * *' THEN 'Runs daily at 9:00 AM'
    ELSE 'Check schedule format'
  END as description,
  -- Calculate next run time (approximate)
  CASE 
    WHEN EXTRACT(HOUR FROM NOW()) < 9 THEN 
      'Today at 9:00 AM'
    ELSE 
      'Tomorrow at 9:00 AM'
  END as next_run
FROM cron.job
WHERE jobname = 'send-stage-target-alerts-daily';

-- ============================================
-- SUCCESS MESSAGE
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🎯 HOW TO TEST THE CRON JOB';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '1️⃣ Manual Test (Run Method 1 above)';
  RAISE NOTICE '   - Copy your service_role key';
  RAISE NOTICE '   - Replace YOUR-SERVICE-ROLE-KEY-HERE';
  RAISE NOTICE '   - Run the SELECT net.http_post(...) command';
  RAISE NOTICE '   - Check the response';
  RAISE NOTICE '';
  RAISE NOTICE '2️⃣ Check Database';
  RAISE NOTICE '   SELECT * FROM shipment_stage_targets;';
  RAISE NOTICE '   - three_day_alert_sent should be TRUE';
  RAISE NOTICE '   - overdue_alert_sent should be TRUE';
  RAISE NOTICE '';
  RAISE NOTICE '3️⃣ Check Your Email';
  RAISE NOTICE '   - Should receive alert emails';
  RAISE NOTICE '   - Check spam folder if not in inbox';
  RAISE NOTICE '';
  RAISE NOTICE '4️⃣ Wait for Scheduled Run';
  RAISE NOTICE '   - Job runs automatically at 9:00 AM daily';
  RAISE NOTICE '   - No action needed!';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;
