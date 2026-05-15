-- SIMPLEST WAY: Setup Cron Job for Stage Target Alerts
-- Just creates the job without trying to remove old ones

-- ============================================
-- STEP 1: GET YOUR SERVICE ROLE KEY FIRST!
-- ============================================
-- 1. Go to: Supabase Dashboard → Settings → API
-- 2. Find: "service_role" key (NOT the anon key!)
-- 3. Click "Reveal" and copy the entire key
-- 4. Paste it in the command below where it says PASTE-YOUR-SERVICE-ROLE-KEY-HERE

-- ============================================
-- STEP 2: ENABLE PG_CRON
-- ============================================
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================
-- STEP 3: CREATE THE CRON JOB
-- ============================================
-- Replace PASTE-YOUR-SERVICE-ROLE-KEY-HERE with your actual service_role key!

SELECT cron.schedule(
  'send-stage-target-alerts-daily',
  '0 9 * * *',  -- Every day at 9:00 AM
  $$
  SELECT net.http_post(
    url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer PASTE-YOUR-SERVICE-ROLE-KEY-HERE',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- ============================================
-- STEP 4: VERIFY IT WAS CREATED
-- ============================================
SELECT 
  jobid,
  jobname,
  schedule,
  active
FROM cron.job 
WHERE jobname = 'send-stage-target-alerts-daily';

-- Expected output:
-- jobname: send-stage-target-alerts-daily
-- schedule: 0 9 * * *
-- active: true

-- ============================================
-- STEP 5: TEST IT NOW (Don't wait for 9 AM!)
-- ============================================
SELECT cron.run_job('send-stage-target-alerts-daily');

-- Wait a few seconds, then check the result:
SELECT 
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'send-stage-target-alerts-daily')
ORDER BY start_time DESC 
LIMIT 1;

-- Expected status: 'succeeded'
-- If you see status: 'failed', check the return_message for error details

-- ============================================
-- IF YOU NEED TO REMOVE THE JOB (for re-creation):
-- ============================================
-- Run this first, then re-run the CREATE above:
-- SELECT cron.unschedule('send-stage-target-alerts-daily');
