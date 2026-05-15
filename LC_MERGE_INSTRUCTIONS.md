# 🔄 LC Stages Merge - Implementation Guide

## ✅ What Was Changed

### Frontend Changes (DONE ✅)

1. **JavaScript (shipment-tracker.js)**
   - ✅ Removed `lc_shared_with_supplier` from STAGE_ORDER
   - ✅ Updated "LC Opening" to "LC Management" 
   - ✅ Duration increased from 3 days to 4 days (combines both stages)
   - ✅ Merged LC form fields (added shared_date and notes)
   - ✅ Removed separate lc_share table configuration
   - ✅ Updated stage condition checks

2. **HTML (shipment_tracker.html)**
   - ✅ Removed old stage-based document upload section
   - ✅ Documents now only managed via "Manage Documents" button

### Result:
- ✅ **Before**: LC Opening → LC Shared (2 separate stages)
- ✅ **After**: LC Management (1 unified stage with all fields)

---

## 🗄️ Database Migration Required

### Option 1: Run SQL Migration (RECOMMENDED)

1. Open **Supabase Dashboard**
2. Go to **SQL Editor**
3. Open the file: `merge_lc_stages.sql`
4. Click **Run**

This will:
- ✅ Add `shared_date` and `notes` to `letter_of_credit` table
- ✅ Migrate all data from `lc_share` to `letter_of_credit`
- ✅ Update shipments in old stage to new stage
- ✅ Update stage history
- ✅ Clean up stage edges
- ✅ Archive `lc_share` table (preserves data)

### Option 2: Manual Database Updates

If you prefer manual updates:

```sql
-- 1. Add new columns
ALTER TABLE letter_of_credit 
ADD COLUMN shared_date DATE,
ADD COLUMN notes TEXT;

-- 2. Migrate existing data
UPDATE letter_of_credit lc
SET 
    shared_date = ls.shared_date,
    notes = ls.notes
FROM lc_share ls
WHERE lc.shipment_id = ls.shipment_id;

-- 3. Update current shipments
UPDATE shipment
SET current_stage = 'lc_opening'
WHERE current_stage = 'lc_shared_with_supplier';

-- 4. Update stage history
UPDATE stage_history
SET stage = 'lc_opening'
WHERE stage = 'lc_shared_with_supplier';

-- 5. Clean up stage edges
DELETE FROM stage_edges 
WHERE from_stage = 'lc_shared_with_supplier' 
   OR to_stage = 'lc_shared_with_supplier';

-- 6. Add correct edge
INSERT INTO stage_edges (from_stage, to_stage)
VALUES ('lc_opening', 'invoice')
ON CONFLICT DO NOTHING;

-- 7. Archive old table
ALTER TABLE lc_share RENAME TO lc_share_archived;
```

---

## 🧪 Testing After Migration

### Test 1: Check Stage Flow
1. Open any shipment in tracker
2. Verify timeline shows:
   - ✅ IP Number
   - ✅ **LC Management** (not "LC Opening" + "LC Shared")
   - ✅ Invoice

### Test 2: Edit LC Stage
1. Click on "LC Management" stage
2. Verify form shows:
   - ✅ LC Number
   - ✅ Opened Date
   - ✅ **Shared with Supplier Date** (NEW)
   - ✅ File URL
   - ✅ **Notes** (NEW)
   - ✅ Bank dropdown

### Test 3: Documents
1. Click "Manage Documents" button
2. Verify you see the **centralized** documents modal
3. Upload a test document
4. Verify it's **NOT** stage-specific

### Test 4: Advance Stage
1. Fill in LC Management details
2. Click "Save" and "Complete Stage"
3. Verify shipment advances to **Invoice** (not LC Shared)

---

## 📊 Before vs After

### Before:
```
IP Number → LC Opening → LC Shared → Invoice
            (3 days)     (1 day)
            
Form fields separated:
- LC Opening: lc_number, opened_date, bank_id
- LC Shared: shared_date, notes
```

### After:
```
IP Number → LC Management → Invoice
            (4 days)

All fields in one stage:
- LC Management: lc_number, opened_date, shared_date, bank_id, notes
```

---

## ✅ Verification Checklist

After migration, verify:

- [ ] No shipments stuck in "lc_shared_with_supplier"
  ```sql
  SELECT COUNT(*) FROM shipment WHERE current_stage = 'lc_shared_with_supplier';
  -- Should return 0
  ```

- [ ] LC data preserved
  ```sql
  SELECT * FROM letter_of_credit WHERE shared_date IS NOT NULL LIMIT 5;
  -- Should show migrated data
  ```

- [ ] Stage edges correct
  ```sql
  SELECT * FROM stage_edges WHERE from_stage = 'lc_opening' OR to_stage = 'lc_opening';
  -- Should show: ip_number → lc_opening → invoice
  ```

- [ ] Old table archived
  ```sql
  SELECT COUNT(*) FROM lc_share_archived;
  -- Should show preserved records
  ```

---

## 🚀 Quick Start

**Fastest way to complete both fixes:**

1. **Refresh browser** (Ctrl+F5) - Frontend changes already applied
2. **Run migration** - Execute `merge_lc_stages.sql` in Supabase
3. **Test** - Create/view shipments to verify everything works

---

## 🔄 Rollback (If Needed)

If you need to revert:

```sql
BEGIN;

-- Restore lc_share table
ALTER TABLE lc_share_archived RENAME TO lc_share;

-- Revert stage updates
UPDATE shipment
SET current_stage = 'lc_shared_with_supplier'
WHERE current_stage = 'lc_opening' 
  AND id IN (
    SELECT shipment_id FROM letter_of_credit 
    WHERE shared_date IS NOT NULL
  );

COMMIT;
```

---

## 📝 Summary of Changes

### ✅ COMPLETED (No Action Needed):
- Frontend: Stage order updated
- Frontend: Stage name changed to "LC Management"
- Frontend: Form fields merged
- Frontend: Old document upload removed

### ⏳ PENDING (Action Required):
- Database: Run `merge_lc_stages.sql`
- Testing: Verify stage flow and data

---

**You're almost done!** Just run the SQL migration and everything will work perfectly. 🚀
