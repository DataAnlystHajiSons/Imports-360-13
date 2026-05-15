# Fix 401 Unauthorized Error - Stage Alerts Cron Job

## 🔍 **The Problem**

Your cron job got a **401 Unauthorized** error because it didn't include an Authorization header when calling the edge function.

**From your logs:**
```json
"status_code": 401
```

**Missing from request headers:**
```
Authorization: Bearer <service-role-key>
```

---

## ✅ **The Solution**

You need to include your **service_role key** in the cron job's HTTP request.

---

## 📋 **Step-by-Step Fix**

### **Step 1: Get Your Service Role Key**

1. Go to **Supabase Dashboard**
2. Click **Settings** (⚙️ icon in sidebar)
3. Click **API**
4. Under "Project API keys" section, find **`service_role`** key
5. Click **"Reveal"** and copy the key
6. It looks like: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ey...` (very long string)

⚠️ **IMPORTANT:** Keep this key **SECRET** - it has admin access to your database!

---

### **Step 2: Update Your Cron Job**

Run this SQL in Supabase SQL Editor:

```sql
-- Enable pg_cron if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove old job (if exists)
SELECT cron.unschedule('send-stage-target-alerts-daily');

-- Create new job with proper authentication
SELECT cron.schedule(
  'send-stage-target-alerts-daily',
  '0 9 * * *',  -- Every day at 9:00 AM
  $$
  SELECT net.http_post(
    url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer YOUR-SERVICE-ROLE-KEY-PASTE-HERE',  -- ⚠️ REPLACE!
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  ) as request_id;
  $$
);
```

**🔴 CRITICAL:** Replace `YOUR-SERVICE-ROLE-KEY-PASTE-HERE` with your actual service_role key from Step 1!

---

### **Step 3: Verify the Job**

```sql
-- Check the job was created
SELECT 
  jobname,
  schedule,
  active,
  command
FROM cron.job 
WHERE jobname = 'send-stage-target-alerts-daily';
```

**Expected output:**
```
jobname: send-stage-target-alerts-daily
schedule: 0 9 * * *
active: true
command: SELECT net.http_post(url := 'https://...' ...
```

---

### **Step 4: Test Manually**

Before waiting until 9 AM tomorrow, test it now:

```sql
-- Trigger the cron job manually right now
SELECT cron.run_job('send-stage-target-alerts-daily');

-- Check the result (wait a few seconds first)
SELECT * FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'send-stage-target-alerts-daily')
ORDER BY start_time DESC 
LIMIT 5;
```

**Expected result:**
- `status` should be `succeeded`
- `return_message` should show HTTP response from edge function

---

### **Step 5: Check If It Worked**

**A. Check edge function was called successfully:**

1. Go to **Supabase Dashboard** → **Edge Functions**
2. Click **`send-stage-target-alerts`**
3. Click **"Logs"** tab
4. Look for recent execution with **200 status code** (not 401!)

**B. Check database alert flags:**

```sql
SELECT 
  stage_name,
  target_date,
  three_day_alert_sent,
  overdue_alert_sent,
  updated_at
FROM shipment_stage_targets
ORDER BY updated_at DESC;
```

**C. Check your email:**
- Should have received alert emails
- Check spam folder if not in inbox

---

## 🔐 **Security Best Practice**

Instead of hardcoding the service_role key in SQL, you can:

### **Option 1: Use Supabase Vault (Recommended)**

```sql
-- Store service role key in Vault
SELECT vault.create_secret('service_role_key', 'your-service-role-key-here');

-- Use it in cron job
SELECT cron.schedule(
  'send-stage-target-alerts-daily',
  '0 9 * * *',
  $$
  SELECT net.http_post(
    url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || vault.read_secret('service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

### **Option 2: Use Edge Function with service_role Auth**

The edge function can check if it's being called from the database using a specific header:

```sql
SELECT cron.schedule(
  'send-stage-target-alerts-daily',
  '0 9 * * *',
  $$
  SELECT net.http_post(
    url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

---

## 🧪 **Testing Checklist**

After applying the fix:

- [ ] Cron job created with service_role key
- [ ] Manual test run completes successfully
- [ ] Edge function logs show 200 status (not 401)
- [ ] Database shows `three_day_alert_sent` or `overdue_alert_sent` = true
- [ ] Email received in inbox
- [ ] `cron.job_run_details` shows `succeeded` status

---

## 🚨 **Common Mistakes**

### ❌ **Mistake 1: Using anon key instead of service_role key**
```sql
-- WRONG - anon key doesn't have enough permissions
'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6...'
```
Make sure you're using the **service_role** key, not the **anon** key!

### ❌ **Mistake 2: Forgetting "Bearer " prefix**
```sql
-- WRONG - missing "Bearer " prefix
'Authorization', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'

-- CORRECT
'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
```

### ❌ **Mistake 3: Extra quotes in the key**
```sql
-- WRONG - key is a string, don't add extra quotes
'Bearer "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."'

-- CORRECT
'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
```

---

## 📊 **What Success Looks Like**

### **Before (401 Error):**
```json
{
  "status_code": 401,
  "response": {
    "error": "Unauthorized"
  }
}
```

### **After (Success):**
```json
{
  "status_code": 200,
  "response": {
    "success": true,
    "alertsSent": 2,
    "message": "Alerts processed successfully"
  }
}
```

---

## 🎯 **Quick Summary**

**Problem:** Cron job got 401 error - no Authorization header  
**Solution:** Add service_role key to the HTTP request headers  
**File to run:** `setup_stage_alerts_cron.sql` (with your service_role key)  
**Test:** `SELECT cron.run_job('send-stage-target-alerts-daily');`  
**Verify:** Check edge function logs for 200 status code  

---

## 📁 **Files Created**

- **`setup_stage_alerts_cron.sql`** - Corrected cron job with auth header
- **`FIX_401_CRON_ERROR.md`** (this file) - Complete fix guide

**Next step:** Run `setup_stage_alerts_cron.sql` with your service_role key! 🚀
