# 📋 Document Requirements Management Guide

## 🎯 Admin Interface Created

**File**: `admin-document-requirements.html`

**Access**: Open this file in your browser to manage document requirements

---

## 🔧 Features

### 1. View All Requirements
- See all document requirements configured
- Filter by Mode of Transport
- Filter by Inco-term
- Filter by Mandatory/Optional

### 2. Statistics Dashboard
- Total requirements count
- Mandatory vs Optional breakdown
- Transport modes coverage

### 3. Add New Requirement
Click **"Add Requirement"** button to add new document requirement:
- Select Mode of Transport (Sea, Air, Land, Rail)
- Select Inco-term (or leave blank for "all inco-terms")
- Enter document type code (e.g., `bill_of_lading`)
- Enter document name (e.g., "Bill of Lading")
- Add description
- Mark as Mandatory or Optional

### 4. Edit Requirement
Click **"Edit"** button on any requirement card to modify:
- Change mandatory/optional status
- Update description
- Modify inco-term applicability

### 5. Delete Requirement
Click **"Delete"** button to remove a requirement (with confirmation)

---

## 📝 How Requirements Work

### Structure

Each requirement has:
- **Mode of Transport**: sea, air, land, rail
- **Inco-term**: EXW, FOB, CFR, etc. (or NULL for all)
- **Document Type**: Unique code (e.g., `commercial_invoice`)
- **Document Name**: Display name (e.g., "Commercial Invoice")
- **Description**: What this document is for
- **Is Mandatory**: Required for completion or optional

### Logic

When a shipment is created with:
- **Mode**: Sea
- **Inco-term**: FOB

The system shows requirements where:
- `mode_of_transport = 'sea'` AND
- (`inco_term IS NULL` OR `inco_term = 'FOB'`)

**Example:**
```
Sea + NULL inco-term → Applies to ALL sea shipments
Sea + FOB → Applies ONLY to Sea + FOB shipments
```

---

## 📋 Pre-configured Requirements

The system comes with these requirements:

### Common Documents (All Shipments)
- ✅ Commercial Invoice (Mandatory)
- ✅ Packing List (Mandatory)
- ⚠️ Certificate of Origin (Optional)

### Sea-Specific
- ✅ Bill of Lading (Mandatory)
- ✅ Arrival Notice (Mandatory)

### Air-Specific
- ✅ Air Waybill (Mandatory)

### FOB-Specific (Buyer arranges)
- ✅ Freight Booking Confirmation (Mandatory)
- ✅ Insurance Certificate (Mandatory)

### CFR-Specific (Seller pays freight)
- ✅ Freight Invoice (Mandatory)
- ✅ Insurance Certificate (Mandatory)

### CIF-Specific (Seller pays freight + insurance)
- ✅ Freight Invoice (Mandatory)
- ✅ Insurance Policy (Mandatory)

### Customs (All Imports)
- ✅ Goods Declaration (Mandatory)
- ✅ Duty Payment Receipt (Mandatory)
- ✅ Release Order (Mandatory)

---

## 🎯 Use Cases

### Add New Document Type

**Scenario**: You want to require "Phytosanitary Certificate" for all air shipments

**Steps**:
1. Click **"Add Requirement"**
2. Mode: **Air**
3. Inco-term: **(Leave blank)**
4. Doc Type: `phytosanitary_certificate`
5. Doc Name: `Phytosanitary Certificate`
6. Description: `Plant health certificate for agricultural products`
7. Mandatory: **✅ Checked**
8. Click **"Save"**

**Result**: All air shipments will now require this document

---

### Make Document Optional

**Scenario**: Certificate of Origin should be optional for EXW shipments

**Steps**:
1. Find "Certificate of Origin" card
2. Click **"Edit"**
3. Uncheck **"This document is mandatory"**
4. Click **"Save"**

**Result**: Certificate becomes optional

---

### Add Inco-term Specific Document

**Scenario**: DDP shipments need "Import License"

**Steps**:
1. Click **"Add Requirement"**
2. Mode: **Sea**
3. Inco-term: **DDP**
4. Doc Type: `import_license`
5. Doc Name: `Import License`
6. Description: `Required for DDP deliveries`
7. Mandatory: **✅ Checked**
8. Click **"Save"**

**Result**: Only Sea + DDP shipments require this

---

## 🔍 Filtering & Search

### Filter by Mode
Select "Sea" → Shows only sea transport requirements

### Filter by Inco-term
Select "FOB" → Shows only FOB-specific requirements

### Filter by Type
Select "Mandatory Only" → Shows only mandatory documents

### Combine Filters
Sea + FOB + Mandatory → Shows mandatory docs for Sea/FOB shipments

---

## 🎨 Visual Indicators

### Requirement Cards Show:
- 🔵 **Blue Badge**: Mode of Transport
- 🟣 **Purple Badge**: Inco-term (or "All Terms")
- 🔴 **Red Badge**: Mandatory
- 🟢 **Green Badge**: Optional

### Quick Scan:
- Red badges = Must have
- Green badges = Nice to have
- "All Terms" = Applies to all inco-terms for that mode

---

## 🚀 Integration

### Frontend Impact

When user opens **Documents modal**:
1. System reads shipment's Mode + Inco-term
2. Calls `get_required_documents(shipment_id)`
3. Shows checklist:
   - ✅ Green check = Uploaded
   - ⚠️ Orange warning = Missing
   - Percentage: "75% Complete"

### Circular Tracker Impact

**Documents stage**:
- 🟠 **Blinks Orange** = Mandatory docs missing
- 🟢 **Green** = All mandatory docs uploaded
- Always accessible (like Bills stage)

---

## 📊 Reports You Can Generate

### Missing Documents Report
```sql
SELECT 
  s.reference_code,
  s.mode_of_transport,
  s.inco_term,
  vsd.completion_percentage,
  vsd.mandatory_uploaded || '/' || vsd.total_mandatory_required as status
FROM shipment s
JOIN v_shipment_document_summary vsd ON vsd.shipment_id = s.id
WHERE vsd.can_complete = false
ORDER BY vsd.completion_percentage;
```

### Shipments Ready to Complete
```sql
SELECT reference_code, current_stage
FROM v_shipment_document_summary
WHERE can_complete = true;
```

---

## 🎯 Best Practices

### Document Type Naming
✅ **Good**: `bill_of_lading`, `commercial_invoice`, `insurance_certificate`  
❌ **Bad**: `BL`, `Invoice123`, `Ins Cert`

Use descriptive, lowercase, underscore-separated names

### Descriptions
Be clear and specific:
- ✅ "Original bill of lading from shipping company"
- ❌ "B/L doc"

### Mandatory vs Optional
- **Mandatory**: Legal/compliance requirements
- **Optional**: Nice-to-have, internal tracking

### Inco-term Specificity
- Leave blank if applies to ALL inco-terms for that mode
- Specify only when document is unique to that inco-term

---

## 🔒 Security

The admin page uses the same Supabase authentication. Only authenticated users can:
- View requirements
- Add/edit/delete requirements
- Manage document rules

Configure RLS policies if you need role-based access (e.g., only admins can modify).

---

## 🎉 Summary

**You now have:**
- ✅ Admin interface to manage document requirements
- ✅ Filter and search capabilities
- ✅ Add/edit/delete functionality
- ✅ Real-time statistics
- ✅ Visual indicators for easy scanning
- ✅ Integration with shipment tracker

**Access the admin page**: Open `admin-document-requirements.html` in your browser! 🚀
