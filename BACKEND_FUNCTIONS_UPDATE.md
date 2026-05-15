# 🔧 Critical Backend Update Required

## Issue Identified
The `advance_stage` function calls `stage_requirements_met(p_shipment_id, p_to_stage)` but this function is **missing** from your backend, causing:

❌ **All stage advancement to fail**
❌ **Frontend auto-advancement to be blocked**
❌ **Manual stage progression to be broken**

## Solution: Missing Backend Function

I've created the `stage_requirements_met` function that needs to be added to your Supabase database.

### **File Created: `stage_requirements_met.sql`**

This function implements the exact logic you requested:

### **🎯 Forecast Stage Logic:**
- ✅ **Always allows** advancement to forecast (starting stage)
- ✅ **To advance to enlistment_verification**: Checks if product exists in forecast table for current year

### **🎯 Enlistment Verification Stage Logic:**
- ✅ **To advance to availability_confirmation**: Checks if `enlistment_status = true` in forecast table for current year

### **🎯 All Other Stages Logic:**
- ✅ **Sequential validation**: Each stage requires the previous stage to be completed
- ✅ **Uses existing `v_shipment_stage_checklist` view** for validation
- ✅ **Maintains data integrity** throughout the workflow

## Function Features

### **✅ Year-Based Validation:**
```sql
-- Only considers current year forecasts
EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
```

### **✅ Product-Specific Validation:**
```sql
-- Links shipment products to forecast entries
SELECT sp.product_variety_id FROM public.shipment_products sp
WHERE sp.shipment_id = p_shipment_id
```

### **✅ Stage Completion Validation:**
```sql
-- Uses existing checklist view for all stages
SELECT availability_confirmation_done FROM public.v_shipment_stage_checklist
WHERE shipment_id = p_shipment_id
```

### **✅ Error Handling:**
- Comprehensive exception handling
- Warning logs for debugging
- Safe fallback behavior

## Implementation Required

### **Step 1: Add to Database**
Run the SQL in `stage_requirements_met.sql` in your Supabase SQL Editor:

```sql
-- Copy and paste the entire content of stage_requirements_met.sql
-- This will create the missing function
```

### **Step 2: Grant Permissions (if needed)**
```sql
GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO service_role;
```

### **Step 3: Test the Function**
```sql
-- Test forecast stage requirement
SELECT public.stage_requirements_met('your-shipment-id'::uuid, 'enlistment_verification'::public.stage);

-- Test enlistment stage requirement  
SELECT public.stage_requirements_met('your-shipment-id'::uuid, 'availability_confirmation'::public.stage);
```

## Stage Requirements Summary

| **From Stage** | **To Stage** | **Requirement** |
|---|---|---|
| `forecast` | `enlistment_verification` | Product exists in forecast for current year |
| `enlistment_verification` | `availability_confirmation` | `enlistment_status = true` in forecast |
| `availability_confirmation` | `purchase_order` | Previous stage completed |
| `purchase_order` | `proforma` | Previous stage completed |
| `proforma` | `invoice` | Previous stage completed |
| ... | ... | ... (all subsequent stages) |

## Impact After Implementation

### **✅ Will Enable:**
- ✅ **Automatic stage advancement** for forecast and enlistment stages
- ✅ **Manual stage progression** throughout the workflow
- ✅ **Data-driven validation** based on forecast table
- ✅ **Complete workflow integrity**

### **✅ Will Fix:**
- ✅ **"Requirements not met" errors** during stage advancement
- ✅ **Blocked stage progression** in frontend
- ✅ **Broken workflow continuity**

## Validation Logic Details

### **Forecast → Enlistment Verification:**
```sql
-- Checks this query returns true:
SELECT EXISTS(
    SELECT 1 FROM public.forecast f
    WHERE f.product_variety_id = shipment_product_variety_id
    AND EXTRACT(YEAR FROM f.date_of_sowing) = CURRENT_YEAR
)
```

### **Enlistment Verification → Availability Confirmation:**
```sql
-- Checks this query returns true:
SELECT COALESCE(f.enlistment_status, false)
FROM public.forecast f
WHERE f.product_variety_id = shipment_product_variety_id
AND EXTRACT(YEAR FROM f.date_of_sowing) = CURRENT_YEAR
```

## Priority: CRITICAL 🚨

**This function is essential for your shipment workflow to function.**

Without it:
- No stages can advance (manual or automatic)
- Frontend auto-advancement will always fail
- Users will be stuck in forecast stage

**Add this function to your database immediately to restore full functionality.**