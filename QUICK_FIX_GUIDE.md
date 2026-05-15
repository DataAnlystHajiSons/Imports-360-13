# Quick Fix Guide: Delete Test Shipment

## 🎯 **The Problem**
The audit trigger is blocking shipment deletion because it tries to log to `shipment_products_audit` while the shipment is being deleted.

---

## ✅ **Choose Your Solution:**

### **🚀 FASTEST (One-Time Delete):**
Use `SIMPLE_DELETE_SHIPMENT.sql` - Temporarily disable trigger, delete, re-enable.

**Steps:**
1. Open Supabase SQL Editor
2. Run this entire script:

```sql
-- Disable ALL triggers on shipment_products
ALTER TABLE shipment_products DISABLE TRIGGER ALL;

-- Delete the shipment
DELETE FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- Re-enable triggers
ALTER TABLE shipment_products ENABLE TRIGGER ALL;
```

**Time:** 10 seconds  
**Best for:** Deleting this one test shipment right now

---

### **🔧 PERMANENT (Best Long-Term Fix):**
Use `PERMANENT_FIX_audit_trigger.sql` - Modify the trigger to handle cascading deletes gracefully.

**Steps:**
1. Open Supabase SQL Editor
2. Copy the entire contents of `PERMANENT_FIX_audit_trigger.sql`
3. Click RUN
4. Then try deleting: `DELETE FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';`

**What it does:**
- Updates the trigger function to check if shipment exists before logging
- If shipment is being deleted (cascade), skip the audit log
- Normal updates/deletes still get logged

**Time:** 30 seconds  
**Best for:** Fixing the issue permanently for all future deletions

---

## 📋 **My Recommendation:**

**Use the PERMANENT FIX** (`PERMANENT_FIX_audit_trigger.sql`) because:
- ✅ Fixes the root cause
- ✅ You can delete shipments normally going forward
- ✅ No need to remember to disable/enable triggers
- ✅ Makes sense: If shipment is deleted, no need to audit its products

---

## 🎯 **Quick Start (Just Run This):**

Open Supabase SQL Editor and run this complete solution:

```sql
-- PERMANENT FIX: Update the audit trigger function
CREATE OR REPLACE FUNCTION public.log_shipment_product_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id uuid;
    v_shipment_exists boolean;
BEGIN
    v_user_id := auth.uid();
    
    IF (TG_OP = 'DELETE') THEN
        -- Only log if shipment still exists (not cascade delete)
        SELECT EXISTS(SELECT 1 FROM shipment WHERE id = OLD.shipment_id) 
        INTO v_shipment_exists;
        
        IF v_shipment_exists THEN
            INSERT INTO public.shipment_products_audit (
                shipment_id, product_variety_id, action,
                old_quantity, old_unit, old_rate, old_amount,
                changed_by, metadata
            ) VALUES (
                OLD.shipment_id, OLD.product_variety_id, 'removed',
                OLD.quantity, OLD.unit, OLD.rate, OLD.amount,
                v_user_id, jsonb_build_object('trigger', 'auto', 'operation', TG_OP)
            );
        END IF;
        RETURN OLD;
    END IF;
    
    IF (TG_OP = 'UPDATE') THEN
        INSERT INTO public.shipment_products_audit (
            shipment_id, product_variety_id, action,
            old_quantity, old_unit, old_rate, old_amount,
            new_quantity, new_unit, new_rate, new_amount,
            changed_by, metadata
        ) VALUES (
            OLD.shipment_id, OLD.product_variety_id, 'modified',
            OLD.quantity, OLD.unit, OLD.rate, OLD.amount,
            NEW.quantity, NEW.unit, NEW.rate, NEW.amount,
            v_user_id, jsonb_build_object('trigger', 'auto', 'operation', TG_OP)
        );
        RETURN NEW;
    END IF;
    
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.shipment_products_audit (
            shipment_id, product_variety_id, action,
            new_quantity, new_unit, new_rate, new_amount,
            changed_by, metadata
        ) VALUES (
            NEW.shipment_id, NEW.product_variety_id, 'added',
            NEW.quantity, NEW.unit, NEW.rate, NEW.amount,
            v_user_id, jsonb_build_object('trigger', 'auto', 'operation', TG_OP)
        );
        RETURN NEW;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Now delete your test shipment
DELETE FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- Verify it's gone
SELECT COUNT(*) FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
```

**Done!** ✅

---

## 📁 **Files Reference:**

1. **`SIMPLE_DELETE_SHIPMENT.sql`** - Fastest one-time fix (disable/enable trigger)
2. **`PERMANENT_FIX_audit_trigger.sql`** - Permanent solution (modify trigger)
3. **`disable_audit_trigger_and_delete.sql`** - Automated disable/delete/enable
4. **`QUICK_FIX_GUIDE.md`** (this file) - Decision guide

---

## 🤔 **Which Should I Use?**

| Situation | Solution |
|-----------|----------|
| Just need to delete this one test shipment | `SIMPLE_DELETE_SHIPMENT.sql` |
| Want to fix it properly for the future | `PERMANENT_FIX_audit_trigger.sql` ✅ |
| Want fully automated script | `disable_audit_trigger_and_delete.sql` |

**I recommend the PERMANENT FIX** - it's the cleanest solution! 🎯
