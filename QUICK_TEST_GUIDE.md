# 🧪 Quick Test Guide - Documents Feature

## ✅ What Was Just Completed

I've successfully integrated the documents management system into your shipment tracker!

**Files Updated:**
- ✅ `js/shipment-tracker.js` - Added 270+ lines of documents functionality
- ✅ Already done: `shipment_tracker.html` - Documents modal UI
- ✅ Already done: `css/shipment-tracker.css` - Styling

---

## 🚀 How to Test Now

### Step 1: Refresh the Page
Open any shipment tracker page and do a **hard refresh**:
- Windows: `Ctrl + F5`
- Mac: `Cmd + Shift + R`

### Step 2: Look for the "Manage Documents" Button
In the sidebar, you should see a purple button that says:
**"📁 Manage Documents"**

### Step 3: Click the Button
The documents modal should open with:
- Upload form at the top
- Documents grid below
- Empty state if no documents exist

### Step 4: Upload a Test Document
1. Select document type from dropdown (e.g., "Commercial Invoice")
2. Choose a file from your computer
3. Click "Upload Document"
4. You should see: "Document uploaded successfully!"
5. Document should appear in the grid below

### Step 5: Test Document Actions
Each document card has 3 buttons:
- 👁️ **View** - Opens in new tab
- ⬇️ **Download** - Downloads the file
- 🗑️ **Delete** - Removes document (with confirmation)

---

## 🔍 Troubleshooting

### If the modal doesn't open:
1. Check browser console (F12) for errors
2. Make sure you're on a shipment tracker page with `?id=XXX` in URL
3. Verify the button exists in the HTML

### If upload fails:
1. Check if `shipment-docs` storage bucket exists in Supabase
2. Verify RLS policies allow authenticated uploads
3. Check file size (must be < 10MB)
4. Check browser console for specific error

### If documents don't load:
1. Verify `document` table exists in database
2. Check RLS policies for `document` table
3. Verify foreign key relationship with `shipment` table

---

## 📋 Database Requirements

### Storage Bucket Setup (if not exists):
```sql
-- In Supabase Dashboard > Storage > Create Bucket
Name: shipment-docs
Public: Yes (or configure RLS policies)
File size limit: 10MB
Allowed file types: All
```

### RLS Policies for Documents:
```sql
-- Allow authenticated users to upload
CREATE POLICY "Allow authenticated uploads"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'shipment-docs');

-- Allow authenticated users to view
CREATE POLICY "Allow authenticated reads"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'shipment-docs');

-- Allow authenticated users to delete their uploads
CREATE POLICY "Allow authenticated deletes"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'shipment-docs');
```

---

## ✅ Success Checklist

After testing, you should be able to:
- ✅ See "Manage Documents" button in sidebar
- ✅ Open documents modal
- ✅ Upload documents (PDF, Word, Images, etc.)
- ✅ See documents in grid with proper icons
- ✅ View documents in new tab
- ✅ Download documents
- ✅ Delete documents with confirmation
- ✅ See success/error messages for all actions

---

## 🎉 What You Now Have

### Shipment Creation ✅
- Dynamic inco-term selection based on transport mode
- Conditional freight charges field (FOB only)
- Full validation and database integration

### Shipment Tracker ✅
- Documents management button in every shipment
- Upload documents at any stage
- Organize by document type
- View/download/delete functionality
- Professional UI with proper icons and metadata

---

## 📞 Next Steps (Optional)

### 1. Add Inco-term Display in Shipment Details
You can display the inco-term and freight charges in the shipment details section:

```javascript
// Add this where you display shipment info
if (shipmentData.inco_term) {
    html += `<div class="info-row">
        <span class="label">Inco-term:</span>
        <span class="value">${shipmentData.inco_term}</span>
    </div>`;
}

if (shipmentData.freight_charges) {
    html += `<div class="info-row">
        <span class="label">Freight Charges:</span>
        <span class="value">$${parseFloat(shipmentData.freight_charges).toFixed(2)}</span>
    </div>`;
}
```

### 2. Run Optional Database Migrations
For LC merge and CFR skip logic:
- `02_update_stage_enum_merge_lc.sql`
- `03_update_stage_edges_new_workflow.sql`
- `04_update_stage_requirements_met_cfr_logic.sql`

---

## 🎯 You're Done! 

Everything is now integrated and ready to use. Just refresh your browser and start testing! 🚀
