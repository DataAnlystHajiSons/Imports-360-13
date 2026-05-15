# Stage Swap Summary: Original Docs ↔ Non Negotiable Docs

## Overview
Successfully swapped the order of "Original Docs" and "Non Negotiable Docs" stages in the shipment workflow.

## New Stage Order
The stages now flow as follows:
```
... → Award Shipment → **Original Docs** → **Non Negotiable Docs** → Bank Endorsement → ...
```

## Changes Made

### 1. Frontend Changes
**File:** `js/shipment-tracker.js`
- Updated `STAGE_ORDER` array to reflect new order
- Original Docs now comes at position 13 (after award_shipment)
- Non Negotiable Docs now comes at position 14 (after original_docs)

### 2. Backend Changes

#### A. Stage Edge Table (`stage_edges.sql`)
Updated the stage transitions:
```sql
('award_shipment', 'original_docs'),          -- NEW: Award → Original Docs
('original_docs', 'non_negotiable_docs'),     -- NEW: Original → Non-Negotiable
('non_negotiable_docs', 'bank_endorsement')   -- NEW: Non-Negotiable → Bank
```

#### B. Stage Requirements Function
**File:** `swap_original_and_non_negotiable_docs.sql`

Updated the `stage_requirements_met` function logic:

**Original Docs Stage (now first):**
- **Requirement:** Shipment must be awarded
- **Check:** `shipment_awarded.awarded = TRUE`

**Non Negotiable Docs Stage (now second):**
- **Requirement:** Original docs must be uploaded  
- **Check:** `original_docs.docs_url IS NOT NULL`

**Bank Endorsement Stage (updated):**
- **Requirement:** Non-negotiable docs must be uploaded
- **Check:** `non_negotiable_docs.file_url IS NOT NULL`

### 3. Documentation Updates
**File:** `Function_related_to_Stages.txt`
- Updated documentation to reflect the swapped logic
- Added comments indicating the swap

## Deployment Steps

### Step 1: Deploy Frontend Changes
The frontend changes are already applied in `js/shipment-tracker.js`. Just refresh the page to see the changes.

### Step 2: Deploy Backend Changes
Run the SQL script in Supabase SQL Editor:
```bash
# Execute this file in Supabase:
swap_original_and_non_negotiable_docs.sql
```

This script will:
1. Update the `stage_edge` table (wrapped in a transaction)
2. Replace the `stage_requirements_met` function
3. Show verification query results

### Step 3: Verify the Changes
After running the SQL script, verify with:
```sql
SELECT from_stage, to_stage 
FROM public.stage_edge 
WHERE from_stage IN ('award_shipment', 'original_docs', 'non_negotiable_docs')
   OR to_stage IN ('original_docs', 'non_negotiable_docs', 'bank_endorsement')
ORDER BY 
  CASE from_stage
    WHEN 'award_shipment' THEN 1
    WHEN 'original_docs' THEN 2
    WHEN 'non_negotiable_docs' THEN 3
  END;
```

Expected result:
```
from_stage          | to_stage
--------------------+---------------------
award_shipment      | original_docs
original_docs       | non_negotiable_docs
non_negotiable_docs | bank_endorsement
```

## Impact on Existing Shipments

### Shipments Currently at "Non Negotiable Docs"
- These will now be considered at a later stage in the workflow
- No manual intervention needed

### Shipments Currently at "Original Docs"
- These will now be considered at an earlier stage
- No manual intervention needed

### Shipments Past Both Stages
- No impact, they've already completed both stages

## Testing Checklist
- [ ] Frontend displays stages in correct order
- [ ] Stage transitions work correctly in the circular tracker
- [ ] Timeline shows stages in new order
- [ ] Stage advancement respects new requirements
- [ ] Modal opens correctly for both stages
- [ ] Database queries return expected results

## Files Modified
1. ✅ `js/shipment-tracker.js` - Frontend stage order
2. ✅ `stage_edges.sql` - Reference file for stage transitions
3. ✅ `Function_related_to_Stages.txt` - Documentation
4. ✅ `swap_original_and_non_negotiable_docs.sql` - Deployment script (NEW)
5. ✅ `SWAP_STAGES_SUMMARY.md` - This summary file (NEW)

## Rollback Plan
If you need to revert these changes:

1. Restore the original `STAGE_ORDER` in `js/shipment-tracker.js`
2. Run this SQL to revert backend:
```sql
BEGIN;

DELETE FROM public.stage_edge 
WHERE (from_stage = 'award_shipment' AND to_stage = 'original_docs')
   OR (from_stage = 'original_docs' AND to_stage = 'non_negotiable_docs')
   OR (from_stage = 'non_negotiable_docs' AND to_stage = 'bank_endorsement');

INSERT INTO public.stage_edge (from_stage, to_stage) VALUES
('award_shipment', 'non_negotiable_docs'),
('non_negotiable_docs', 'original_docs'),
('original_docs', 'bank_endorsement');

COMMIT;
```

3. Restore the original `stage_requirements_met` function from `Function_related_to_Stages.txt` backup

---
**Date:** 2025-10-24
**Status:** ✅ Complete - Ready for Deployment
