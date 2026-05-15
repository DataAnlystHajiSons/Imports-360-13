# 🚫 Critical Issue: Missing Backend Stage Requirements Function

## Problem Identified
The `advance_stage` function calls `stage_requirements_met(p_shipment_id, p_to_stage)` on line 24, but this function is **missing** from the backend functions. This means:

❌ **No automatic stage advancement will work**
❌ **Manual stage advancement may also be blocked**
❌ **Stage validation logic is incomplete**

## Required Backend Functions

We need to create the `stage_requirements_met` function that validates whether a shipment can advance to the next stage. Based on your requirements, this function should:

### **1. Forecast Stage Requirements**
```sql
-- For advancing FROM forecast TO enlistment_verification
-- Check: Product exists in forecast table for current year
```

### **2. Enlistment Verification Stage Requirements**  
```sql
-- For advancing FROM enlistment_verification TO availability_confirmation
-- Check: enlistment_status = true in forecast table for current year
```

### **3. All Other Stages**
The function needs to handle requirements for all other stages in your workflow.

## Solution Needed

You need to create this PostgreSQL function in your Supabase database:

```sql
CREATE OR REPLACE FUNCTION public.stage_requirements_met(
    p_shipment_id uuid,
    p_to_stage public.stage
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    -- Variables for validation
    v_current_year integer;
    v_product_variety_id uuid;
    v_forecast_exists boolean;
    v_enlistment_status boolean;
BEGIN
    -- Get current year
    v_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    
    -- Get product variety from shipment
    SELECT sp.product_variety_id INTO v_product_variety_id
    FROM public.shipment_products sp
    WHERE sp.shipment_id = p_shipment_id
    LIMIT 1;
    
    -- Stage-specific requirements
    CASE p_to_stage
        WHEN 'enlistment_verification' THEN
            -- Check if product exists in forecast for current year
            SELECT EXISTS(
                SELECT 1 FROM public.forecast f
                WHERE f.product_variety_id = v_product_variety_id
                AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
            ) INTO v_forecast_exists;
            
            RETURN v_forecast_exists;
            
        WHEN 'availability_confirmation' THEN
            -- Check if enlistment_status is true in forecast
            SELECT f.enlistment_status INTO v_enlistment_status
            FROM public.forecast f
            WHERE f.product_variety_id = v_product_variety_id
            AND EXTRACT(YEAR FROM f.date_of_sowing) = v_current_year
            LIMIT 1;
            
            RETURN COALESCE(v_enlistment_status, false);
            
        -- Add other stage requirements here
        ELSE
            -- For now, allow all other stages (you can add specific logic)
            RETURN true;
    END CASE;
END;
$$;
```

## Impact Without This Function

- ✅ **Frontend auto-advancement logic** - Already implemented
- ❌ **Backend validation** - Missing and blocking progression
- ❌ **Stage requirements** - Not enforced
- ❌ **Data integrity** - Compromised

## Next Steps Required

1. **Create the `stage_requirements_met` function** in your Supabase database
2. **Test stage advancement** with the new validation logic
3. **Extend the function** to handle all your workflow stages
4. **Update frontend** if needed based on backend validation responses

Without this backend function, the auto-advancement logic I implemented in the frontend will not work because the `advance_stage` function will always fail the requirements check.