# Audit Trigger Blocking Shipment Deletion - Solution Guide

## 🔍 **The Problem**

When trying to delete a shipment, you get this error:
```
ERROR: insert or update on table "shipment_products_audit" violates foreign key constraint
"shipment_products_audit_shipment_id_fkey"
DETAIL: Key (shipment_id)=(1ce68160-0f4e-4ac1-85c6-b6062f3b6a18) is not present in table "shipment".
CONTEXT: SQL statement in function log_shipment_product_changes()
```

---

## 🎯 **Root Cause**

There's an **audit trigger** that logs all changes to `shipment_products`. Here's what happens:

1. You try to `DELETE FROM shipment`
2. CASCADE tries to delete related `shipment_products`
3. The `log_shipment_product_changes()` trigger fires (BEFORE DELETE)
4. Trigger tries to INSERT audit record into `shipment_products_audit`
5. But `shipment_products_audit` has a foreign key to `shipment` table
6. The `shipment` is already being deleted, so the foreign key validation fails!
7. ❌ **Error: Foreign key constraint violation**

**It's a chicken-and-egg problem:**
- Can't delete shipment until products are deleted
- Can't delete products because audit trigger needs shipment to exist
- Can't insert audit record because shipment is being deleted

---

## ✅ **Recommended Solution: SET NULL on Delete**

**This preserves audit history while allowing deletions.**

### Run this SQL:

```sql
-- Make audit foreign key SET NULL instead of blocking
ALTER TABLE public.shipment_products_audit 
DROP CONSTRAINT IF EXISTS shipment_products_audit_shipment_id_fkey;

ALTER TABLE public.shipment_products_audit 
ADD CONSTRAINT shipment_products_audit_shipment_id_fkey 
FOREIGN KEY (shipment_id) 
REFERENCES public.shipment(id) 
ON DELETE SET NULL;

-- Allow NULL values in shipment_id
ALTER TABLE public.shipment_products_audit 
ALTER COLUMN shipment_id DROP NOT NULL;
```

### What This Does:
- ✅ Allows shipments to be deleted
- ✅ Preserves audit history (records remain)
- ✅ Sets `shipment_id` to NULL in audit records when shipment deleted
- ✅ You can still see what products were changed, just not which shipment they belonged to

### After Running:
```sql
-- Try deleting again
DELETE FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- Check audit records (they'll have NULL shipment_id but still exist)
SELECT * FROM shipment_products_audit 
WHERE shipment_id IS NULL 
ORDER BY changed_at DESC 
LIMIT 10;
```

---

## 🔀 **Alternative Solutions**

### **Option 2: CASCADE Delete (⚠️ Loses Audit History)**
```sql
ALTER TABLE public.shipment_products_audit 
DROP CONSTRAINT IF EXISTS shipment_products_audit_shipment_id_fkey;

ALTER TABLE public.shipment_products_audit 
ADD CONSTRAINT shipment_products_audit_shipment_id_fkey 
FOREIGN KEY (shipment_id) 
REFERENCES public.shipment(id) 
ON DELETE CASCADE;
```

**Pros:** Clean deletion, no orphaned records  
**Cons:** ❌ **Defeats the purpose of audit logs!** History is lost when shipment deleted

---

### **Option 3: Remove Foreign Key Entirely**
```sql
ALTER TABLE public.shipment_products_audit 
DROP CONSTRAINT IF EXISTS shipment_products_audit_shipment_id_fkey;
```

**Pros:** Maximum flexibility  
**Cons:** No referential integrity, orphaned IDs in audit table

---

### **Option 4: Temporarily Disable Trigger (Testing Only)**
```sql
-- Find trigger name
SELECT trigger_name 
FROM information_schema.triggers
WHERE event_object_table = 'shipment_products';

-- Disable (for testing only!)
ALTER TABLE shipment_products 
DISABLE TRIGGER log_shipment_product_changes_trigger;

-- Delete your test shipment
DELETE FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- Re-enable
ALTER TABLE shipment_products 
ENABLE TRIGGER log_shipment_product_changes_trigger;
```

