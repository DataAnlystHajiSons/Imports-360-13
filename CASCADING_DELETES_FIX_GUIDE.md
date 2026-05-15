# Cascading Deletes Fix - Quick Guide

## Problem
When trying to delete a shipment from Supabase dashboard, you get this error:
```
Unable to delete row as it is currently referenced by a foreign key constraint from the table supplier_payments
DETAIL: Key (id)=(1ce68160-0f4e-4ac1-85c6-b6062f3b6a18) is still referenced from table supplier_payments.
```

## Root Cause
The `supplier_payments` table has a foreign key to `shipment`, but it doesn't have `ON DELETE CASCADE` behavior set. This prevents deletion of shipments that have payment records.

---

## Quick Fix (Immediate Solution)

### Option 1: Run Quick Fix SQL
**File:** `fix_supplier_payments_cascade.sql`

1. Open Supabase Dashboard
2. Go to SQL Editor
3. Copy and paste the contents of `fix_supplier_payments_cascade.sql`
4. Click "Run"
5. Try deleting the shipment again - it should work now!

**What it does:** Updates only the `supplier_payments` foreign key to allow cascading deletes.

---

## Complete Fix (Recommended)

### Option 2: Run Complete Fix SQL
**File:** `complete_cascading_deletes_fix.sql`

This fixes **all tables** that were missing from the original cascading deletes scripts, including:
- ✅ `supplier_payments` (your current issue)
- ✅ `shipment_stage_targets` (stage target dates feature)
- ✅ `bank_communication`
- ✅ `clearing_agent_communication`
- ✅ `warehouse_communication`
- ✅ All other shipment-related tables

**Steps:**
1. Open Supabase Dashboard → SQL Editor
2. Copy the entire contents of `complete_cascading_deletes_fix.sql`
3. Click "Run"
4. Review the verification query results at the bottom
5. You should see "✅ OK" for all tables

---

## What "ON DELETE CASCADE" Means

### Before (Current State):
```
Shipment → supplier_payments
   ↓            ↓
 DELETE    ❌ BLOCKS (Foreign Key Error)
```
- You try to delete a shipment
- Database sees it has payment records
- **Blocks** the deletion with an error

### After (With CASCADE):
```
Shipment → supplier_payments
   ↓            ↓
 DELETE    ✅ AUTO-DELETED
```
- You delete a shipment
- Database **automatically deletes** all related payment records
- No errors!

---

## Testing After Fix

1. **Verify the fix worked:**
   ```sql
   -- Run this in SQL Editor
   SELECT 
     constraint_name, 
     delete_rule
   FROM information_schema.referential_constraints
   WHERE constraint_name = 'supplier_payments_shipment_id_fkey';
   ```
   
   Expected result: `delete_rule` = `CASCADE`

2. **Try deleting the test shipment:**
   - Go to Table Editor → shipment
   - Find your test shipment
   - Click delete
   - Should succeed without errors! ✅

3. **Verify related data was deleted:**
   ```sql
   -- Check if supplier_payments were deleted too
   SELECT * FROM supplier_payments 
   WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
   ```
   
   Expected result: No rows (they were cascaded)

---

## Important Warnings ⚠️

### Once this is applied:

1. **Permanent Deletions:**
   - Deleting a shipment will **permanently delete ALL related data**
   - This includes: payments, documents, stages, communications, etc.
   - **Cannot be undone** without a backup

2. **Production Safety:**
   - Consider adding a "soft delete" feature instead
   - Add a `deleted_at` timestamp column
   - Hide deleted records instead of removing them
   - Keeps data for audit trails and recovery

3. **Backup First:**
   - Before running in production, backup your database
   - Test on a staging environment if possible

---

## Alternative: Manual Cleanup (Not Recommended)

If you don't want to use CASCADE, you can manually delete related records first:

```sql
-- 1. Delete supplier payments
DELETE FROM supplier_payments 
WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- 2. Delete stage targets
DELETE FROM shipment_stage_targets 
WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- 3. Delete shipment products
DELETE FROM shipment_products 
WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- ... (repeat for all related tables)

-- 4. Finally delete the shipment
DELETE FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
```

**Why this is bad:**
- ❌ Tedious and error-prone
- ❌ Easy to miss tables
- ❌ Not maintainable as schema evolves
- ❌ Doesn't fix the root cause

---

## Why This Wasn't Caught Earlier

1. The original `add_cascading_deletes.sql` was created before these tables existed:
   - `supplier_payments` (added Oct 2025)
   - `shipment_stage_targets` (added recently for stage target dates)
   - Communication tables (added for CC functionality)

2. When new tables are added with foreign keys, they need to be manually updated with CASCADE behavior.

---

## Future Prevention

### When adding new tables with shipment references:

✅ **Do this:**
```sql
CREATE TABLE new_table (
  id uuid PRIMARY KEY,
  shipment_id uuid REFERENCES shipment(id) ON DELETE CASCADE,  -- ← Add this!
  -- other columns
);
```

❌ **Don't do this:**
```sql
CREATE TABLE new_table (
  id uuid PRIMARY KEY,
  shipment_id uuid REFERENCES shipment(id),  -- ← Missing ON DELETE behavior
  -- other columns
);
```

---

## Verification Checklist

After running the fix:

- [ ] SQL script executed without errors
- [ ] Verification query shows "CASCADE" for supplier_payments
- [ ] Test shipment can be deleted successfully
- [ ] Related supplier_payments records are also deleted
- [ ] No foreign key errors appear

---

## Files in This Fix

1. **`fix_supplier_payments_cascade.sql`**
   - Quick fix for immediate issue
   - Only updates supplier_payments table
   - Run this if you just want to fix the current error

2. **`complete_cascading_deletes_fix.sql`**
   - Comprehensive fix for all tables
   - Updates 12+ tables with proper cascading
   - Includes verification query
   - Recommended for production

3. **`CASCADING_DELETES_FIX_GUIDE.md`** (this file)
   - Complete documentation
   - Testing instructions
   - Warnings and best practices

---

## Summary

**Problem:** Can't delete test shipments due to foreign key constraints
**Solution:** Add `ON DELETE CASCADE` to all foreign keys referencing shipment
**Impact:** Deleting a shipment will now automatically delete all related data
**Action:** Run `complete_cascading_deletes_fix.sql` in Supabase SQL Editor

🎯 **Next Step:** Run the SQL fix, test it, and you'll be able to delete test shipments easily!
