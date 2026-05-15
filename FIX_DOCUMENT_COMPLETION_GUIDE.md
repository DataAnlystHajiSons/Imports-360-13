# Fix Document Completion Percentage - Deployment Guide

## Problem Identified
The completion percentage shows 0% even when documents are uploaded because:

1. **Trailing spaces** in `required_document_config.doc_type` values (e.g., `'Import Permit '` instead of `'import_permit'`)
2. **Wrong naming convention** - Config uses descriptive names ("Import Permit") instead of technical names ("ip_number")

## Root Cause
```sql
-- Required docs from config:
'Import Permit '    -- ❌ Has trailing space
'proforma Invoice ' -- ❌ Has trailing space, wrong case
'Purchase Order '   -- ❌ Has trailing space, wrong format

-- Actual docs in database:
'ip_number'         -- ✅ Correct
'proforma_invoice'  -- ✅ Correct
'purchase_order'    -- ✅ Correct
```

The SQL function checks: `d.doc_type = rdc.doc_type` (exact match)
Since `'ip_number' ≠ 'Import Permit '`, it returns `is_uploaded: false`

## Solution
Run the SQL script to fix the `required_document_config` table with correct values.

## Deployment Steps

### Step 1: Backup Current Data
```sql
-- Create backup table
CREATE TABLE required_document_config_backup AS 
SELECT * FROM required_document_config;

-- Verify backup
SELECT COUNT(*) FROM required_document_config_backup;
```

### Step 2: Run the Fix Script
1. Open **Supabase SQL Editor**
2. Copy and paste the contents of `fix_required_documents_config.sql`
3. **Execute the script**

### Step 3: Verify the Fix
```sql
-- Check for trailing spaces (should return 0 rows)
SELECT doc_type, LENGTH(doc_type), doc_name
FROM required_document_config
WHERE doc_type LIKE '% ';

-- Check doc_types match dropdown values
SELECT DISTINCT doc_type, doc_name, is_mandatory
FROM required_document_config
ORDER BY doc_type;
```

### Step 4: Test in Browser
1. **Refresh** the shipment tracker page (Ctrl + F5)
2. **Click** "Manage Documents" button
3. **Check console** for debug logs:
   ```
   ✅ Uploaded docs: 5 (should be > 0 if documents exist)
   📋 Required Documents Data: [...] (is_uploaded should be true)
   ```
4. **Check completion badge**: Should show correct percentage (e.g., 100% if all required docs uploaded)

### Step 5: Check Different Shipments
Test with shipments that have:
- ✅ All required documents uploaded (should show 100%)
- ⚠️ Some documents missing (should show correct percentage like 60%, 80%)
- ❌ No documents uploaded (should show 0%)

## Expected Results

### Before Fix:
```javascript
📊 Mandatory docs: 5
✅ Uploaded docs: 0  // ❌ Wrong!
🔍 Missing docs: ['Import Permit ', 'proforma Invoice ', ...] // ❌ With spaces!
```

### After Fix:
```javascript
📊 Mandatory docs: 5
✅ Uploaded docs: 5  // ✅ Correct!
📝 Uploaded docs list: ['ip_number', 'proforma_invoice', 'purchase_order', ...]
```

## Rollback (if needed)
```sql
-- Restore from backup
DELETE FROM required_document_config;
INSERT INTO required_document_config 
SELECT * FROM required_document_config_backup;

-- Clean up backup table
DROP TABLE required_document_config_backup;
```

## Notes
- The fix updates the `required_document_config` table to use the same `doc_type` values as the dropdown in `shipment_tracker.html`
- All existing uploaded documents will now be correctly matched
- Future uploads will also work correctly
- The completion percentage will automatically update

## Files Modified
- Created: `fix_required_documents_config.sql`
- Modified: `js/shipment-tracker.js` (added debug logging)