**Use Case:** Quick fix for deleting test data  
**Warning:** ⚠️ Don't forget to re-enable! Use only in development.

---

### **Option 5: Modify Trigger Function (Most Robust)**

Update the trigger to handle cascading deletes gracefully. See `fix_audit_trigger_alternatives.sql` for the full implementation.

**Key change:** Check if shipment exists before inserting audit record:
```sql
-- In the trigger function
SELECT EXISTS(SELECT 1 FROM shipment WHERE id = OLD.shipment_id) 
INTO v_shipment_exists;

-- Use NULL if shipment is being deleted
shipment_id = CASE WHEN v_shipment_exists THEN OLD.shipment_id ELSE NULL END
```

**Pros:** Most elegant solution, handles all edge cases  
**Cons:** Requires modifying existing trigger function

---

## 🎯 **Quick Decision Guide**

**Choose based on your needs:**

| Requirement | Solution |
|------------|----------|
| Keep audit history forever | **Option 1: SET NULL** ✅ |
| Don't care about audit after shipment deleted | Option 2: CASCADE |
| Need to test quickly | Option 4: Disable trigger temporarily |
| Want robust long-term solution | Option 5: Modify trigger |

---

## 📝 **Step-by-Step: Recommended Fix**

### 1. Run the Fix
```bash
# Open Supabase SQL Editor
# Run: fix_audit_trigger_issue.sql
```

### 2. Verify the Fix
```sql
-- Check the constraint was updated
SELECT 
  constraint_name,
  (SELECT delete_rule 
   FROM information_schema.referential_constraints rc 
   WHERE rc.constraint_name = 'shipment_products_audit_shipment_id_fkey'
  ) as delete_rule
FROM information_schema.table_constraints
WHERE constraint_name = 'shipment_products_audit_shipment_id_fkey';

-- Should show: delete_rule = 'SET NULL'
```

### 3. Test the Deletion
```sql
BEGIN;

-- Try deleting
DELETE FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'
RETURNING id, reference_code;

-- Verify it's gone
SELECT COUNT(*) FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
-- Should return 0

-- Check audit records still exist
SELECT COUNT(*) FROM shipment_products_audit 
WHERE shipment_id IS NULL  -- Now has NULL shipment_id
  AND changed_at > NOW() - INTERVAL '1 hour';

COMMIT;
```

### 4. Confirm Success
- ✅ Shipment deleted without errors
- ✅ Audit records preserved with NULL shipment_id
- ✅ No foreign key constraint violations

---

## 🚨 **Important Notes**

### About Audit Records with NULL shipment_id:
After deleting shipments, you'll have audit records where `shipment_id IS NULL`. This is **intentional and good**:
- ✅ You still know what products were changed
- ✅ You still know when and by whom
- ✅ You still have the old/new values
- ❌ You just can't link back to which shipment (because it's deleted)

### Query Audit Records After Fix:
```sql
-- Find audit records for deleted shipments
SELECT 
  product_variety_id,
  action,
  old_quantity,
  new_quantity,
  changed_at,
  changed_by,
  metadata
FROM shipment_products_audit
WHERE shipment_id IS NULL
ORDER BY changed_at DESC;
```

---

## 📋 **Files Created**

1. **`fix_audit_trigger_issue.sql`** - Recommended solution (SET NULL)
2. **`fix_audit_trigger_alternatives.sql`** - All alternative solutions
3. **`AUDIT_TRIGGER_FIX_GUIDE.md`** (this file) - Complete documentation

---

## 🎯 **Next Steps**

1. **Run:** `fix_audit_trigger_issue.sql` in Supabase SQL Editor
2. **Wait:** 2 seconds for the constraint to update
3. **Try:** Delete your test shipment again
4. **Success!** 🎉

The error should be gone and deletion should work!
