# Testing Stage Target Date Email Alerts

## 🎯 **What We're Testing**

The edge function `send-stage-target-alerts` should automatically:
1. ✅ Send emails **3 days before** target date (warning)
2. ✅ Send emails when target date **passes** and stage is incomplete (overdue)
3. ✅ Only send each alert **once** (no duplicates)

---

## 🧪 **Testing Method 1: Manual Trigger (Fastest)**

### **Step 1: Create Test Data**

Run this in Supabase SQL Editor:

```sql
-- Get a test shipment ID
SELECT id, reference_code 
FROM shipment 
LIMIT 1;

-- Insert test target dates (use the shipment ID from above)
INSERT INTO shipment_stage_targets (shipment_id, stage_name, target_date)
VALUES 
  -- Replace with your shipment ID
  ('YOUR-SHIPMENT-ID-HERE', 'enlistment_verification', CURRENT_DATE + INTERVAL '3 days'),  -- Should trigger 3-day warning
  ('YOUR-SHIPMENT-ID-HERE', 'ip_number', CURRENT_DATE - INTERVAL '1 day');  -- Should trigger overdue alert

-- Verify insertion
SELECT * FROM shipment_stage_targets 
WHERE shipment_id = 'YOUR-SHIPMENT-ID-HERE';
```

### **Step 2: Manually Invoke the Edge Function**

**Option A: Using Supabase Dashboard**
1. Go to Supabase Dashboard → Edge Functions
2. Find `send-stage-target-alerts`
3. Click "Invoke" button
4. Click "Invoke function"
5. Check the response

**Option B: Using cURL (Command Line)**

```bash
# Replace with your project URL and anon key
curl -X POST \
  'https://YOUR-PROJECT-REF.supabase.co/functions/v1/send-stage-target-alerts' \
  -H 'Authorization: Bearer YOUR-ANON-KEY' \
  -H 'Content-Type: application/json'
```

**Option C: Using SQL (Trigger via Database)**

```sql
-- Create a SQL function to trigger the edge function
SELECT
  net.http_post(
    url := 'https://YOUR-PROJECT-REF.supabase.co/functions/v1/send-stage-target-alerts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer YOUR-SERVICE-ROLE-KEY',
      'Content-Type', 'application/json'
    )
  ) as response;
```

### **Step 3: Check the Results**

**A. Check Edge Function Logs:**
1. Go to Supabase Dashboard → Edge Functions
2. Click on `send-stage-target-alerts`
3. Click "Logs" tab
4. Look for execution logs showing:
   - How many alerts were found
   - Email sending status
   - Any errors

**B. Check Database for Alert Tracking:**

```sql
-- Check if alerts were marked as sent
SELECT 
  shipment_id,
  stage_name,
  target_date,
  three_day_alert_sent,
  overdue_alert_sent,
  created_at
FROM shipment_stage_targets
WHERE shipment_id = 'YOUR-SHIPMENT-ID-HERE';

-- Should show three_day_alert_sent = true or overdue_alert_sent = true
```

**C. Check Your Email Inbox:**
- Check the email address(es) in `alert_emails_list` table
- Look for emails with subject:
  - "⚠️ Stage Target Date Warning - [Shipment Ref]"
  - "🚨 Stage Target Date Overdue - [Shipment Ref]"

---

## 🧪 **Testing Method 2: Wait for Scheduled Execution**

### **Step 1: Verify Cron Job is Set Up**

1. Go to Supabase Dashboard → Database → Cron Jobs (pg_cron extension)
2. Look for a job targeting `send-stage-target-alerts`

**Or check via SQL:**

```sql
-- Check if pg_cron extension is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_cron';

-- Check scheduled jobs
SELECT * FROM cron.job WHERE command LIKE '%send-stage-target-alerts%';
```

### **Step 2: Create Test Data with Near-Future Dates**

