# CC Functionality Deployment Guide

## Overview
This guide walks you through deploying the complete CC (carbon copy) functionality for bank communications.

## Prerequisites
- Supabase CLI installed (`npm install -g supabase`)
- Database access credentials
- Supabase project linked to CLI

## Deployment Steps

### Step 1: Database Migration

Run the SQL migration to add the `cc_emails` column to the `bank_communication` table.

```bash
# Using psql
psql -h your-database-host -U postgres -d postgres -f add_cc_emails_to_bank_communication.sql

# OR using Supabase CLI
supabase db push
```

**Verify the migration:**
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'bank_communication' 
AND column_name = 'cc_emails';
```

Expected result: Column `cc_emails` with type `ARRAY`

---

### Step 2: Deploy Edge Function

The edge function `send-bank-email` has been updated to:
- Fetch `cc_emails` from the database
- Validate CC email addresses
- Include CC recipients in email sending
- Log CC information for debugging
- Return CC count in response

**Deploy the function:**
```bash
# Navigate to your project root
cd "D:\Hamza\Imports 360 preserved"

# Deploy the updated edge function
supabase functions deploy send-bank-email
```

**Verify deployment:**
```bash
supabase functions list
```

You should see `send-bank-email` in the list of deployed functions.

---

### Step 3: Deploy Frontend Changes

The `bank-communication.html` file has been updated with:
- CC email input with tag-based UI
- Email validation
- Visual feedback
- Communication history showing CC recipients

**If using version control:**
```bash
git add bank-communication.html
git commit -m "Add CC functionality to bank communications"
git push origin main
```

**If deploying manually:**
Upload the updated `bank-communication.html` to your hosting platform.

---

### Step 4: Test the Implementation

#### Test 1: Send Email Without CC
1. Navigate to bank communication page
2. Fill in all required fields
3. Leave CC field empty
4. Send email
5. ✅ Verify email sent successfully

#### Test 2: Send Email With Single CC
1. Navigate to bank communication page
2. Fill in all required fields
3. Add one CC email: `stakeholder@example.com`
4. Send email
5. ✅ Verify both primary recipient and CC recipient receive email
6. ✅ Check communication history shows CC email

#### Test 3: Send Email With Multiple CCs
1. Navigate to bank communication page
2. Fill in all required fields
3. Add multiple CC emails:
   - `stakeholder1@example.com`
   - `stakeholder2@example.com`
   - `finance@example.com`
4. Send email
5. ✅ Verify all recipients receive email
6. ✅ Check communication history displays all CC emails

#### Test 4: Invalid Email Validation
1. Try adding invalid email: `not-an-email`
2. ✅ Verify error message appears
3. ✅ Verify invalid email is not added

#### Test 5: Duplicate Email Prevention
1. Add email: `test@example.com`
2. Try adding same email again
3. ✅ Verify error message appears
4. ✅ Verify duplicate is not added

#### Test 6: Edge Function Logs
1. Send email with CC
2. Check Supabase Edge Function logs:
   ```bash
   supabase functions logs send-bank-email
   ```
3. ✅ Verify logs show:
   - Primary recipient email
   - CC email addresses
   - Subject line
   - Number of attachments

---

### Step 5: Monitor Production

#### Check Database
```sql
-- View recent communications with CC
SELECT 
  id,
  email_subject,
  cc_emails,
  sent_at,
  status
FROM bank_communication
WHERE cc_emails IS NOT NULL
ORDER BY sent_at DESC
LIMIT 10;
```

#### Check Edge Function Performance
```bash
# View recent function invocations
supabase functions logs send-bank-email --tail

# Or in Supabase Dashboard:
# Functions > send-bank-email > Logs
```

#### Monitor Email Delivery
Check your Resend dashboard for:
- Email delivery status
- CC recipient confirmations
- Bounce/failure rates

---

## Rollback Plan

If you encounter issues and need to rollback:

### Rollback Database (Optional)
```sql
-- Remove cc_emails column if needed
ALTER TABLE public.bank_communication
DROP COLUMN IF EXISTS cc_emails;
```

### Rollback Edge Function
```bash
# Redeploy previous version
git checkout <previous-commit>
supabase functions deploy send-bank-email
```

### Rollback Frontend
```bash
# Restore previous version
git checkout <previous-commit> bank-communication.html
# Redeploy
```

---

## Troubleshooting

### Issue: CC emails not showing in history
**Solution:** Clear browser cache, refresh page. Check database column exists:
```sql
SELECT * FROM bank_communication WHERE id = 'your-communication-id';
```

### Issue: Edge function error "cc_emails not found"
**Solution:** Verify database migration ran successfully:
```sql
\d bank_communication
```

### Issue: Email sending fails with CC
**Solution:** Check edge function logs:
```bash
supabase functions logs send-bank-email --tail
```
Look for validation errors or Resend API errors.

### Issue: Invalid emails not filtered
**Solution:** Edge function includes validation. Check logs for warnings about filtered emails.

### Issue: CC field not showing in form
**Solution:** 
1. Clear browser cache
2. Hard refresh (Ctrl+Shift+R)
3. Check browser console for JavaScript errors

---

## Post-Deployment Checklist

- [ ] Database migration completed successfully
- [ ] Edge function deployed without errors
- [ ] Frontend deployed to production
- [ ] Test email sent without CC (backward compatibility)
- [ ] Test email sent with single CC
- [ ] Test email sent with multiple CCs
- [ ] Communication history displays CC correctly
- [ ] Edge function logs show CC information
- [ ] Email validation working correctly
- [ ] Resend dashboard shows CC recipients
- [ ] No errors in browser console
- [ ] No errors in edge function logs
- [ ] Documentation updated
- [ ] Team notified of new feature

---

## Support

### Edge Function Logs
```bash
# Real-time logs
supabase functions logs send-bank-email --tail

# Recent logs
supabase functions logs send-bank-email --limit 50
```

### Database Query for Debugging
```sql
-- Check latest communications with details
SELECT 
  bc.id,
  bc.email_subject,
  bc.cc_emails,
  bc.status,
  bc.sent_at,
  s.reference_code,
  bc2.contact_name as bank_contact,
  u.full_name as sent_by
FROM bank_communication bc
LEFT JOIN shipment s ON bc.shipment_id = s.id
LEFT JOIN bank_contact bc2 ON bc.bank_contact_id = bc2.id
LEFT JOIN app_user u ON bc.sent_by = u.id
ORDER BY bc.sent_at DESC
LIMIT 10;
```

### Edge Function Environment Variables
Verify your edge function has access to:
- `RESEND_API_KEY` - For sending emails
- `SUPABASE_URL` - Database URL
- `SUPABASE_SERVICE_ROLE_KEY` - Database access

Check in Supabase Dashboard: Settings > Edge Functions > Environment Variables

---

## Next Steps

After successful deployment:
1. Notify users about the new CC functionality
2. Update user documentation/training materials
3. Monitor usage and gather feedback
4. Consider future enhancements (see BANK_COMMUNICATION_CC_IMPLEMENTATION.md)

---

## Quick Commands Reference

```bash
# Database
psql -h HOST -U postgres -d postgres -f add_cc_emails_to_bank_communication.sql

# Edge Function
supabase functions deploy send-bank-email
supabase functions logs send-bank-email --tail

# Verification
supabase functions list
supabase db push --dry-run

# Rollback
git checkout <commit> bank-communication.html
supabase functions deploy send-bank-email
```

---

## Contact

For issues or questions during deployment, check:
1. Edge function logs
2. Browser console
3. Supabase Dashboard > Functions > send-bank-email
4. Resend Dashboard for email delivery issues
