# 📋 Deployment Guide: Updated Shipment Completion Logic

## 🎯 Overview

This update changes the shipment completion logic to mark a shipment as **completed** when:
1. ✅ **`per_unit_rate` > 0** in the `costing` table (Bills are fully calculated)
2. ✅ **`current_stage` = 'bills'** (All previous stages are completed)

### Previous Logic
```sql
-- Old: Triggered on bills table, checked if costing field is NOT NULL
IF NEW.costing IS NOT NULL THEN
    UPDATE shipment SET status = 'completed'
```

### New Logic
```sql
-- New: Triggered on costing table, checks per_unit_rate > 0 AND stage = 'bills'
IF NEW.per_unit_rate > 0 AND current_stage = 'bills' THEN
    UPDATE shipment SET status = 'completed'
```

---

## 📦 Files Involved

| File | Purpose |
|------|---------|
| `update_shipment_completion_logic.sql` | Main trigger update script |
| `test_completion_logic.sql` | Test script to verify functionality |
| `DEPLOYMENT_GUIDE_COMPLETION_LOGIC.md` | This deployment guide |

---

## 🚀 Deployment Steps

### Step 1: Backup Current Database

```sql
-- Backup the current trigger definition
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_name = 'update_shipment_status_to_completed';

-- Backup current shipment statuses for rollback
CREATE TABLE shipment_status_backup AS
SELECT id, status, current_stage, created_at
FROM shipment
WHERE status = 'completed';
```

### Step 2: Run the Trigger Update Script

Execute the main update script in your Supabase SQL Editor or psql:

```bash
# Option 1: Via Supabase Dashboard
1. Go to Supabase Dashboard > SQL Editor
2. Open: update_shipment_completion_logic.sql
3. Click "Run"

# Option 2: Via psql
psql -h <your-host> -U postgres -d <your-db> -f update_shipment_completion_logic.sql
```

### Step 2.5: 🆕 Run the Migration Script (For Existing Shipments)

**IMPORTANT**: This step applies the new logic to existing shipments in the database.

Execute the migration script:

```bash
# Option 1: Via Supabase Dashboard
1. Go to Supabase Dashboard > SQL Editor
2. Open: migrate_existing_shipments_completion.sql
3. Click "Run"

# Option 2: Via psql
psql -h <your-host> -U postgres -d <your-db> -f migrate_existing_shipments_completion.sql
```

**What the migration does:**
- ✅ Analyzes current data (pre-migration report)
- ✅ Creates automatic backup table
- ✅ Shows dry-run preview of changes
- ✅ Updates existing shipments where `current_stage = 'bills'` AND `per_unit_rate > 0`
- ✅ Runs validation checks
- ✅ Provides rollback capability

**Migration is SAFE:**
- Automatic backup created before any changes
- Dry-run preview shows exactly what will change
- Rollback script included
- Validation checks ensure data integrity

### Step 3: Verify Trigger Installation

```sql
-- Check if trigger was created successfully
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_costing_update_or_insert';

-- Expected Output:
-- trigger_name: on_costing_update_or_insert
-- event_manipulation: INSERT, UPDATE
-- event_object_table: costing
-- action_statement: EXECUTE FUNCTION update_shipment_status_to_completed()
```

### Step 4: Run Tests

Execute the test script to validate the logic:

```sql
-- Run the comprehensive test suite
\i test_completion_logic.sql

-- OR paste the contents into Supabase SQL Editor and run
```

**Expected Test Results:**
- ✅ TEST 1: Shipment at bills stage + per_unit_rate > 0 → **COMPLETED**
- ✅ TEST 2: Shipment NOT at bills stage + per_unit_rate > 0 → **NOT COMPLETED**
- ✅ TEST 3: Shipment at bills stage + per_unit_rate = 0 → **NOT COMPLETED**
- ✅ TEST 4: Shipment at bills stage + per_unit_rate = NULL → **NOT COMPLETED**

### Step 5: Verify in Application

1. **Open Shipment Tracker** for a shipment at 'bills' stage
2. **Click on Bills circle** to open the modal
3. **Fill in all fields** and ensure calculations run
4. **Verify `per_unit_rate` is calculated** and greater than 0
5. **Click Save**
6. **Check shipment status** - it should now be 'completed'

---

