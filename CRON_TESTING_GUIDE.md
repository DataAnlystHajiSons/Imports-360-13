# How to Test Cron Job (Without run_job)

## ❌ **Why `cron.run_job()` Doesn't Work**

The error `function cron.run_job(unknown) does not exist` happens because:
- **`pg_cron` doesn't have a `run_job()` function**
- That function doesn't exist in the pg_cron extension
- We need to use different methods to test

---

## ✅ **3 Ways to Test Your Cron Job**

---

## 🚀 **Method 1: Run the Same Command Manually** (Fastest!)

This executes exactly what the cron job will do:

### **Step 1: Get your service_role key**
- Supabase Dashboard → Settings → API → service_role key

### **Step 2: Run this in SQL Editor:**

```sql
-- This is what the cron job executes
SELECT net.http_post(
  url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
  headers := jsonb_build_object(
    'Authorization', 'Bearer YOUR-SERVICE-ROLE-KEY-HERE',  -- 🔴 PASTE YOUR KEY!
    'Content-Type', 'application/json'
  ),
  body := '{}'::jsonb
) as response;
```

**Expected result:**
```
response
--------
12345  (some number - this is the request_id)
```

### **Step 3: Check the HTTP response:**

```sql
-- Wait 3-5 seconds after running the above, then:
SELECT 
  status_code,
  content::text
FROM net._http_response
ORDER BY created DESC
LIMIT 1;
```

**✅ Success looks like:**
```
status_code: 200
content: {"success":true,"alertsSent":2}
```

**❌ If you see 401:**
- You forgot to replace YOUR-SERVICE-ROLE-KEY-HERE
- Or you used the anon key instead of service_role key

---

## ⏰ **Method 2: Change Schedule to Run in 1 Minute**

Make the cron job run in the next minute:

```sql
-- Get current time
SELECT TO_CHAR(NOW() + INTERVAL '1 minute', 'MI HH * * *') as schedule_for_next_minute;

-- Example output: "45 14 * * *" means it will run at 14:45 (2:45 PM)
```

Now update the cron job:

```sql
-- Replace XX with the minute from above (e.g., if it's 14:45 now, use '46 14 * * *' to run at 14:46)
SELECT cron.alter_job(
  (SELECT jobid FROM cron.job WHERE jobname = 'send-stage-target-alerts-daily'),
  schedule := 'XX HH * * *'  -- Replace XX HH with actual values
);

-- Example: To run at 2:46 PM today:
-- schedule := '46 14 * * *'
```

Wait for that minute, then check edge function logs!

**After testing, change it back to 9 AM:**

```sql
SELECT cron.alter_job(
  (SELECT jobid FROM cron.job WHERE jobname = 'send-stage-target-alerts-daily'),
  schedule := '0 9 * * *'
);
```

---

## 🕐 **Method 3: Just Wait for 9 AM Tomorrow**

The easiest way - let it run on schedule!

**To verify it's scheduled:**

```sql
SELECT 
  jobname,
  schedule,
  active,
  CASE 
    WHEN schedule = '0 9 * * *' THEN 
      CASE 
        WHEN EXTRACT(HOUR FROM NOW()) < 9 THEN 'Will run today at 9:00 AM'
        ELSE 'Will run tomorrow at 9:00 AM'
      END
    ELSE 'Unknown schedule'
  END as next_run
FROM cron.job
WHERE jobname = 'send-stage-target-alerts-daily';
```

**After 9 AM, check:**

1. **Edge Function Logs:**
   - Supabase Dashboard → Edge Functions → send-stage-target-alerts → Logs
   - Look for executions at 9:00 AM

2. **Database:**
   ```sql
   SELECT 
     stage_name,
     target_date,
     three_day_alert_sent,
     overdue_alert_sent,
     updated_at
   FROM shipment_stage_targets
   WHERE updated_at > CURRENT_DATE;
   ```

3. **Your Email:**
   - Check inbox for alert emails
   - Check spam folder

---

## 📊 **Verification Checklist**

