# 🎯 Smart Document Management System

## Philosophy

**Documents DON'T block stage progression** ✅  
**Documents ARE required for shipment completion** ✅  
**Required documents depend on Mode + Inco-term** ✅

---

## How It Works

### 1. Dynamic Requirements

Documents required change based on:
- **Mode of Transport**: Sea, Air, Land, Rail
- **Inco-term**: EXW, FOB, CFR, CIF, FCA, CPT, DDP

**Example:**
```
Sea + FOB Shipment needs:
✅ Commercial Invoice (mandatory)
✅ Bill of Lading (mandatory)
✅ Packing List (mandatory)
✅ Freight Booking (mandatory - buyer arranges)
✅ Insurance Certificate (mandatory - buyer insures)
✅ Customs Declaration (mandatory)
❌ Freight Invoice (not needed - buyer pays directly)

Sea + CIF Shipment needs:
✅ Commercial Invoice (mandatory)
✅ Bill of Lading (mandatory)
✅ Freight Invoice (mandatory - seller pays freight)
✅ Insurance Policy (mandatory - seller insures)
✅ Customs Declaration (mandatory)
```

### 2. Two Types of Documents

**Mandatory** 🔴
- MUST be uploaded before shipment can be marked "complete"
- Shows as red/orange indicator if missing
- Blocks final completion

**Optional** 🟡
- Nice to have, but not required
- Can be uploaded anytime
- Doesn't affect completion status

### 3. No Stage Blocking

- ✅ Stages advance regardless of documents
- ✅ Documents can be uploaded **late** without blocking progress
- ✅ But shipment can't be **completed** without mandatory docs

---

## Database Structure

### Tables

1. **`document`** (existing, enhanced)
   - Stores all uploaded documents
   - Added: metadata, status, file_size, category

2. **`document_category`** (new)
   - Organizes documents into categories
   - Commercial, Shipping, Banking, Customs, etc.

3. **`required_document_config`** (new)
   - Defines what documents are required
   - Based on mode_of_transport + inco_term
   - Marks which are mandatory vs optional

### Key Functions

#### `get_required_documents(shipment_id)`
Returns list of required documents for a shipment based on its mode + inco-term.

```sql
SELECT * FROM get_required_documents('abc-123-uuid');
```

Returns:
```
doc_type              | doc_name                | is_mandatory | is_uploaded
----------------------|-------------------------|--------------|-------------
commercial_invoice    | Commercial Invoice      | true         | true
bill_of_lading        | Bill of Lading          | true         | false  ⚠️
packing_list          | Packing List            | true         | true
insurance_certificate | Insurance Certificate   | true         | false  ⚠️
```

#### `can_complete_shipment(shipment_id)`
Checks if all mandatory documents are uploaded.

```sql
SELECT * FROM can_complete_shipment('abc-123-uuid');
```

Returns:
```
can_complete | missing_mandatory_docs | missing_doc_list
-------------|------------------------|----------------------------------
false        | 2                      | {Bill of Lading, Insurance Certificate}
```

### View: `v_shipment_document_summary`
Quick overview of document status per shipment.

```sql
SELECT * FROM v_shipment_document_summary WHERE shipment_id = 'abc-123';
```

Returns:
```
shipment_id | mode | inco_term | total_uploaded | mandatory_uploaded | completion_% | can_complete
------------|------|-----------|----------------|--------------------|--------------|--------------
abc-123     | sea  | FOB       | 8              | 6/8                | 75%          | false
```

---

## Frontend Integration

### Current Implementation

1. **Documents Stage** (circular + timeline)
   - Shows **orange blinking** if ANY mandatory docs missing
   - Shows **green** if ALL mandatory docs uploaded
   - Accessible anytime (like Bills stage)

### Recommended Enhancements

#### 1. Show Required Documents Checklist

```javascript
async function loadRequiredDocuments(shipmentId) {
  const { data, error } = await supabase
    .rpc('get_required_documents', { p_shipment_id: shipmentId });
  
  // Returns list with is_uploaded flag
  // Show checklist in documents modal
}
```

