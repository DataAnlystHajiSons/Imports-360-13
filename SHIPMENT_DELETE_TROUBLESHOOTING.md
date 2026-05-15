# Shipment Won't Delete - Troubleshooting Guide

## Symptoms
- ✅ No foreign key constraint errors
- ❌ Shipment doesn't actually delete
- ⚠️ Silent failure (no error message)

---

## Common Causes & Solutions

### 🔍 **Cause 1: RLS (Row Level Security) Policy Blocking Delete**

**Symptom:** No error, but nothing happens when you click delete in Supabase UI.

**Solution:**
```sql
-- Check if RLS is enabled on shipment table
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename = 'shipment';

-- If rowsecurity = true, check DELETE policies
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'shipment' AND cmd = 'DELETE';
```

**Fix Options:**

**Option A: Temporarily disable RLS (for testing only!)**
```sql
ALTER TABLE shipment DISABLE ROW LEVEL SECURITY;
-- Try deleting now
-- Then re-enable:
ALTER TABLE shipment ENABLE ROW LEVEL SECURITY;
```

**Option B: Add DELETE policy**
```sql
-- Allow authenticated users to delete any shipment
CREATE POLICY "Allow delete for authenticated users" 
ON shipment 
FOR DELETE 
TO authenticated 
USING (true);
```

**Option C: Use service_role connection (bypass RLS)**
- In Supabase SQL Editor, there's a dropdown to switch connection role
- Switch from "authenticated" to "service_role"
- Try delete again

---

### 🔍 **Cause 2: BEFORE DELETE Trigger Preventing Deletion**

**Symptom:** Trigger is intercepting the delete and returning NULL or FALSE.

**Check for triggers:**
```sql
SELECT trigger_name, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'shipment'
  AND event_manipulation = 'DELETE';
```

**If you see a trigger like `prevent_shipment_deletion_trigger`:**
```sql
-- Temporarily disable it
ALTER TABLE shipment DISABLE TRIGGER prevent_shipment_deletion_trigger;
-- Try delete
-- Re-enable if needed
ALTER TABLE shipment ENABLE TRIGGER prevent_shipment_deletion_trigger;
```

---

### 🔍 **Cause 3: Trying to Delete from Supabase Table Editor UI**

**Symptom:** UI shows "Deleting..." but nothing happens.

**Why:** The UI might timeout on large cascading deletes, or RLS blocks it.

**Solution: Use SQL Editor instead:**
```sql
-- Direct SQL delete (more reliable than UI)
DELETE FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- Verify it's gone
SELECT id, reference_code 
FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
-- Should return 0 rows
```

---

### 🔍 **Cause 4: Transaction Timeout (Too Many Related Records)**

**Symptom:** Delete operation hangs or times out.

**Check how many records will be deleted:**
```sql
SELECT 
  (SELECT COUNT(*) FROM supplier_payments WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18') as payments,
  (SELECT COUNT(*) FROM shipment_products WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18') as products,
  (SELECT COUNT(*) FROM document WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18') as documents,
  (SELECT COUNT(*) FROM audit_log WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18') as audit_logs;
```

**If thousands of records:** Delete related records in batches first, then delete shipment.

---

### 🔍 **Cause 5: Connection/Session Issue**

**Symptom:** Operation appears to work but changes don't persist.

**Try:**
1. Refresh the Supabase page
2. Open a new SQL Editor tab
3. Run the delete in a transaction:
```sql
BEGIN;
DELETE FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
SELECT * FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'; -- Should be empty
COMMIT; -- Only commit if the above SELECT returns no rows
```

---

## 🧪 **Step-by-Step Debug Process**

### Step 1: Run the Debug Script
```bash
# Run this in Supabase SQL Editor:
1. Open debug_shipment_deletion.sql
2. Run each section one by one
3. Note any errors or unexpected results
```

### Step 2: Check What's Blocking
Run these in order:

```sql
-- 1. Does shipment exist?
SELECT COUNT(*) FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
-- Expected: 1

-- 2. Is RLS blocking you?
SELECT current_setting('role') as current_role;
-- If 'authenticated', try switching to 'service_role'

-- 3. Are there triggers?
SELECT COUNT(*) FROM information_schema.triggers 
WHERE event_object_table = 'shipment' AND event_manipulation = 'DELETE';
-- Expected: 0 or very few

-- 4. Try direct SQL delete
DELETE FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18' RETURNING id;
-- Should return the ID if successful
```

### Step 3: Nuclear Option (Manual Cleanup)

If all else fails, manually delete related records first:

```sql
-- Start a transaction
BEGIN;

-- Delete in order (respecting dependencies)
DELETE FROM supplier_payments WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
DELETE FROM shipment_stage_targets WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
DELETE FROM shipment_products WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
DELETE FROM bank_communication WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
DELETE FROM document WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
DELETE FROM audit_log WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
DELETE FROM costing WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- Finally delete the shipment
DELETE FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- Verify it's gone
SELECT COUNT(*) FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
-- Should return 0

-- If everything looks good:
COMMIT;

-- If something went wrong:
-- ROLLBACK;
```

---

## 🎯 **Most Likely Solutions**

Based on your symptoms, try these in order:

1. **Switch to service_role in SQL Editor**
   - Top right of SQL Editor → Click "RUN" dropdown → Select "service_role"
   - Run: `DELETE FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';`

2. **Use SQL Editor instead of Table Editor UI**
   - Don't click delete button in Table Editor
   - Write SQL delete query instead

3. **Check for RLS policies blocking delete**
   - Run the RLS check queries above
   - Temporarily disable RLS or add delete policy

---

## 📋 **Quick Checklist**

- [ ] Ran `debug_shipment_deletion.sql` 
- [ ] Checked if shipment still exists
- [ ] Switched to service_role in SQL Editor
- [ ] Tried direct SQL DELETE instead of UI
- [ ] Checked for BEFORE DELETE triggers
- [ ] Checked RLS policies
- [ ] Verified cascading constraints are set
- [ ] Tried transaction with explicit COMMIT

---

## 💡 **Report Back**

After running `debug_shipment_deletion.sql`, tell me:
1. Section 1 result: Does shipment exist? (Yes/No)
2. Section 3 result: Any triggers found? (list them)
3. Section 4 result: What RLS policies exist?
4. Section 6 result: What did the test delete output say?

This will help me identify the exact issue!
