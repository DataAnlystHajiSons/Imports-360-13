# Stage Target Alerts - Quick Testing Guide

## 🎯 **Goal**
Test that automated email alerts are sent for stage target dates (3-day warnings and overdue alerts).

---

## 🚀 **Quick Test (5 Minutes)**

### **Step 1: Create Test Data** (2 minutes)

1. Open **Supabase SQL Editor**
2. Copy and paste **`test_stage_alerts_now.sql`**
3. Click **RUN**
4. You should see:
   ```
   ✅ Using shipment: D-2501
   📊 Test Data Created
   ⚠️ Should send 3-DAY WARNING (enlistment_verification)
   🚨 Should send OVERDUE alert (ip_number)
   ```

---

### **Step 2: Add Email Recipient** (1 minute)

```sql
-- Add your email to receive test alerts
INSERT INTO alert_emails_list (email) 
VALUES ('your-email@example.com')
ON CONFLICT (email) DO NOTHING;

-- Verify it was added
SELECT * FROM alert_emails_list;
```

---

### **Step 3: Trigger Alerts** (2 minutes)

**Option A: Using Supabase Dashboard** (Easiest)
1. Go to **Supabase Dashboard** → **Edge Functions**
2. Find **`send-stage-target-alerts`**
3. Click **"Invoke"** button
4. Click **"Invoke function"**
5. Check the response

**Option B: Using HTML Test Page** (Visual)
1. Open **`test-stage-alerts-trigger.html`** in your browser
2. Fields are pre-filled with your Supabase credentials
3. Click **"🚀 Trigger Alert Emails Now"**
4. See results immediately

**Option C: Using cURL** (Command Line)
```bash
curl -X POST \
  'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma256cWtpcXhpdnpjdWFsY2F1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3OTU0ODksImV4cCI6MjA3MjM3MTQ4OX0.JKjOS9NRdbVH1UanfqmBeHmMSnlWlZtDr-5LdKw5YaA' \
  -H 'Content-Type: application/json'
```

---

### **Step 4: Verify Results** (1 minute)

**A. Check Function Response:**
- Should show: `{ "alertsSent": 2, "success": true }`

**B. Check Database:**
```sql
SELECT 
  stage_name,
  target_date,
  three_day_alert_sent,  -- Should be TRUE for enlistment_verification
  overdue_alert_sent      -- Should be TRUE for ip_number
FROM shipment_stage_targets
ORDER BY target_date;
```

**C. Check Your Email:**
- Should receive **2 emails**:
  1. "⚠️ Stage Target Date Warning" for enlistment_verification
  2. "🚨 Stage Target Date Overdue" for ip_number

**D. Check Edge Function Logs:**
1. Go to **Supabase Dashboard** → **Edge Functions**
2. Click **`send-stage-target-alerts`**
3. Click **"Logs"** tab
4. Look for execution logs showing:
   ```
   Alerts to send: 2
   Email sent to: your-email@example.com
   Alerts processed successfully: 2
   ```

---

## ✅ **Success Criteria**

You'll know it's working if:
- [x] Function returns `{ "alertsSent": 2 }`
- [x] Database shows `three_day_alert_sent = true` and `overdue_alert_sent = true`
- [x] You receive 2 emails in your inbox
- [x] Edge Function logs show no errors
- [x] Re-running the function returns `{ "alertsSent": 0 }` (no duplicates)

---

## 🔍 **Troubleshooting**

### **Problem: No emails received**

**Check 1: Recipients configured?**
```sql
SELECT * FROM alert_emails_list;
-- Should show your email
```

**Check 2: Resend API key set?**
- Go to **Supabase Dashboard** → **Settings** → **Edge Functions**
- Look for environment variable: `RESEND_API_KEY`
- Should be set to your Resend API key

**Check 3: Edge function deployed?**
```bash
supabase functions deploy send-stage-target-alerts
```

**Check 4: Function logs show errors?**
- Go to **Edge Functions** → **Logs**
- Look for error messages

---

### **Problem: Function returns error**

**Common errors:**

**Error: "Function not found"**
- Solution: Deploy the function
  ```bash
  cd "D:\Hamza\Imports 360 preserved"
  supabase functions deploy send-stage-target-alerts
  ```

**Error: "Invalid API key"**
- Solution: Set RESEND_API_KEY in Supabase Dashboard
  1. Go to Settings → Edge Functions → Secrets
  2. Add: `RESEND_API_KEY` = `your_resend_api_key`

**Error: "No alerts found"**
- Solution: Run `test_stage_alerts_now.sql` to create test data

---

### **Problem: Duplicate emails sent**

**Check alert flags:**
```sql
SELECT 
  stage_name,
  three_day_alert_sent,
  overdue_alert_sent
FROM shipment_stage_targets;
```

**If stuck at FALSE, check edge function logs for errors**

**To reset for re-testing:**
```sql
UPDATE shipment_stage_targets 
SET three_day_alert_sent = false, overdue_alert_sent = false;
```

---

## 📧 **Email Template Preview**

### **3-Day Warning Email:**
```
Subject: ⚠️ Stage Target Date Warning - D-2501

Stage: enlistment_verification
Target Date: 2026-02-20
Status: ⚠️ Due in 3 days

Action Required:
Please ensure this stage is completed by the target date.

Shipment Details:
Reference: D-2501
```

### **Overdue Email:**
```
Subject: 🚨 Stage Target Date Overdue - D-2501

Stage: ip_number
Target Date: 2026-02-16
Status: 🚨 1 day(s) overdue

Action Required:
This stage has passed its target date and is still incomplete.

Shipment Details:
Reference: D-2501
```

---

## 🔄 **Testing Scheduled Execution**

To test the **automated daily schedule**:

### **Option 1: Set up pg_cron job**

```sql
-- Schedule to run daily at 9:00 AM
SELECT cron.schedule(
  'send-stage-target-alerts-daily',
  '0 9 * * *',
  $$
  SELECT net.http_post(
    url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer YOUR-SERVICE-ROLE-KEY',
      'Content-Type', 'application/json'
    )
  );
  $$
);

-- Verify it was scheduled
SELECT * FROM cron.job;
```

### **Option 2: Use Supabase Cron Extension**

1. Go to **Supabase Dashboard** → **Database** → **Extensions**
2. Enable **pg_cron** if not already enabled
3. Go to **Database** → **Cron Jobs**
4. Add new job:
   - Name: `send-stage-target-alerts-daily`
   - Schedule: `0 9 * * *` (9 AM daily)
   - Command: HTTP POST to edge function

---

## 📁 **Test Files Reference**

1. **`test_stage_alerts_now.sql`** - Create test data and show what should alert
2. **`test-stage-alerts-trigger.html`** - Visual interface to trigger function
3. **`TEST_STAGE_TARGET_ALERTS.md`** - Complete testing documentation
4. **`ALERT_TESTING_QUICK_START.md`** - This file (quick reference)

---

## 🎯 **Next Steps**

1. ✅ Run `test_stage_alerts_now.sql` to create test data
2. ✅ Add your email to `alert_emails_list`
3. ✅ Trigger the function using one of the 3 methods
4. ✅ Check your email and verify alerts received
5. ✅ Set up scheduled execution (cron job) for production

**You're all set!** The automated email alerts should now be working. 🎉
