# Clearing Agent Communication CC Functionality - Deployment Guide

## Overview
Complete deployment guide for the clearing agent communication system with built-in CC (carbon copy) functionality.

## What's Being Deployed

1. **Database Tables:**
   - `clearing_agent_communication` - Main communication tracking
   - `clearing_agent_communication_documents` - Document attachments junction table

2. **Frontend Page:**
   - `clearing-agent-communication.html` - Complete UI with CC functionality

3. **Edge Function:**
   - `send-clearing-agent-email` - Email sending with CC support

## Prerequisites

- Supabase CLI installed: `npm install -g supabase`
- Database access credentials
- Supabase project linked
- Resend API key configured

## Step-by-Step Deployment

### Step 1: Database Migration

Run the SQL migration to create the communication tables.

#### Option A: Using psql
```bash
psql -h your-database-host -U postgres -d postgres -f create_clearing_agent_communication_table.sql
```

#### Option B: Using Supabase Dashboard
1. Go to SQL Editor in Supabase Dashboard
2. Copy contents of `create_clearing_agent_communication_table.sql`
3. Paste and execute

#### Option C: Using Supabase CLI
```bash
supabase db push
```

#### Verify Database Migration

Run this verification query:
```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('clearing_agent_communication', 'clearing_agent_communication_documents');

-- Check columns including cc_emails
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'clearing_agent_communication';

-- Check indexes
SELECT indexname 
FROM pg_indexes 
WHERE tablename = 'clearing_agent_communication';
```

**Expected Results:**
- ✅ Both tables exist
- ✅ `cc_emails` column exists with type `ARRAY`
- ✅ Two indexes created on shipment_id and clearing_agent_id

---

### Step 2: Deploy Edge Function

The edge function handles email sending to clearing agents with CC support.

#### Deploy Command:
```bash
# Navigate to project root
cd "D:\Hamza\Imports 360 preserved"

# Deploy the edge function
supabase functions deploy send-clearing-agent-email
```

#### Verify Deployment:
```bash
# List all deployed functions
supabase functions list

# Check function logs
supabase functions logs send-clearing-agent-email --tail
```

**Expected Output:**
```
Functions:
  - send-clearing-agent-email (deployed)
```

#### Environment Variables Check:
Verify these environment variables are set in Supabase Dashboard:
- `RESEND_API_KEY` - Your Resend API key
- `SUPABASE_URL` - Auto-configured
- `SUPABASE_SERVICE_ROLE_KEY` - Auto-configured

Go to: **Supabase Dashboard → Settings → Edge Functions → Environment Variables**

---

### Step 3: Deploy Frontend

Deploy the HTML page to your hosting platform.

#### Option A: Manual Deployment
1. Upload `clearing-agent-communication.html` to your web server
2. Ensure it's accessible via your domain

#### Option B: Version Control
```bash
git add clearing-agent-communication.html
git commit -m "Add clearing agent communication with CC functionality"
git push origin main
```

#### Verify Frontend:
1. Navigate to: `https://yourdomain.com/clearing-agent-communication.html?id=<test-shipment-id>`
2. Check browser console for errors (F12)
3. Verify page loads correctly

---

### Step 4: Test the Implementation

#### Test 1: Database Tables ✅
```sql
-- Insert test communication
INSERT INTO clearing_agent_communication (
  shipment_id, 
  clearing_agent_id, 
  sent_by, 
  email_subject, 
  email_body, 
  cc_emails, 
  status
) VALUES (
  'your-shipment-uuid',
  'your-clearing-agent-uuid',
  'your-user-uuid',
  'Test Subject',
  'Test Body',
  ARRAY['test1@example.com', 'test2@example.com'],
  'sent'
);

-- Verify insert
SELECT * FROM clearing_agent_communication ORDER BY sent_at DESC LIMIT 1;
```

#### Test 2: Frontend Page ✅
1. Navigate to communication page for a shipment
2. Verify clearing agent dropdown loads
3. Select a clearing agent → verify email auto-fills
4. Add CC email and press Enter → verify tag appears
5. Remove CC email by clicking × → verify tag removed
6. Type invalid email → verify error message appears
7. Fill form completely and submit → verify success message

