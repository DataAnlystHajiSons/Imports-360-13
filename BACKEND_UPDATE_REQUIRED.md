# 🔄 Backend Function Update Required

## Current Issue
The existing `stage_requirements_met` function **does NOT implement** your requested forecast-based logic:

### **Current Backend Logic (Lines 369-376):**
```sql
WHEN 'enlistment_verification' THEN
  RETURN FALSE; -- ❌ Completely blocks auto-advancement

WHEN 'availability_confirmation' THEN
  -- ❌ Requires manual verification record with document upload
  RETURN EXISTS (
    SELECT 1 FROM public.enlistment_verification ev
    WHERE ev.shipment_id = p_shipment_id 
    AND ev.verified = TRUE 
    AND ev.verification_doc_url IS NOT NULL
  );
```

### **Your Required Logic:**
```sql
WHEN 'enlistment_verification' THEN
  -- ✅ Check if product exists in forecast for current year
  
WHEN 'availability_confirmation' THEN  
  -- ✅ Check if enlistment_status = true in forecast
```

## Solution

### **File Created: `backend_function_update.sql`**

This contains the updated `stage_requirements_met` function that implements:

#### **✅ Forecast Stage Logic:**
- Always allows starting at forecast stage
- **To advance to enlistment_verification**: Checks if product exists in forecast table for current year

#### **✅ Enlistment Verification Logic:**  
- **To advance to availability_confirmation**: Checks if `enlistment_status = true` in forecast table for current year

#### **✅ All Other Stages:**
- Keeps existing logic unchanged
- Maintains all your current business rules

## Key Changes Made

### **1. Added Current Year Validation:**
```sql
v_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
```

### **2. Added Product Variety Lookup:**
```sql
SELECT sp.product_variety_id INTO v_product_variety_id
FROM public.shipment_products sp
WHERE sp.shipment_id = p_shipment_id
```

### **3. Updated Enlistment Verification Logic:**
```sql
WHEN 'enlistment_verification' THEN
  SELECT EXISTS(
    SELECT 1 FROM public.forecast f
    WHERE f.product_variety_id = v_product_variety_id
    AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
  ) INTO v_forecast_exists;
  
  RETURN v_forecast_exists;
```

### **4. Updated Availability Confirmation Logic:**
```sql
WHEN 'availability_confirmation' THEN
  SELECT COALESCE(f.enlistment_status, false) INTO v_enlistment_status
  FROM public.forecast f
  WHERE f.product_variety_id = v_product_variety_id
  AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year;
  
  RETURN v_enlistment_status;
```

## Implementation Steps

### **Step 1: Update Database Function**
1. Open **Supabase Dashboard** → **SQL Editor**
2. Copy contents of `backend_function_update.sql`
3. Execute the SQL to replace the existing function

### **Step 2: Test the Updated Logic**
```sql
-- Test forecast stage advancement
SELECT public.stage_requirements_met('shipment-id'::uuid, 'enlistment_verification'::public.stage);

-- Test enlistment stage advancement
SELECT public.stage_requirements_met('shipment-id'::uuid, 'availability_confirmation'::public.stage);
```

## Expected Behavior After Update

### **✅ Forecast Stage:**
- Shipment loads → Auto-checks forecast table
- **If product found in current year forecast** → Automatically advances to `enlistment_verification`
- **If not found** → Stays in forecast with warning message

### **✅ Enlistment Verification Stage:**  
- Shipment in enlistment stage → Auto-checks `enlistment_status`
- **If `enlistment_status = true`** → Automatically advances to `availability_confirmation`
- **If false or not found** → Stays in stage with warning message

### **✅ All Other Stages:**
- Continue working exactly as before
- No changes to existing business logic

## Impact

### **Before Update:**
- ❌ Frontend auto-advancement fails (backend blocks with `FALSE`)
- ❌ Manual advancement may also be blocked
- ❌ Forecast-based logic not implemented

### **After Update:**
- ✅ Frontend auto-advancement works perfectly
- ✅ Manual advancement continues to work  
- ✅ Forecast-based validation implemented
- ✅ Year-based filtering active
- ✅ Complete workflow functionality restored

## Priority: HIGH 🚨

**This backend update is essential for the auto-advancement feature to work.**

The frontend logic I implemented is ready and waiting for this backend function update to enable the complete forecast-based auto-advancement workflow you requested.