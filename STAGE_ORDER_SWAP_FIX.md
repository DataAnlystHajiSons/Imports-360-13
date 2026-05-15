# 🔄 Stage Order Swap Fix - Proforma & Purchase Order

## 📊 **Problem Identified:**

You swapped the stage order from:
- **OLD**: `availability_confirmation` → `purchase_order` → `proforma` → `invoice`
- **NEW**: `availability_confirmation` → `proforma` → `purchase_order` → `invoice`

But the backend `stage_requirements_met` function still has the **old dependencies**:

```sql
-- WRONG: Old logic
WHEN 'proforma' THEN
  RETURN EXISTS (
    SELECT 1 FROM public.purchase_order po  -- ❌ Expects purchase_order first!
    WHERE po.shipment_id = p_shipment_id AND po.po_file_url IS NOT NULL
  );
```

## 🔧 **Solution:**

### **1. Updated Stage Requirements:**
```sql
-- FIXED: New logic matching the swapped order
WHEN 'proforma' THEN
  RETURN EXISTS (
    SELECT 1 FROM public.availability_confirmation ac  -- ✅ Now depends on availability_confirmation
    WHERE ac.shipment_id = p_shipment_id AND ac.available = TRUE
  );

WHEN 'purchase_order' THEN
  RETURN EXISTS (
    SELECT 1 FROM public.proforma_invoice pi  -- ✅ Now depends on proforma
    WHERE pi.shipment_id = p_shipment_id AND pi.file_url IS NOT NULL
  );
```

### **2. Updated Stage Edges:**
```sql
-- OLD edges (removed):
availability_confirmation → purchase_order → proforma → invoice

-- NEW edges (added):
availability_confirmation → proforma → purchase_order → invoice
```

## 🚀 **How to Apply Fix:**

### **Method 1: Run SQL File**
```sql
-- Execute the complete fix
\i fix_stage_order_swap.sql
```

### **Method 2: Manual Steps**
1. **Update Function**: Run the new `stage_requirements_met` function
2. **Update Edges**: Delete old stage_edge records and insert new ones
3. **Verify**: Check that the new order is working

## 🧪 **Testing:**

After applying the fix:
1. **Test Proforma Stage**: Should advance after `availability_confirmation` is complete
2. **Test Purchase Order Stage**: Should advance after `proforma` document is uploaded
3. **Test Invoice Stage**: Should advance after `purchase_order` document is uploaded

## 📋 **New Flow:**
1. `availability_confirmation` (complete) ✅
2. `proforma` (upload document) ✅  
3. `purchase_order` (upload document) ✅
4. `invoice` (upload document) ✅

The fix ensures both frontend stage order and backend requirements are **synchronized**! 🎯