#### Test 3: Edge Function ✅
```bash
# Monitor edge function logs in real-time
supabase functions logs send-clearing-agent-email --tail

# Send a test communication from the UI
# Watch logs for:
# - "Sending email to clearing agent:"
# - "To: agent@example.com"
# - "CC: stakeholder1@example.com, stakeholder2@example.com"
# - Success response
```

#### Test 4: Email Delivery ✅
1. Send test communication with CC
2. Check Resend dashboard for delivery status
3. Verify primary recipient receives email
4. Verify CC recipients receive email
5. Check email headers show CC addresses

#### Test 5: Communication History ✅
1. After sending communication, check history table
2. Verify communication appears with:
   - Sent timestamp
   - Clearing agent name
   - CC recipients (comma-separated)
   - Subject
   - Status

---

### Step 5: Integration with Shipment Details

Add a link to clearing agent communication in your shipment details page.

#### Add to Shipment Details HTML:
```html
<!-- Add this button in your shipment details page -->
<button onclick="window.location.href='clearing-agent-communication.html?id=' + shipmentId">
  <i class="fas fa-envelope"></i> Contact Clearing Agent
</button>
```

#### Or add to navigation menu:
```html
<li>
  <a href="clearing-agent-communication.html?id=<shipment-id>" class="nav-link">
    <i class="fas fa-user-shield icon"></i>
    <span class="text">Clearing Agent Communication</span>
  </a>
</li>
```

---

## Production Monitoring

### Monitor Database
```sql
-- View recent communications
SELECT 
  cac.id,
  cac.email_subject,
  array_length(cac.cc_emails, 1) as cc_count,
  cac.sent_at,
  cac.status,
  ca.name as clearing_agent,
  s.reference_code as shipment
FROM clearing_agent_communication cac
LEFT JOIN clearing_agent ca ON cac.clearing_agent_id = ca.id
LEFT JOIN shipment s ON cac.shipment_id = s.id
WHERE cac.sent_at >= NOW() - INTERVAL '7 days'
ORDER BY cac.sent_at DESC
LIMIT 20;

-- Count by clearing agent
SELECT 
  ca.name,
  COUNT(cac.id) as total_communications,
  COUNT(CASE WHEN cac.cc_emails IS NOT NULL THEN 1 END) as with_cc
FROM clearing_agent ca
LEFT JOIN clearing_agent_communication cac ON ca.id = cac.clearing_agent_id
GROUP BY ca.id, ca.name
ORDER BY total_communications DESC;
```

### Monitor Edge Function
```bash
# Real-time logs
supabase functions logs send-clearing-agent-email --tail

# Recent logs (last 50)
supabase functions logs send-clearing-agent-email --limit 50

# Filter for errors only
supabase functions logs send-clearing-agent-email | grep -i error
```

### Monitor Email Delivery
Check Resend Dashboard:
1. Go to https://resend.com/dashboard
2. Navigate to Emails section
3. Filter by:
   - Date range
   - Status (delivered, bounced, failed)
   - Subject line
4. Check CC recipient confirmations

---

## Rollback Plan

If issues occur, follow these rollback steps:

### Rollback Database (Optional)
```sql
-- Drop tables if needed
DROP TABLE IF EXISTS public.clearing_agent_communication_documents CASCADE;
DROP TABLE IF EXISTS public.clearing_agent_communication CASCADE;
```

### Rollback Edge Function
```bash
# Redeploy previous version or delete function
supabase functions delete send-clearing-agent-email
```

### Rollback Frontend
```bash
# Remove the file or restore previous version
git checkout HEAD~1 clearing-agent-communication.html
git push origin main
```

---

## Troubleshooting

### Issue 1: Tables not created
**Symptoms:** Error when inserting communication  
**Solution:**
```sql
-- Check if tables exist
\dt clearing_agent*

-- If not, run migration again
\i create_clearing_agent_communication_table.sql
```

### Issue 2: CC emails not saving
**Symptoms:** cc_emails column is NULL in database  
**Solution:**
1. Check frontend JS sends `cc_emails` array
2. Verify column type is `text[]`:
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'clearing_agent_communication' 
AND column_name = 'cc_emails';
```

### Issue 3: Edge function error
**Symptoms:** "Function not found" or 500 error  
**Solution:**
```bash
# Redeploy function
supabase functions deploy send-clearing-agent-email

