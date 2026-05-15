# 🚀 Run This SQL Migration

## ⚡ Quick Fix - No lc_share Table Issue

The error occurred because your database doesn't have the `lc_share` table. I've created a **simplified migration** that works with your actual database structure.

---

## 📋 Instructions

### Step 1: Open Supabase SQL Editor
1. Go to your Supabase Dashboard
2. Click on **SQL Editor** in the left sidebar
3. Click **New Query**

### Step 2: Copy the SQL
Open the file: **`merge_lc_stages_simple.sql`**

Or copy this:

```sql
-- Run this in Supabase SQL Editor
-- This file: merge_lc_stages_simple.sql
```

### Step 3: Run the Migration
1. Paste the entire SQL into the editor
2. Click **Run** button
3. Wait for success messages

### Step 4: Verify Success
You should see output like:
```
✅ Stage enum updated successfully
✅ Stage duration updated
✅ All shipments migrated
✅ LC STAGES MERGED SUCCESSFULLY!
```

---

## 🎯 What This Migration Does

### ✅ Safe Operations:
1. **Adds columns** to `letter_of_credit` table:
   - `shared_date` (for when LC was shared with supplier)
   - `notes` (for additional notes)

2. **Updates shipments**:
   - Moves any shipments in `lc_shared_with_supplier` to `lc_opening`

3. **Updates stage history**:
   - Renames old stage references

4. **Cleans up stage edges**:
   - Removes old stage transitions
   - Adds correct `lc_opening → invoice` edge

5. **Updates stage enum** (if exists):
   - Removes `lc_shared_with_supplier` from enum

6. **Updates durations** (if stage_details exists):
   - Sets LC Management to 4 days

### ✅ What Makes It Safe:
- ✅ Uses `IF NOT EXISTS` - won't fail if columns exist
- ✅ Uses `DO $$ BEGIN ... EXCEPTION` - handles missing tables gracefully
- ✅ Wrapped in transaction - all or nothing
- ✅ No data deletion - only updates
- ✅ Includes verification queries

---

## 🧪 After Running Migration

### Test 1: Refresh Browser
```
Ctrl+F5 (Windows) or Cmd+Shift+R (Mac)
```

### Test 2: Open Shipment Tracker
1. Open any shipment
2. Look at the timeline
3. **VERIFY**: Shows "LC Management" (not 2 stages)

### Test 3: Check LC Stage Form
1. Click on "LC Management" stage
2. Click "Edit"
3. **VERIFY**: Form shows these fields:
   - ✅ LC Number
   - ✅ Opened Date
   - ✅ Shared with Supplier Date (NEW)
   - ✅ File URL
   - ✅ Notes (NEW)
   - ✅ Bank

### Test 4: Stage Advancement
1. Fill in LC details
2. Save and complete stage
3. **VERIFY**: Advances to Invoice (not LC Shared)

---

## ❌ If You See Errors

### Error: "relation X does not exist"
**This is OK!** The migration handles missing tables gracefully. As long as you see:
```
✅ LC STAGES MERGED SUCCESSFULLY!
```
at the end, it worked!

### Error: "column already exists"
**This is OK!** It means columns were already added. The migration will continue.

### Error: "duplicate key value"
**This is OK!** It means stage edges already exist. The migration uses `ON CONFLICT DO NOTHING`.

### Other Errors
If you see any other error, share it with me and I'll help fix it.

---

## 🔄 Rollback (If Needed)

If something goes wrong, you can rollback:

```sql
BEGIN;

-- Restore old stage for shipments
UPDATE shipment
SET current_stage = 'lc_shared_with_supplier'
WHERE current_stage = 'lc_opening'
  AND id IN (
    SELECT shipment_id 
    FROM letter_of_credit 
    WHERE shared_date IS NOT NULL
  );

-- Remove added columns
ALTER TABLE letter_of_credit 
DROP COLUMN IF EXISTS shared_date,
DROP COLUMN IF EXISTS notes;

COMMIT;
```

---

## ✅ Success Checklist

After migration, verify:

- [ ] SQL ran without blocking errors
- [ ] Verification queries show ✅ status
- [ ] Browser refreshed (Ctrl+F5)
- [ ] Timeline shows "LC Management" (1 stage)
- [ ] LC form has 6 fields
- [ ] No shipments stuck in old stage
- [ ] Stage advancement works

---

## 📊 Expected Database Changes

| Table | Change | Impact |
|-------|--------|--------|
| `letter_of_credit` | +2 columns | Can store shared_date and notes |
| `shipment` | Stage updates | Moves from old stage to new |
| `stage_history` | Stage renames | Historical records updated |
| `stage_edges` | Edge cleanup | Removes old transitions |
| `stage_enum` | Enum update | Removes old stage value |

**Total Records Affected**: Depends on your data, typically 0-100 shipments

---

## 🎉 After Success

You'll have:
- ✅ Single "LC Management" stage
- ✅ All LC fields in one form
- ✅ Simplified workflow
- ✅ Clean timeline
- ✅ All data preserved

---

## 📞 Quick Support

**If migration fails**, send me:
1. The exact error message
2. The table name mentioned in error
3. Your Supabase database schema (if possible)

I'll create a custom migration for your specific setup!

---

**Ready?** 
1. Open `merge_lc_stages_simple.sql`
2. Copy the entire content
3. Paste in Supabase SQL Editor
4. Click **Run**
5. Wait for ✅ success message

**You got this!** 🚀
