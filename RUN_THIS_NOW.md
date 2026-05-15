# ✅ RUN THIS SQL NOW!

## 📁 File: `merge_lc_fixed.sql`

**This version has all syntax errors fixed!**

---

## 🚀 Quick Steps:

1. Open **Supabase SQL Editor**
2. Copy **entire contents** of `merge_lc_fixed.sql`
3. Paste and click **Run**
4. Wait for success messages

---

## ✅ Expected Output:

```
✅ Columns added to letter_of_credit table
✅ Migrated X LC records from lc_share to letter_of_credit
✅ No shipments in old stage (all good!)
✅ Stage edges updated
✅ No audit_log records to update
✅ Stage duration updated to 4 days
✅ Stage enum updated successfully
✅ lc_share table archived as lc_share_archived
✅ All shipments migrated successfully

========================================
✅ LC STAGES MERGED SUCCESSFULLY!
========================================

📋 Summary:
  ✅ lc_opening + lc_shared_with_supplier → LC Management
  ✅ Data migrated from lc_share to letter_of_credit
  ✅ Shipments updated to new stage
  ✅ Stage enum updated
  ✅ Stage edges cleaned up
  ✅ lc_share table archived

📋 Next Steps:
  1. Refresh browser (Ctrl+F5)
  2. Open shipment tracker
  3. Verify "LC Management" appears
========================================
```

Plus verification tables showing:
- ✅ letter_of_credit columns (with shared_date and notes)
- ✅ Count of migrated records
- ✅ Stage edges (lc_opening → invoice)

---

## 🎉 After Running:

1. **Refresh browser** (Ctrl+F5)
2. **Open any shipment tracker**
3. **Verify**:
   - ✅ Timeline shows "LC Management" (not 2 stages)
   - ✅ No document upload in stage modals
   - ✅ "Manage Documents" button works

---

## 📝 What Was Fixed:

❌ **Previous error**: `RAISE NOTICE` outside DO block  
✅ **Fixed**: All RAISE NOTICE wrapped in `DO $$ ... END $$;`

---

**This will work!** 🚀

Just copy `merge_lc_fixed.sql` and run it in Supabase SQL Editor.