#### 2. Completion Check

```javascript
async function checkCanComplete(shipmentId) {
  const { data, error } = await supabase
    .rpc('can_complete_shipment', { p_shipment_id: shipmentId });
  
  if (!data[0].can_complete) {
    alert(`Missing: ${data[0].missing_doc_list.join(', ')}`);
  }
}
```

#### 3. Update Documents Modal

Add a checklist section:
```html
<div class="required-docs-section">
  <h3>📋 Required Documents</h3>
  <ul>
    <li class="uploaded">✅ Commercial Invoice</li>
    <li class="uploaded">✅ Packing List</li>
    <li class="missing">⚠️ Bill of Lading (Missing)</li>
    <li class="missing">⚠️ Insurance Certificate (Missing)</li>
  </ul>
  <p>Completion: 50% (2/4 mandatory documents)</p>
</div>
```

---

## Configuration Examples

### Adding New Document Type

```sql
INSERT INTO required_document_config 
  (mode_of_transport, inco_term, doc_type, doc_name, description, is_mandatory) 
VALUES 
  ('sea', 'FOB', 'quality_certificate', 'Quality Certificate', 'Product quality cert', false);
```

### Making Document Mandatory for Specific Inco-term

```sql
UPDATE required_document_config 
SET is_mandatory = true 
WHERE doc_type = 'insurance_certificate' 
  AND mode_of_transport = 'sea' 
  AND inco_term = 'FOB';
```

### Removing Requirement

```sql
DELETE FROM required_document_config 
WHERE doc_type = 'some_optional_doc' 
  AND inco_term = 'EXW';
```

---

## Benefits

### ✅ Flexibility
- Documents can be uploaded late
- Stages don't wait for documents
- Real-world workflow supported

### ✅ Control
- Shipment can't complete without mandatory docs
- Clear visibility of missing documents
- Compliance ensured

### ✅ Customization
- Easy to add/remove document requirements
- Different requirements per mode/inco-term
- Mandatory vs optional flags

### ✅ Performance
- Indexed for fast queries
- Cached document counts
- Single query to check completion

### ✅ Reporting
- See which shipments have missing docs
- Track document upload timelines
- Compliance reports

---

## Migration Path

### Phase 1: Run SQL Script ✅
```bash
Run: SMART_DOCUMENT_SYSTEM.sql
```

### Phase 2: Update Frontend (Optional)
- Add required documents checklist to modal
- Show completion percentage
- Add "Missing Documents" warning in Bills stage

### Phase 3: Configure Requirements
- Review default document requirements
- Adjust mandatory flags per your business rules
- Add any custom documents needed

---

## Example Queries

### Check missing documents for all active shipments
```sql
SELECT 
  s.reference_code,
  s.mode_of_transport,
  s.inco_term,
  vsd.completion_percentage,
  vsd.mandatory_uploaded || '/' || vsd.total_mandatory_required as docs_status
FROM shipment s
JOIN v_shipment_document_summary vsd ON vsd.shipment_id = s.id
WHERE s.status = 'active' 
  AND vsd.can_complete = false
ORDER BY vsd.completion_percentage;
```

### Get all missing documents for a specific shipment
```sql
SELECT doc_name, description, category
FROM get_required_documents('your-shipment-id')
WHERE is_mandatory = true 
  AND is_uploaded = false;
```

### Find shipments ready to complete
```sql
SELECT reference_code, mode_of_transport, current_stage
FROM v_shipment_document_summary
WHERE can_complete = true 
  AND current_stage = 'bills';
```

---

## Summary

**This system gives you:**
- ✅ Flexible document upload (no stage blocking)
- ✅ Enforced completion requirements
- ✅ Dynamic requirements based on shipment type
- ✅ Clear visibility of document status
- ✅ Easy configuration and maintenance

**Perfect for real-world logistics where documents often arrive late but still need to be tracked!** 🚀