# Check deployment status
supabase functions list
```

### Issue 4: Email not sending
**Symptoms:** Success message but no email received  
**Solution:**
1. Check Resend API key:
```bash
# In Supabase Dashboard
Settings → Edge Functions → Environment Variables → RESEND_API_KEY
```
2. Check edge function logs for errors
3. Verify Resend dashboard for bounced emails

### Issue 5: CC field not showing
**Symptoms:** Form doesn't have CC input  
**Solution:**
1. Clear browser cache (Ctrl+Shift+Delete)
2. Hard refresh (Ctrl+Shift+R)
3. Check browser console for JS errors

### Issue 6: Invalid emails not filtered
**Symptoms:** Invalid emails accepted  
**Solution:**
- Frontend validation should catch this
- Edge function also validates and filters
- Check console logs for validation errors

---

## Post-Deployment Checklist

- [ ] Database migration completed successfully
- [ ] Both tables created with correct schema
- [ ] cc_emails column is text[] type
- [ ] Indexes created on foreign keys
- [ ] Edge function deployed without errors
- [ ] RESEND_API_KEY environment variable set
- [ ] Frontend deployed and accessible
- [ ] Test communication sent successfully
- [ ] Email received by primary recipient
- [ ] Email received by CC recipients
- [ ] Communication appears in history
- [ ] CC recipients shown in history table
- [ ] Document attachments work
- [ ] Edge function logs show no errors
- [ ] Resend dashboard confirms delivery
- [ ] Browser console shows no errors
- [ ] Link added to shipment details page
- [ ] Team notified of new feature
- [ ] Documentation updated

---

## Verification Commands

### Database Verification
```sql
-- Verify table structure
\d clearing_agent_communication
\d clearing_agent_communication_documents

-- Verify data
SELECT COUNT(*) FROM clearing_agent_communication;
SELECT * FROM clearing_agent_communication LIMIT 5;

-- Verify foreign keys
SELECT 
  tc.constraint_name, 
  tc.table_name, 
  kcu.column_name, 
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_name = 'clearing_agent_communication';
```

### Edge Function Verification
```bash
# Test function invocation
supabase functions invoke send-clearing-agent-email --body '{"communication_id":"test-id"}'

# Expected: Error response (test-id doesn't exist) but function executed
```

### Frontend Verification
1. Open developer tools (F12)
2. Navigate to clearing-agent-communication.html
3. Check Network tab for API calls
4. Check Console tab for errors
5. Test all functionality manually

---

## Performance Benchmarks

Expected performance after deployment:

| Operation | Time | Notes |
|-----------|------|-------|
| Page Load | < 2s | Loading clearing agents and documents |
| Send Email | 3-5s | Including DB insert and edge function |
| History Load | < 1s | Loading past communications |
| Add CC Email | Instant | Frontend only |
| Remove CC Email | Instant | Frontend only |

---

## Next Steps

After successful deployment:

1. **User Training**
   - Create user guide for CC functionality
   - Train team on clearing agent communication
   - Document common use cases

2. **Monitoring Setup**
   - Set up alerts for failed emails
   - Monitor edge function performance
   - Track usage metrics

3. **Future Enhancements**
   - Email templates for common messages
   - Stakeholder picker from database
   - Bulk communication feature
   - Read receipt tracking

4. **Integration**
   - Add to shipment workflow
   - Link from clearing agent details page
   - Add to admin dashboard

---

## Support Contact

For deployment issues:
1. Check edge function logs first
2. Verify database tables
3. Check Resend dashboard
4. Review browser console errors
5. Contact system administrator if issues persist

---

## Quick Reference Commands

```bash
# Database
psql -h HOST -U postgres -d postgres -f create_clearing_agent_communication_table.sql

# Edge Function
supabase functions deploy send-clearing-agent-email
supabase functions logs send-clearing-agent-email --tail

# Verification
supabase functions list
supabase db push --dry-run

# Rollback
git checkout HEAD~1 clearing-agent-communication.html
supabase functions delete send-clearing-agent-email
```

---

## Success Criteria

Deployment is successful when:
- ✅ Database tables created with correct schema
- ✅ Edge function deployed and accessible
- ✅ Frontend page loads without errors
- ✅ Test email sent successfully
- ✅ CC recipients receive email
- ✅ Communication history displays correctly
- ✅ No errors in logs or console
- ✅ All tests passed

**Ready for production use!** 🎉
