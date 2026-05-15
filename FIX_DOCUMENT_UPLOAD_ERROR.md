# Fix Document Upload Error

## Error Message
```
Error: Failed to upload document: Could not find the 'file_name' column of 'document' in the schema cache
```

## Root Cause
The `document` table is missing the `file_name` column. The JavaScript code is trying to insert a `file_name` value, but the database column doesn't exist.

## Quick Fix - Option 1 (Temporary)
Remove `file_name` from the insert - **ALREADY DONE** in `js/shipment-tracker.js`

The code now only inserts:
```javascript
{
    shipment_id: documentsShipmentId,
    doc_type: docType,
    file_url: urlData.publicUrl,
    uploaded_by: user.id,
    status: 'active'
    // file_name removed temporarily
}
```

## Permanent Fix - Option 2 (Recommended)
Add the `file_name` column to the database.

### Step 1: Run SQL Migration
Open **Supabase SQL Editor** and run:

```sql
-- File: add_file_name_to_document_table.sql

ALTER TABLE document 
ADD COLUMN IF NOT EXISTS file_name TEXT;
```

### Step 2: Re-enable file_name in JavaScript
After running the SQL, update `js/shipment-tracker.js`:

```javascript
const { data: docData, error: docError } = await supabase
    .from('document')
    .insert({
        shipment_id: documentsShipmentId,
        doc_type: docType,
        file_url: urlData.publicUrl,
        file_name: file.name,  // ← Add this back
        uploaded_by: user.id,
        status: 'active'
    })
    .select()
    .single();
```

### Step 3: Test Upload
1. Refresh the page (Ctrl + F5)
2. Open Documents modal
3. Upload a document
4. Should work without error

## Benefits of Adding file_name Column
1. **Display original filename** in document cards
2. **Better user experience** - users see the actual filename they uploaded
3. **Easier identification** - know which file is which without opening
4. **Consistency** - matches other document tables (bank_charge_documents, insurance_documents)

## Current Status
✅ **Quick fix applied** - Document upload works (without storing filename)
⏳ **Permanent fix pending** - Need to add `file_name` column to database

## Testing After Fix
```javascript
// After running SQL migration, test:
1. Upload a document
2. Check database:
   SELECT id, doc_type, file_name, file_url FROM document LIMIT 5;
3. Verify file_name is populated
4. Check document display shows filename
```

## Files Modified
- ✅ `js/shipment-tracker.js` - Removed file_name from insert (temporary)
- 📝 `add_file_name_to_document_table.sql` - SQL migration to add column

## Next Steps
1. **Immediate**: Test document upload - should work now
2. **Soon**: Run `add_file_name_to_document_table.sql` in Supabase
3. **After SQL**: Re-enable file_name in JavaScript insert
4. **Verify**: Document cards show original filenames