```sql
-- Set target dates to trigger tomorrow morning
INSERT INTO shipment_stage_targets (shipment_id, stage_name, target_date)
VALUES 
  ('YOUR-SHIPMENT-ID', 'enlistment_verification', CURRENT_DATE + INTERVAL '3 days');

-- Check it was inserted
SELECT * FROM shipment_stage_targets WHERE shipment_id = 'YOUR-SHIPMENT-ID';
```

### **Step 3: Wait and Check Logs**

- Wait for the scheduled time (e.g., 9:00 AM if that's when you scheduled it)
- Check Edge Function logs after scheduled time
- Check your email inbox

---

## 🧪 **Testing Method 3: Complete Integration Test**

### **Full Test Script**

Run this complete test in Supabase SQL Editor:

```sql
-- ============================================
-- COMPLETE TEST SCRIPT FOR STAGE TARGET ALERTS
-- ============================================

-- Step 1: Get or create a test shipment
DO $$
DECLARE
  test_shipment_id uuid;
  test_shipment_ref text;
BEGIN
  -- Get existing shipment or create one
  SELECT id, reference_code INTO test_shipment_id, test_shipment_ref
  FROM shipment 
  LIMIT 1;
  
  IF test_shipment_id IS NULL THEN
    RAISE EXCEPTION 'No shipments found. Create a test shipment first.';
  END IF;
  
  RAISE NOTICE '📌 Using test shipment: % (%)', test_shipment_ref, test_shipment_id;
  
  -- Step 2: Clean up any existing test data
  DELETE FROM shipment_stage_targets 
  WHERE shipment_id = test_shipment_id;
  
  RAISE NOTICE '🧹 Cleaned up old test data';
  
  -- Step 3: Insert test target dates
  INSERT INTO shipment_stage_targets (shipment_id, stage_name, target_date)
  VALUES 
    (test_shipment_id, 'enlistment_verification', CURRENT_DATE + INTERVAL '3 days'),
    (test_shipment_id, 'ip_number', CURRENT_DATE - INTERVAL '1 day'),
    (test_shipment_id, 'original_docs', CURRENT_DATE + INTERVAL '7 days');
  
  RAISE NOTICE '✅ Inserted 3 test target dates';
  RAISE NOTICE '   - 3-day warning: enlistment_verification';
  RAISE NOTICE '   - Overdue: ip_number';
  RAISE NOTICE '   - Future: original_docs (should not alert)';
  
  -- Step 4: Show what should be alerted
  RAISE NOTICE '';
  RAISE NOTICE '📧 Expected Alerts:';
  RAISE NOTICE '   1. WARNING email for enlistment_verification (3 days away)';
  RAISE NOTICE '   2. OVERDUE email for ip_number (1 day past)';
  RAISE NOTICE '   3. NO email for original_docs (7 days away)';
  
END $$;

-- Step 5: Query to see targets that should trigger alerts
SELECT 
  s.reference_code,
  st.stage_name,
  st.target_date,
  CURRENT_DATE as today,
  (st.target_date - CURRENT_DATE) as days_until_target,
  CASE 
    WHEN st.target_date - CURRENT_DATE = 3 AND NOT st.three_day_alert_sent 
      THEN '⚠️ Should send 3-day WARNING'
    WHEN st.target_date < CURRENT_DATE AND NOT st.overdue_alert_sent 
      THEN '🚨 Should send OVERDUE alert'
    ELSE '✅ No alert needed yet'
  END as expected_alert
FROM shipment_stage_targets st
JOIN shipment s ON s.id = st.shipment_id
ORDER BY st.target_date;

-- Step 6: Verify alert recipients are configured
SELECT 
  COUNT(*) as recipient_count,
  array_agg(email) as recipients
FROM alert_emails_list;

-- If no recipients, insert a test email:
-- INSERT INTO alert_emails_list (email) VALUES ('your-email@example.com');
```

---

## 📧 **Verify Email Configuration**

### **Check Recipients List:**

```sql
-- See who will receive alerts
SELECT * FROM alert_emails_list;

-- Add your email for testing
INSERT INTO alert_emails_list (email) 
VALUES ('your-email@example.com')
ON CONFLICT (email) DO NOTHING;
```

### **Check Resend API Key is Set:**

1. Go to Supabase Dashboard → Settings → Edge Functions
2. Look for environment variable: `RESEND_API_KEY`
3. Verify it's set and valid

---

## 🔍 **Debugging Issues**

### **Issue 1: No Emails Received**

**Check logs:**
```sql
-- In Supabase Dashboard → Edge Functions → send-stage-target-alerts → Logs
```

**Common causes:**
- ❌ RESEND_API_KEY not set or invalid
- ❌ No recipients in `alert_emails_list` table
- ❌ Resend API domain not verified
- ❌ Edge function not deployed

**Fix:**
```sql
-- Verify recipients exist
SELECT * FROM alert_emails_list;

-- Manually test the function (see Method 1 above)
```

### **Issue 2: Emails Sent Multiple Times**

**Check alert flags:**
```sql
SELECT 
  stage_name,
  three_day_alert_sent,
  overdue_alert_sent
FROM shipment_stage_targets;
```

**Should be TRUE after alert sent to prevent duplicates**

**Fix if stuck:**
```sql
-- Reset alert flags for testing
UPDATE shipment_stage_targets 
SET three_day_alert_sent = false, overdue_alert_sent = false
WHERE shipment_id = 'YOUR-TEST-SHIPMENT-ID';
```

### **Issue 3: Edge Function Not Scheduled**

**Check if cron job exists:**
```sql
SELECT * FROM cron.job;
```

**Set up cron job manually:**
```sql
-- Schedule to run daily at 9:00 AM
SELECT cron.schedule(
  'send-stage-target-alerts-daily',
  '0 9 * * *',  -- Every day at 9:00 AM
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR-PROJECT-REF.supabase.co/functions/v1/send-stage-target-alerts',
      headers := jsonb_build_object(
        'Authorization', 'Bearer YOUR-SERVICE-ROLE-KEY',
        'Content-Type', 'application/json'
      )
    ) as request_id;
  $$
);
```

---

## ✅ **Success Checklist**

After running tests, verify:

- [ ] Edge function executes without errors
- [ ] Logs show "Alerts processed: X"
- [ ] `three_day_alert_sent` or `overdue_alert_sent` = true in database
- [ ] Email received in inbox with correct subject
- [ ] Email contains shipment reference and stage name
- [ ] Running function again doesn't send duplicate emails
- [ ] Recipients in `alert_emails_list` receive emails

---

## 🎯 **Quick Test Summary**

**Fastest way to test (5 minutes):**

1. **Insert test data:**
   ```sql
   INSERT INTO shipment_stage_targets (shipment_id, stage_name, target_date)
   VALUES ('YOUR-SHIPMENT-ID', 'ip_number', CURRENT_DATE - 1);
   ```

2. **Manually invoke function:**
   - Go to Supabase Dashboard → Edge Functions
   - Click `send-stage-target-alerts` → Invoke

3. **Check results:**
   - Look at function logs
   - Check your email
   - Query database: `SELECT * FROM shipment_stage_targets;`

---

## 📁 **Related Files**

- `add_stage_target_dates.sql` - Database setup
- `supabase/functions/send-stage-target-alerts/index.ts` - Edge function
- `deploy-stage-target-alerts.ps1` - Deployment script
- `STAGE_TARGET_DATES_SUMMARY.md` - Feature documentation

---

## 🆘 **Need Help?**

If emails aren't sending:
1. Check Edge Function logs for errors
2. Verify RESEND_API_KEY is set
3. Confirm recipients in `alert_emails_list`
4. Test Resend API directly at https://resend.com/docs
5. Check spam folder in your email

**Next step:** Run Method 1 (Manual Trigger) to test immediately!
