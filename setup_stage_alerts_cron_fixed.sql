-- Setup Cron Job for Stage Target Alerts (Fixed Version)
-- Handles case where job doesn't exist yet

-- ============================================
-- Step 1: Enable pg_cron extension
-- ============================================
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================
-- Step 2: Remove existing job (if it exists) - with error handling
-- ============================================
DO $$
BEGIN
  -- Try to unschedule, ignore error if job doesn't exist
  PERFORM cron.unschedule('send-stage-target-alerts-daily');
  RAISE NOTICE '🗑️  Old job removed';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '✅ No existing job found (this is normal for first-time setup)';
END $$;

-- ============================================
-- Step 3: Create the new cron job
-- IMPORTANT: Replace YOUR-SERVICE-ROLE-KEY with your actual key!
-- Find it in: Supabase Dashboard → Settings → API → service_role key
-- ============================================
SELECT cron.schedule(
  'send-stage-target-alerts-daily',
  '0 9 * * *',  -- Every day at 9:00 AM
  $$
  SELECT net.http_post(
    url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer YOUR-SERVICE-ROLE-KEY-HERE',  -- ⚠️ REPLACE THIS!
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);

-- ============================================
-- Step 4: Verify the job was created
-- ============================================
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  CASE 
    WHEN command LIKE '%YOUR-SERVICE-ROLE-KEY-HERE%' THEN '❌ You need to replace YOUR-SERVICE-ROLE-KEY-HERE with your actual key!'
    ELSE '✅ Key looks good'
  END as key_status
FROM cron.job 
WHERE jobname = 'send-stage-target-alerts-daily';

-- ============================================
-- Success message
-- ============================================
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ Cron job created successfully!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📅 Schedule: Daily at 9:00 AM';
  RAISE NOTICE '🎯 Job name: send-stage-target-alerts-daily';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  IMPORTANT NEXT STEPS:';
  RAISE NOTICE '1. Get your service_role key from:';
  RAISE NOTICE '   Supabase Dashboard → Settings → API → service_role key';
  RAISE NOTICE '';
  RAISE NOTICE '2. Run this UPDATE command with your actual key:';
  RAISE NOTICE '';
  RAISE NOTICE '   UPDATE cron.job';
  RAISE NOTICE '   SET command = $CMD$';
  RAISE NOTICE '   SELECT net.http_post(';
  RAISE NOTICE '     url := ''https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts'',';
  RAISE NOTICE '     headers := jsonb_build_object(';
  RAISE NOTICE '       ''Authorization'', ''Bearer PASTE-YOUR-KEY-HERE'',';
  RAISE NOTICE '       ''Content-Type'', ''application/json''';
  RAISE NOTICE '     ),';
  RAISE NOTICE '     body := ''''{}''''::jsonb';
  RAISE NOTICE '   );';
  RAISE NOTICE '   $CMD$';
  RAISE NOTICE '   WHERE jobname = ''send-stage-target-alerts-daily'';';
  RAISE NOTICE '';
  RAISE NOTICE '3. Test manually:';
  RAISE NOTICE '   SELECT cron.run_job(''send-stage-target-alerts-daily'');';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;
