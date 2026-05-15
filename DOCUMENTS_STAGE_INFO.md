# 📁 Documents Stage - Complete Information

## 🎯 **Table Name**

Documents from the **"Documents"** stage are saved in:

```
Table: public.document
```

---

## 📊 **Table Structure**

```sql
CREATE TABLE public.document (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id uuid,                    -- Link to shipment
  doc_type text NOT NULL,              -- Type of document (e.g., 'proforma_invoice', 'bill_of_lading')
  file_url text NOT NULL,              -- Public URL of uploaded file
  uploaded_by uuid,                    -- User who uploaded
  uploaded_at timestamp with time zone DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,  -- Additional metadata
  status text DEFAULT 'active',        -- 'active', 'archived', 'deleted', 'replaced'
  file_size bigint,                    -- File size in bytes
  notes text,                          -- Optional notes
  category_id uuid,                    -- Link to document_category
  
  -- Foreign Keys
  CONSTRAINT document_uploaded_by_fkey FOREIGN KEY (uploaded_by) 
    REFERENCES public.app_user(id),
  CONSTRAINT document_shipment_id_fkey FOREIGN KEY (shipment_id) 
    REFERENCES public.shipment(id),
  CONSTRAINT document_category_id_fkey FOREIGN KEY (category_id) 
    REFERENCES public.document_category(id)
);
```

---

## 🗂️ **Storage Location**

Files are physically stored in:

```
Supabase Storage Bucket: shipment-docs
Path Structure: {shipment_id}/{timestamp}_{filename}
Example: abc-123-uuid/1704710400000_invoice.pdf
```

---

## 📝 **Document Types Supported**

### **Purchase Documents**
- `proforma_invoice` - Proforma Invoice
- `purchase_order` - Purchase Order
- `commercial_invoice` - Commercial Invoice

### **Shipping Documents**
- `bill_of_lading` - Bill of Lading
- `packing_list` - Packing List
- `certificate_of_origin` - Certificate of Origin

### **Financial Documents**
- `letter_of_credit` - Letter of Credit
- `insurance_certificate` - Insurance Certificate
- `bank_charges` - Bank Charges

### **Customs Documents**
- `ip_number` - IP Number
- `customs_declaration` - Customs Declaration
- `release_order` - Release Order

### **Other**
- `other` - Other Document

---

## 🔄 **Upload Flow**

### **Step 1: User Uploads File**
```javascript
// User fills form in Documents modal:
// - doc_type (dropdown)
// - document_file (file input)
```

### **Step 2: File Uploaded to Storage**
```javascript
const fileName = `${shipmentId}/${Date.now()}_${file.name}`;
await supabase.storage
    .from('shipment-docs')
    .upload(fileName, file);
```

### **Step 3: Get Public URL**
```javascript
const { data: urlData } = supabase.storage
    .from('shipment-docs')
    .getPublicUrl(fileName);
```

### **Step 4: Insert Record to Database**
```javascript
await supabase.from('document').insert({
    shipment_id: documentsShipmentId,
    doc_type: docType,
    file_url: urlData.publicUrl,
    uploaded_by: user.id
});
```

---

## 🔍 **Querying Documents**

### **Get All Documents for a Shipment**
```sql
SELECT 
    d.id,
    d.doc_type,
    d.file_url,
    d.uploaded_at,
    d.status,
    u.full_name as uploader_name
FROM document d
LEFT JOIN app_user u ON u.id = d.uploaded_by
WHERE d.shipment_id = '<shipment-id>'
  AND d.status = 'active'
ORDER BY d.uploaded_at DESC;
```

### **Check if Shipment Has Documents**
```javascript
const { data: documentsData } = await supabase
    .from('document')
    .select('id')
    .eq('shipment_id', shipmentId);

const hasDocuments = documentsData && documentsData.length > 0;
```

---

## 🎨 **UI Integration**

### **Documents Stage in Circular Tracker**
- **Green Circle** = Documents uploaded (`hasDocuments = true`)
- **Orange Blinking** = No documents uploaded (`hasDocuments = false`)
- **Always Accessible** = Can be clicked at any stage (like Bills stage)

### **Opening Documents Modal**
```javascript
// When user clicks "Documents" stage circle
openStageModal('documents')
  ↓
// Special handling redirects to documents modal
openDocumentsModal()
  ↓
// Shows:
// 1. Required Documents Checklist
// 2. Upload Form
// 3. List of Uploaded Documents
```

---

## 📋 **Related Tables**

### **1. document_category**
```sql
CREATE TABLE public.document_category (
  id uuid PRIMARY KEY,
  name text UNIQUE NOT NULL,
  description text,
  icon text,
  sort_order integer DEFAULT 0
);
```

### **2. required_document_config**
```sql
-- Defines which documents are required based on mode_of_transport and inco_term
CREATE TABLE public.required_document_config (
  id uuid PRIMARY KEY,
  mode_of_transport text NOT NULL,
  inco_term text,
  doc_type text NOT NULL,
  doc_name text NOT NULL,
  description text,
  category_id uuid,
  is_mandatory boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);
```

---

## 🔐 **Row Level Security**

Documents table should have RLS policies like:

```sql
-- Users can view documents for shipments they have access to
CREATE POLICY "Users can view documents"
ON document FOR SELECT
USING (true); -- Adjust based on your access control

-- Users can upload documents
CREATE POLICY "Users can upload documents"
ON document FOR INSERT
WITH CHECK (auth.uid() = uploaded_by);

-- Users can delete their own documents
CREATE POLICY "Users can delete own documents"
ON document FOR DELETE
USING (auth.uid() = uploaded_by);
```

---

## 📊 **Key Features**

### ✅ **Smart Document Management**
- Categorized by document type
- Required documents checklist
- Progress tracking (% complete)
- Document status tracking

### ✅ **File Handling**
- Max file size: 10MB
- Supported formats: PDF, DOC, DOCX, JPG, JPEG, PNG
- Automatic file naming with timestamp
- Public URL generation

### ✅ **User Experience**
- Drag & drop upload (if implemented)
- View/Download/Delete actions
- Upload progress indication
- Success/Error feedback

---

## 🔄 **Document Lifecycle**

```
1. Upload → status = 'active'
2. Replace → old status = 'replaced', new status = 'active'
3. Archive → status = 'archived'
4. Delete → status = 'deleted' (or hard delete from storage)
```

---

## 📈 **Statistics Queries**

### **Count Documents by Type**
```sql
SELECT 
    doc_type,
    COUNT(*) as count
FROM document
WHERE shipment_id = '<shipment-id>'
  AND status = 'active'
GROUP BY doc_type;
```

### **Total Storage Used by Shipment**
```sql
SELECT 
    shipment_id,
    SUM(file_size) as total_bytes,
    COUNT(*) as document_count
FROM document
WHERE shipment_id = '<shipment-id>'
  AND status = 'active'
GROUP BY shipment_id;
```

---

## 🎯 **Summary**

| Aspect | Details |
|--------|---------|
| **Table** | `public.document` |
| **Storage** | `shipment-docs` bucket in Supabase Storage |
| **Stage Config** | `STAGE_CONFIG.documents` with `isDocumentStage: true` |
| **Special Behavior** | Always accessible (like Bills stage) |
| **UI Modal** | `#documents-stage-modal` |
| **JavaScript Function** | `openDocumentsModal()` |

---

**Version:** 1.0  
**Date:** 2026-01-08  
**Status:** ✅ Active
