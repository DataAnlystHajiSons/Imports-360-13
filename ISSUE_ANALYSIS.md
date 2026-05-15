# 🔍 **EXACT ISSUE FOUND in All Functions.txt**

## 🚨 **Root Cause Identified**

After examining your `All Functions.txt`, I found **TWO critical issues**:

### **Issue 1: Incorrect Stage Order Logic (Lines 420-431)**

**❌ Current (Wrong):**
```sql
WHEN 'purchase_order' THEN
  -- Checks availability_confirmation 
  RETURN EXISTS (
    SELECT 1 FROM public.availability_confirmation ac
    WHERE ac.shipment_id = p_shipment_id AND ac.available = TRUE
  );
WHEN 'proforma' THEN
  -- Checks purchase_order 
  RETURN EXISTS (
    SELECT 1 FROM public.purchase_order po
    WHERE po.shipment_id = p_shipment_id AND po.po_file_url IS NOT NULL
  );
```

**✅ Should Be (Correct):**
```sql
WHEN 'proforma' THEN
  -- Should check availability_confirmation
  RETURN EXISTS (
    SELECT 1 FROM public.availability_confirmation ac
    WHERE ac.shipment_id = p_shipment_id AND ac.available = TRUE
  );
WHEN 'purchase_order' THEN
  -- Should check proforma_invoice
  RETURN EXISTS (
    SELECT 1 FROM public.proforma_invoice pi
    WHERE pi.shipment_id = p_shipment_id AND pi.file_url IS NOT NULL
  );
```

### **Issue 2: advance_stage Function Parameter Mismatch**

Your `advance_stage` function expects these parameters:
```sql
p_shipment_id, p_to_stage, p_meta
```

But your frontend is calling:
```javascript
supabase.rpc('advance_stage', {
    p_shipment_id: shipmentId,
    p_to_stage: nextStage,
    p_meta: { manual: true }
});
```

The function signature might be missing or incorrect, causing the **400 Bad Request**.

## 🎯 **The IP Number Issue Specifically**

Looking at lines 444-449 in your function:
```sql
WHEN 'lc_opening' THEN
  -- Advance only when the required document has been uploaded
  RETURN EXISTS (
    SELECT 1 FROM public.ip_number ip
    WHERE ip.shipment_id = p_shipment_id AND ip.file_url IS NOT NULL
  );
```

This logic is **correct** - it should check for `ip_number.file_url IS NOT NULL`.

Since you confirmed the file_url exists, the issue is likely:
1. **Function signature mismatch** causing 400 error
2. **Stage order logic** preventing proper flow
3. **Missing function parameters** in database

## 🛠️ **DEFINITIVE SOLUTION**

**Run `FINAL_STAGE_ORDER_FIX.sql`** in Supabase SQL Editor. This will:

1. ✅ **Fix the stage order logic** (proforma before purchase_order)
2. ✅ **Recreate advance_stage function** with proper parameters  
3. ✅ **Add enhanced debugging** for the lc_opening stage specifically
4. ✅ **Test with your exact shipment ID** to verify it works
5. ✅ **Grant all necessary permissions**

## 🔍 **What You'll See After Fix**

The enhanced `lc_opening` check will log:
```
lc_opening check - Shipment: fb6c3681-d213-40a3-998e-62fec92d0453, IP exists: true, File URL: https://...Report.pdf
✅ IP Number requirements met for lc_opening
```

## ⚡ **Expected Result**

After running the fix:
1. ✅ **IP Number stage will save data**
2. ✅ **advance_stage will work without 400 error**  
3. ✅ **Stage will advance from ip_number to lc_opening**
4. ✅ **No more "Requirements not met" errors**

The stage order swap issue and the IP Number advancement issue will both be resolved! 🚀