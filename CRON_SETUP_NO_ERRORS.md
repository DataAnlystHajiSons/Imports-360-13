# Setup Cron Job - No Errors Version

## ❌ **Why You Got the Error**

The error `could not find valid entry for job 'send-stage-target-alerts-daily'` happened because:
- The script tried to **unschedule** (remove) the job
- But the job **doesn't exist yet** (first time setup)
- So it failed trying to remove something that's not there

---

## ✅ **The Fix: Just Create It (Don't Try to Remove First)**

---

## 🚀 **Simple 3-Step Setup**

### **Step 1: Get Your Service Role Key** (1 minute)

1. Open **Supabase Dashboard**
2. Click **Settings** (⚙️ in sidebar)
3. Click **API**
4. Scroll to **"Project API keys"**
5. Find **"service_role"** (NOT "anon")
6. Click **"Reveal"**
7. **Copy** the entire key (it's very long, starts with `eyJ...`)

**What it looks like:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNma256cWtpcXhpdnpjdWFsY2F1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Njc5NTQ4OSwiZXhwIjoyMDcyMzcxNDg5fQ.XXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

---

### **Step 2: Run This SQL** (2 minutes)

Open **Supabase SQL Editor** and run:

```sql
-- Enable cron
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create the job (replace YOUR-KEY-HERE with your actual service_role key!)
SELECT cron.schedule(
  'send-stage-target-alerts-daily',
  '0 9 * * *',
  $$
  SELECT net.http_post(
    url := 'https://sfknzqkiqxivzcualcau.supabase.co/functions/v1/send-stage-target-alerts',
    headers := jsonb_build_object(
      'Authorization', 'Bearer YOUR-KEY-HERE',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

**🔴 CRITICAL:** Replace `YOUR-KEY-HERE` with the service_role key you copied in Step 1!

**Expected result:**
```
schedule
--------
1
```

---

### **Step 3: Verify It Works** (1 minute)

```sql
-- Check the job exists
SELECT jobname, schedule, active FROM cron.job 
WHERE jobname = 'send-stage-target-alerts-daily';

-- Expected:
-- jobname: send-stage-target-alerts-daily
-- schedule: 0 9 * * *
-- active: true
```

---

## 🧪 **Test It Now (Don't Wait for 9 AM)**

```sql
-- Run the job manually right now
SELECT cron.run_job('send-stage-target-alerts-daily');

-- Wait 5 seconds, then check the result
SELECT 
  status,
  return_message,
  start_time
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'send-stage-target-alerts-daily')
ORDER BY start_time DESC 
LIMIT 1;
```

**✅ Success looks like:**
```
status: succeeded
return_message: (shows HTTP response with 200 status)
```

**❌ If you see:**
```
status: failed
return_message: 401 Unauthorized
```
**Then:** You forgot to replace `YOUR-KEY-HERE` or used the wrong key (anon instead of service_role)

---

## 🔄 **If You Need to Start Over**

If you made a mistake and want to try again:

```sql
-- Remove the job
SELECT cron.unschedule('send-stage-target-alerts-daily');

-- Now go back to Step 2 and create it again
```

---

## 📋 **Final Checklist**

- [ ] Got service_role key from Supabase Dashboard
- [ ] Ran the `CREATE EXTENSION` command
- [ ] Ran the `cron.schedule` command with YOUR actual key
- [ ] Verified job exists with `SELECT * FROM cron.job`
- [ ] Tested manually with `cron.run_job()`
- [ ] Got `status: succeeded` result
- [ ] Checked edge function logs show 200 status (not 401)

---

## 🎯 **Common Mistakes**

### ❌ **Mistake 1: Using anon key instead of service_role key**
```
Won't work: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...aW...  (anon key)
Will work:  eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...c2V...  (service_role key)
```
Make sure it says **"service_role"** when you copy it!

### ❌ **Mistake 2: Forgetting to replace YOUR-KEY-HERE**
```sql
-- WRONG - still has placeholder
'Authorization', 'Bearer YOUR-KEY-HERE'

-- CORRECT - has actual key
'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
```

### ❌ **Mistake 3: Adding extra quotes**
```sql
-- WRONG - extra quotes around the key
'Bearer "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."'

-- CORRECT - no extra quotes
'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
```

---

## 📁 **Files to Use**

- **`SIMPLE_CRON_SETUP.sql`** ⭐ **Use this one!** - No errors, just works
- **`setup_stage_alerts_cron_fixed.sql`** - Alternative with error handling
- **`CRON_SETUP_NO_ERRORS.md`** (this file) - Step-by-step guide

---

## 🆘 **Still Getting Errors?**

**Share these details:**
1. The exact error message
2. The SQL command you ran (remove your key before sharing!)
3. The result from: `SELECT * FROM cron.job;`
4. The result from: `SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 1;`

---

## 🎉 **Success!**

Once you see `status: succeeded`, your automated email alerts are working!

**What happens now:**
- ✅ Every day at 9:00 AM, the cron job runs automatically
- ✅ It calls the edge function
- ✅ Edge function checks for alerts to send
- ✅ Emails are sent to recipients in `alert_emails_list`
- ✅ Alerts are marked as sent to prevent duplicates

**You're all set!** 🚀