After testing with any method:

### **✅ Check 1: Edge Function Response**
```sql
-- See recent HTTP responses
SELECT 
  created,
  status_code,
  content::json->>'alertsSent' as alerts_sent,
  content::json->>'message' as message
FROM net._http_response
WHERE status_code IS NOT NULL
ORDER BY created DESC
LIMIT 5;
```

**Expected:**
- `status_code: 200`
- `alerts_sent: 2` (or however many alerts were sent)
- `message: "Alerts processed successfully"`

---

### **✅ Check 2: Database Flags**
```sql
SELECT 
  s.reference_code,
  st.stage_name,
  st.target_date,
  st.three_day_alert_sent,
  st.overdue_alert_sent,
  st.updated_at
FROM shipment_stage_targets st
JOIN shipment s ON s.id = st.shipment_id
ORDER BY st.updated_at DESC;
```

**Expected:**
- Flags should be `true` for alerts that were sent
- `updated_at` should be recent

---

### **✅ Check 3: Edge Function Logs**
1. Go to Supabase Dashboard
2. Edge Functions → send-stage-target-alerts
3. Click "Logs" tab
4. Look for recent executions

**Expected log entries:**
```
Checking for alerts to send...
Found 2 alerts to send
Sending warning email for stage: enlistment_verification
Sending overdue email for stage: ip_number
Alerts processed successfully: 2
```

---

### **✅ Check 4: Email Received**
- Check inbox for emails with subjects:
  - "⚠️ Stage Target Date Warning"
  - "🚨 Stage Target Date Overdue"
- Check spam folder if not in inbox

---

## 🔍 **Troubleshooting**

### **Problem: status_code 401**
**Cause:** Missing or wrong Authorization header

**Fix:**
```sql
-- Make sure you're using service_role key, not anon key
-- Check the cron job has the correct key:
SELECT 
  jobname,
  CASE 
    WHEN command LIKE '%Bearer ey%' THEN '✅ Has auth header'
    ELSE '❌ Missing auth header'
  END as auth_status
FROM cron.job
WHERE jobname = 'send-stage-target-alerts-daily';
```

If missing, update it:
```sql
-- Replace YOUR-SERVICE-ROLE-KEY with actual key
UPDATE cron.job
SET command = $$
SELECT net.http_post(
  url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
  headers := jsonb_build_object(
    'Authorization', 'Bearer YOUR-SERVICE-ROLE-KEY-HERE',
    'Content-Type', 'application/json'
  ),
  body := '{}'::jsonb
);
$$
WHERE jobname = 'send-stage-target-alerts-daily';
```

---

### **Problem: status_code 500**
**Cause:** Edge function error

**Fix:**
1. Check Edge Function logs for error details
2. Common causes:
   - RESEND_API_KEY not set or invalid
   - No recipients in alert_emails_list
   - Database permission issues

---

### **Problem: No response in net._http_response**
**Cause:** The HTTP extension might not be logging responses

**Fix:** Check edge function logs directly in Supabase Dashboard instead

---

## 🎯 **Recommended Testing Flow**

1. **Use Method 1 (Manual Command)** to test immediately
2. Check the response with `SELECT * FROM net._http_response`
3. Verify database flags changed
4. Check your email
5. Once working, let the cron job run on schedule at 9 AM

---

## 📁 **Files Reference**

- **`test_cron_manually.sql`** - SQL commands to test manually
- **`SIMPLE_CRON_SETUP.sql`** - Create the cron job
- **`CRON_TESTING_GUIDE.md`** (this file) - Testing methods

---

## 💡 **Quick Summary**

**You can't use:** `cron.run_job()` (doesn't exist)

**You CAN use:**
1. ⭐ **Run the command manually** - Execute the same `net.http_post()` command
2. ⏰ **Change schedule temporarily** - Make it run in 1 minute
3. 🕐 **Wait for scheduled time** - Let it run at 9 AM

**Fastest option:** Method 1 - Run the command manually! 🚀
