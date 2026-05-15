SELECT cron.schedule(
  'send-sowing-alerts-daily',
  '30 8 * * *',
  $$
  SELECT net.http_post(
    url:='https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-sowing-alerts',
    headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
  )
  $$
);