## 🧪 Manual Testing Checklist

- [ ] Shipment advances through all stages correctly
- [ ] Bills stage modal opens and displays all fields
- [ ] Auto-calculations work for `total`, `total_cost`, `oh_perc`, `per_unit_rate`
- [ ] When `per_unit_rate > 0` is saved at bills stage → status becomes 'completed'
- [ ] When `per_unit_rate = 0` is saved → status remains 'active'
- [ ] When shipment is NOT at bills stage → status does NOT change to 'completed'
- [ ] Trigger logs NOTICE messages in database logs

---

## 🔄 Rollback Plan

If something goes wrong, you can rollback to the old logic:

```sql
-- Step 1: Drop the new trigger
DROP TRIGGER IF EXISTS on_costing_update_or_insert ON public.costing;
DROP FUNCTION IF EXISTS public.update_shipment_status_to_completed();

-- Step 2: Restore old trigger (from original shipment_completion_trigger.sql)
CREATE OR REPLACE FUNCTION public.update_shipment_status_to_completed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.costing IS NOT NULL THEN
    UPDATE public.shipment
    SET status = 'completed'
    WHERE id = NEW.shipment_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_bill_update_or_insert
  AFTER INSERT OR UPDATE ON public.bills
  FOR EACH ROW EXECUTE PROCEDURE public.update_shipment_status_to_completed();

-- Step 3: Restore shipment statuses from backup
UPDATE shipment s
SET status = b.status
FROM shipment_status_backup b
WHERE s.id = b.id
  AND s.status != b.status;

-- Step 4: Drop backup table
DROP TABLE shipment_status_backup;
```

---

## ⚠️ Important Notes

### 1. **Old `bills` Table Reference**
The old trigger referenced a `bills` table that no longer exists or is not being used for costing. The new trigger correctly uses the `costing` table.

### 2. **Stage Dependency**
The completion now depends on being at the 'bills' stage, ensuring all previous stages are completed before marking the shipment as done.

### 3. **Calculation Dependency**
The `per_unit_rate` is auto-calculated in the frontend using:
```javascript
per_unit_rate = totalCost / qty
```
Ensure `qty` is always > 0 to avoid division by zero.

### 4. **Database Logs**
The trigger includes `RAISE NOTICE` statements for debugging. Check your database logs to see trigger execution details.

---

## 📊 Monitoring

After deployment, monitor these metrics:

```sql
-- Check how many shipments are marked as completed
SELECT 
    COUNT(*) as total_completed,
    COUNT(CASE WHEN current_stage = 'bills' THEN 1 END) as completed_at_bills
FROM shipment
WHERE status = 'completed';

-- Check costing entries with per_unit_rate > 0
SELECT 
    COUNT(*) as total_costing_entries,
    COUNT(CASE WHEN per_unit_rate > 0 THEN 1 END) as with_per_unit_rate
FROM costing;

-- Find shipments at bills stage that should be completed
SELECT 
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    c.per_unit_rate
FROM shipment s
JOIN costing c ON c.shipment_id = s.id
WHERE s.current_stage = 'bills'
  AND c.per_unit_rate > 0
  AND s.status != 'completed';
-- This query should return 0 rows after the trigger is working correctly
```

---

## ✅ Success Criteria

Deployment is successful when:
1. ✅ All 4 test scenarios pass
2. ✅ Trigger is visible in `information_schema.triggers`
3. ✅ Manual testing checklist is complete
4. ✅ No errors in database logs
5. ✅ Application UI shows correct shipment status

---

## 🆘 Support

If you encounter issues:
1. Check database logs for trigger execution messages
2. Verify `per_unit_rate` calculation in browser console
3. Check `costing` table has data for the shipment
4. Verify `current_stage = 'bills'` in shipment table
5. Review trigger definition in information_schema

---

## 📝 Change Log

**Version 1.0** (Current)
- Changed trigger table from `bills` to `costing`
- Changed condition from `costing IS NOT NULL` to `per_unit_rate > 0`
- Added stage validation: `current_stage = 'bills'`
- Added comprehensive logging with RAISE NOTICE
- Added proper error handling

---

**Deployment Date:** _To be filled_  
**Deployed By:** _To be filled_  
**Database Version:** _To be filled_  
**Status:** ⏳ Pending

