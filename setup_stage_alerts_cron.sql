-- Setup Cron Job for Stage Target Alerts with Proper Authentication
-- This schedules the email alerts to run automatically every day

-- ============================================
-- IMPORTANT: Replace YOUR-SERVICE-ROLE-KEY with your actual service role key
-- Find it in: Supabase Dashboard → Settings → API → service_role key
-- ============================================

-- First, make sure pg_cron extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove existing job if it exists
SELECT cron.unschedule('send-stage-target-alerts-daily');

-- Schedule the job to run daily at 9:00 AM
-- CRITICAL: Include the Authorization header with service_role key!
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

-- Verify the job was scheduled
SELECT 
  jobid,
  schedule,
  command,
  nodename,
  active
FROM cron.job 
WHERE jobname = 'send-stage-target-alerts-daily';

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Cron job scheduled successfully!';
  RAISE NOTICE '📅 Will run daily at 9:00 AM';
  RAISE NOTICE '⚠️  IMPORTANT: Make sure you replaced YOUR-SERVICE-ROLE-KEY with your actual key!';
  RAISE NOTICE '';
  RAISE NOTICE '🧪 To test manually, run:';
  RAISE NOTICE '   SELECT cron.run_job(''send-stage-target-alerts-daily'');';
END $$;
