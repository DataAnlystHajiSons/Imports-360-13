-- ============================================
-- QUICK TEST: Stage Target Date Alerts
-- Run this entire script in Supabase SQL Editor to test email alerts
-- ============================================

-- Step 1: Get a test shipment
DO $$
DECLARE
  test_shipment_id uuid;
  test_shipment_ref text;
BEGIN
  SELECT id, reference_code INTO test_shipment_id, test_shipment_ref
  FROM shipment 
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF test_shipment_id IS NULL THEN
    RAISE EXCEPTION '❌ No shipments found. Create a test shipment first.';
  END IF;
  
  RAISE NOTICE '✅ Using shipment: % (ID: %)', test_shipment_ref, test_shipment_id;
  
  -- Store in a temp table for later steps
  CREATE TEMP TABLE IF NOT EXISTS test_config (
    shipment_id uuid,
    shipment_ref text
  );
  
  DELETE FROM test_config;
  INSERT INTO test_config VALUES (test_shipment_id, test_shipment_ref);
  
END $$;

-- Step 2: Clean up any existing test targets for this shipment
DELETE FROM shipment_stage_targets 
WHERE shipment_id = (SELECT shipment_id FROM test_config);

-- Step 3: Insert test target dates
INSERT INTO shipment_stage_targets (shipment_id, stage_name, target_date)
SELECT 
  shipment_id,
  stage_name,
  target_date
FROM test_config,
LATERAL (
  VALUES 
    ('enlistment_verification'::stage, CURRENT_DATE + INTERVAL '3 days'),  -- Should trigger 3-day warning
    ('ip_number'::stage, CURRENT_DATE - INTERVAL '1 day')  -- Should trigger overdue alert
) AS targets(stage_name, target_date);

-- Step 4: Show what was created
SELECT 
  '📊 Test Data Created' as status,
  s.reference_code as shipment,
  st.stage_name,
  st.target_date,
  (st.target_date - CURRENT_DATE) as days_until_target,
  CASE 
    WHEN st.target_date - CURRENT_DATE = 3 THEN '⚠️ Should send 3-DAY WARNING'
    WHEN st.target_date < CURRENT_DATE THEN '🚨 Should send OVERDUE alert'
    ELSE '—'
  END as expected_alert
FROM shipment_stage_targets st
JOIN shipment s ON s.id = st.shipment_id
WHERE st.shipment_id = (SELECT shipment_id FROM test_config)
ORDER BY st.target_date;

-- Step 5: Check email recipients
SELECT 
  '📧 Email Recipients' as status,
  COUNT(*) as count,
  array_agg(email) as emails
FROM alert_emails_list;

-- If no recipients found, show warning
DO $$
DECLARE
  recipient_count int;
BEGIN
  SELECT COUNT(*) INTO recipient_count FROM alert_emails_list;
  
  IF recipient_count = 0 THEN
    RAISE WARNING '⚠️ NO EMAIL RECIPIENTS CONFIGURED!';
    RAISE NOTICE 'Add recipients with: INSERT INTO alert_emails_list (email) VALUES (''your-email@example.com'');';
  ELSE
    RAISE NOTICE '✅ Found % email recipient(s)', recipient_count;
  END IF;
END $$;

-- Step 6: Call the edge function to check what would be alerted
-- This queries the same logic the edge function uses
SELECT 
  '🔍 Alerts That Should Be Sent' as info,
  s.reference_code,
  st.stage_name,
  st.target_date,
  CASE 
    WHEN st.target_date - CURRENT_DATE = 3 AND NOT st.three_day_alert_sent 
      THEN '⚠️ 3-DAY WARNING'
    WHEN st.target_date < CURRENT_DATE AND NOT st.overdue_alert_sent 
      THEN '🚨 OVERDUE'
    ELSE '—'
  END as alert_type
FROM shipment_stage_targets st
JOIN shipment s ON s.id = st.shipment_id
WHERE (
  (st.target_date - CURRENT_DATE = 3 AND NOT st.three_day_alert_sent)
  OR 
  (st.target_date < CURRENT_DATE AND NOT st.overdue_alert_sent)
)
ORDER BY st.target_date;

-- Step 7: Show instructions for manual testing
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '🎯 NEXT STEPS TO TEST EMAILS:';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '1️⃣ Go to Supabase Dashboard → Edge Functions';
  RAISE NOTICE '2️⃣ Find "send-stage-target-alerts" function';
  RAISE NOTICE '3️⃣ Click "Invoke" button';
  RAISE NOTICE '4️⃣ Click "Invoke function" (no parameters needed)';
  RAISE NOTICE '5️⃣ Check the response and logs';
  RAISE NOTICE '6️⃣ Check your email inbox';
  RAISE NOTICE '';
  RAISE NOTICE '📧 Expected: 2 emails should be sent';
  RAISE NOTICE '   - 1 warning email (3 days before target)';
  RAISE NOTICE '   - 1 overdue email (past target date)';
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
END $$;

-- Cleanup temp table
DROP TABLE IF EXISTS test_config;
