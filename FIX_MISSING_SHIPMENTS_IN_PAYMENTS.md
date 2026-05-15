# Fix Missing Shipments in Supplier Payments Dashboard

## Problem
Not all shipments are listed in the **Supplier Payments Dashboard** (`supplier-payments.html`).

## Root Cause
The `supplier_payments` table only shows shipments that have a payment record. Shipments without a payment record won't appear in the dashboard.

### Why Are Records Missing?
1. **No auto-creation**: When shipments are created, payment records aren't automatically generated
2. **Backfill not run**: The backfill script was never executed for existing shipments
3. **Missing data**: Some shipments may lack required data (payment term, products, supplier)

## Solution

### Step 1: Run the Fix Script
Open **Supabase SQL Editor** and run:
```sql
-- File: fix_missing_supplier_payments.sql
```

This script will:
1. ✅ **Backfill existing shipments** - Creates payment records for all shipments
2. ✅ **Add auto-creation trigger** - Automatically creates payment records for new shipments
3. ✅ **Show verification report** - Lists which shipments are still missing and why

### Step 2: Review the Output
The script shows:
```sql
Total Shipments: 150
Shipments with Payment Records: 145
Shipments Missing Payment Records: 5
```

And lists reasons why some are missing:
- Missing payment term
- No products
- Total amount is 0
- No supplier assigned

### Step 3: Fix Remaining Issues
For shipments still missing payment records:

#### Missing Payment Term:
```sql
-- Update shipment to have a payment term
UPDATE shipment 
SET payment_term_id = (SELECT id FROM payment_terms WHERE term_name = 'Net 30' LIMIT 1)
WHERE id = '<shipment-id>';
```

#### No Products:
Add products to the shipment via the UI or:
```sql
INSERT INTO shipment_products (shipment_id, product_variety_id, quantity, rate)
VALUES ('<shipment-id>', '<product-variety-id>', 1000, 5.50);
```

#### Run the Trigger Manually:
After fixing the data, manually create the payment record:
```sql
DO $$
DECLARE
    v_shipment_id UUID := '<shipment-id>';
    v_supplier_id UUID;
    v_total_amount NUMERIC;
BEGIN
    -- Get supplier
    SELECT pv.supplier_id INTO v_supplier_id
    FROM shipment_products sp
    JOIN product_variety pv ON sp.product_variety_id = pv.id
    WHERE sp.shipment_id = v_shipment_id
    LIMIT 1;
    
    -- Calculate total
    SELECT SUM(quantity * rate) INTO v_total_amount
    FROM shipment_products
    WHERE shipment_id = v_shipment_id;
    
    -- Create payment record
    INSERT INTO supplier_payments (
        shipment_id, supplier_id, payment_term_id, total_amount, amount_paid, status
    )
    SELECT 
        v_shipment_id,
        v_supplier_id,
        s.payment_term_id,
        v_total_amount,
        0,
        'pending'
    FROM shipment s
    WHERE s.id = v_shipment_id
    ON CONFLICT (shipment_id) DO NOTHING;
END $$;
```

## Verification

### Check Total Counts:
```sql
-- Count shipments vs payment records
SELECT 
    (SELECT COUNT(*) FROM shipment) as total_shipments,
    (SELECT COUNT(*) FROM supplier_payments) as payment_records,
    (SELECT COUNT(*) FROM shipment) - (SELECT COUNT(*) FROM supplier_payments) as missing;
```

### Check Dashboard:
1. Refresh `supplier-payments.html` (Ctrl + F5)
2. Count rows in the "All Payments" table
3. Compare with total shipments in `shipment-details.html`
4. Should match or be very close

### Test Auto-Creation:
1. Create a new shipment with products
2. Check if payment record is auto-created:
```sql
SELECT * FROM supplier_payments WHERE shipment_id = '<new-shipment-id>';
```

## Future: Automatic Creation

### Trigger is Now Active
After running the fix script, payment records are automatically created when:
- ✅ Products are added to a shipment
- ✅ Shipment has a payment term
- ✅ Products have valid supplier and rates

### When Records Won't Be Created
Payment records won't be auto-created if:
- ❌ Shipment has no payment term
- ❌ Shipment has no products
- ❌ Total amount is 0
- ❌ No supplier assigned to products

## Expected Results

### Before Fix:
```
Total Shipments: 150
Listed in Payment Dashboard: 120
Missing: 30 (20%)
```

### After Fix:
```
Total Shipments: 150
Listed in Payment Dashboard: 145
Missing: 5 (3% - due to data issues)
```

## Troubleshooting

### "Duplicate key" Error
If you get a duplicate key error:
```
ERROR: duplicate key value violates unique constraint "supplier_payments_shipment_id_key"
```

This means the payment record already exists. Check:
```sql
SELECT * FROM supplier_payments WHERE shipment_id = '<shipment-id>';
```

### Payment Record Created but Wrong Amount
Update the total amount:
```sql
UPDATE supplier_payments
SET total_amount = (
    SELECT SUM(quantity * rate) 
    FROM shipment_products 
    WHERE shipment_id = '<shipment-id>'
)
WHERE shipment_id = '<shipment-id>';
```

### Trigger Not Working
Check if trigger exists:
```sql
SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'trigger_create_supplier_payment';
```

## Summary

1. ✅ Run `fix_missing_supplier_payments.sql` in Supabase
2. ✅ Check verification report for missing shipments
3. ✅ Fix any data issues for remaining shipments
4. ✅ Refresh supplier-payments.html to see all shipments
5. ✅ New shipments will automatically get payment records

After running this fix, all valid shipments should appear in the Supplier Payments Dashboard!
