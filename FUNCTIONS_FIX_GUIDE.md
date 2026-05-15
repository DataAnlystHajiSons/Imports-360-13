# 🔧 Functions Fix Guide

## 🚨 What Happened?

When we merged the LC stages using `CASCADE`, it automatically dropped **dependent functions** because PostgreSQL detected they referenced the old enum values.

### Functions That Were Dropped:
1. ✅ `advance_stage()` - Moves shipment between stages
2. ✅ `stage_requirements_met()` - Checks if stage requirements are met
3. ✅ `get_stage_order()` - Returns stage ordering
4. ✅ `filter_shipments()` - Filters shipments (used by admin dashboard)

---

## 🎯 The Fix

**Run this SQL file in Supabase:**

```
COMPLETE_FIX.sql
```

This will:
- ✅ Recreate the view `v_shipments_with_all_details` with all fields
- ✅ Recreate all 4 dropped functions
- ✅ Update `filter_shipments()` to include `p_mode_of_transport` parameter
- ✅ Add `documents` stage to `get_stage_order()`
- ✅ Add `mode_of_transport` and `inco_term` to view
- ✅ Grant proper permissions
- ✅ Verify everything was created

---

## 📋 Step-by-Step Instructions

### 1. Open Supabase SQL Editor
- Go to your Supabase project
- Click **SQL Editor** in left sidebar

### 2. Copy & Paste SQL
- Open `COMPLETE_FIX.sql`
- Copy entire contents
- Paste into SQL Editor

### 3. Run the SQL
- Click **Run** button (or press Ctrl+Enter)
- Wait for confirmation

### 4. Verify Success
You should see:
```
✅ COMPLETE! View and all functions recreated successfully!

View created:
- v_shipments_with_all_details

Functions created:
- advance_stage(p_shipment_id uuid, p_to_stage stage, p_meta jsonb)
- filter_shipments(11 parameters...)
- get_stage_order(p_stage stage)
- stage_requirements_met(p_shipment_id uuid, p_stage stage)
```

---

## 🧪 Test It

### Test Admin Dashboard:
1. Open `admin-dashboard.html`
2. Should load without errors
3. Shipments table should populate
4. Search/filter should work

### Test Shipment Tracker:
1. Open `shipment_tracker.html?id=<shipment-id>`
2. Should display stages correctly
3. "Next" button should work
4. No console errors

---

## 📚 Function Details

### 1. `advance_stage()`
**Purpose**: Move shipment to next stage

**Parameters**:
- `p_shipment_id` - UUID of shipment
- `p_to_stage` - Target stage
- `p_meta` - Optional metadata (JSON)

**What it does**:
- Validates stage transition
- Checks requirements
- Updates shipment
- Creates audit log

---

### 2. `stage_requirements_met()`
**Purpose**: Check if stage can be advanced

**Parameters**:
- `p_shipment_id` - UUID of shipment
- `p_stage` - Stage to check

**Returns**: `boolean`

**Note**: Currently returns `true` for all stages. You can add specific requirements later.

---

### 3. `get_stage_order()`
**Purpose**: Get numeric order of a stage

**Parameters**:
- `p_stage` - Stage name

**Returns**: `integer` (1-22)

**Used for**: Progress calculations, stage comparisons

---

### 4. `filter_shipments()`
**Purpose**: Filter shipments with multiple criteria

**Parameters** (all optional):
- `p_search_term` - Search in reference/product/supplier
- `p_supplier_id` - Filter by supplier
- `p_clearing_agent_id` - Filter by clearing agent
- `p_bank_id` - Filter by bank
- `p_status` - Filter by status
- `p_shipment_type` - Filter by type
- `p_commodity` - Filter by commodity
- `p_lc_number` - Filter by LC number
- `p_product_name` - Filter by product
- `p_variety_name` - Filter by variety
- `p_mode_of_transport` - **NEW!** Filter by transport mode

**Returns**: `SETOF v_shipments_with_all_details`

**Used by**: Admin dashboard, shipment lists

---

## 🔍 Why CASCADE Dropped Functions

PostgreSQL CASCADE works like this:

```sql
-- When you run:
ALTER TYPE stage DROP VALUE 'lc_shared_with_supplier' CASCADE;

-- PostgreSQL thinks:
"This function uses the 'stage' enum type..."
"What if it references the value being dropped?"
"Better drop it to be safe!"
💥 DROPS FUNCTION
```

**This is why we had to recreate them!**

---

## 🛡️ Prevention for Future

### Before Running CASCADE:

1. **Check Dependencies**:
```sql
SELECT 
  p.proname as function_name,
  pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_depend d ON d.objid = p.oid
JOIN pg_type t ON d.refobjid = t.oid
WHERE t.typname = 'stage';
```

2. **Backup Functions**:
- Export function definitions before CASCADE
- Keep in version control

3. **Use IF NOT EXISTS**:
```sql
CREATE OR REPLACE FUNCTION ...
```

---

## ✅ Checklist

After running `RECREATE_ALL_FUNCTIONS.sql`:

- [ ] Admin dashboard loads without errors
- [ ] Shipments appear in table
- [ ] Search/filter works
- [ ] Shipment tracker opens
- [ ] Stage advancement works
- [ ] No console errors about missing functions
- [ ] Mode of transport filter works (new feature!)

---

## 🆘 Troubleshooting

### Error: "function filter_shipments does not exist"
**Solution**: Run `RECREATE_ALL_FUNCTIONS.sql`

### Error: "type v_shipments_with_all_details does not exist"
**Solution**: The view was also dropped by CASCADE. Run `COMPLETE_FIX.sql` which recreates both the view AND functions.

### Error: "column mode_of_transport does not exist"
**Solution**: Old view doesn't include the field. Run `COMPLETE_FIX.sql` to get the updated view.

### Error: "type stage does not exist"
**Solution**: The enum wasn't created. Run `LAST_ONE.sql` first.

### Error: "permission denied for function"
**Solution**: Check `GRANT EXECUTE` statements ran successfully

---

## 📝 Summary

**Problem**: CASCADE dropped view AND functions when merging LC stages

**Solution**: Run `COMPLETE_FIX.sql`

**What it fixes**:
- ✅ Recreates `v_shipments_with_all_details` view
- ✅ Adds `mode_of_transport` and `inco_term` columns
- ✅ Restores all 4 dropped functions
- ✅ Updates function parameters to match JavaScript calls

**Result**: View + functions restored with improvements

**Time**: ~30 seconds to run

✅ **Admin dashboard will work perfectly after this!**
