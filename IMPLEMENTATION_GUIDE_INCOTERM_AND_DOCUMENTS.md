# 🚀 Implementation Guide: Inco-term & Documents Stage

## Overview
This guide covers the implementation of:
1. **Inco-term field** in shipment creation (dynamic based on mode of transport)
2. **Freight charges field** (conditional on FOB inco-term)
3. **Documents Stage** - A separate, always-accessible stage for all documents
4. **Merged LC Stage** - Combining LC Opening + LC Shared into one stage
5. **CFR Skip Logic** - Auto-skip supplier details/freight stages for CFR shipments

---

## 📋 Part 1: Database Changes

### Step 1: Run Database Migrations (IN ORDER)

```sql
-- 1. Add inco_term and freight_charges columns
\i 01_add_inco_term_and_freight_charges.sql

-- 2. Merge LC stages
\i 02_update_stage_enum_merge_lc.sql

-- 3. Update stage edges
\i 03_update_stage_edges_new_workflow.sql

-- 4. Update stage_requirements_met function
\i 04_update_stage_requirements_met_cfr_logic.sql
```

**Verification:**
```sql
-- Check if columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'shipment' 
AND column_name IN ('inco_term', 'freight_charges');

-- Check merged LC table
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'letter_of_credit' 
AND column_name IN ('lc_shared', 'lc_shared_date', 'lc_shared_notes');

-- Test stage function
SELECT stage_requirements_met(
  '<some-shipment-id>'::uuid, 
  'shipment_details_from_supplier'::stage
);
```

---

## 📋 Part 2: Frontend - Shipment Creation

### Step 1: Update admin-dashboard.html

Replace the Step 2 section with the content from:
```
05_shipment_creation_incoterm_updates.html
```

**Location:** Find `<!-- Step 2: Shipment Details Section -->` in admin-dashboard.html

### Step 2: Update ShipmentFormManager.js

Add the methods from:
```
06_shipment_form_manager_incoterm_integration.js
```

**Key additions:**
- `setupIncotermLogic()` - Initialize dynamic behavior
- `updateIncotermOptions()` - Update options based on mode
- `toggleFreightChargesField()` - Show/hide freight charges
- Updated `validateCurrentStep()` - Validate new fields
- Updated `populateReview()` - Display new fields in review
- Updated `getFormData()` - Include new fields

**Integration Point:** Call `setupIncotermLogic()` in `attachEventListeners()` method:

```javascript
attachEventListeners() {
  // ... existing code ...
  
  // Setup inco-term dynamic logic
  this.setupIncotermLogic();
  
  // ... rest of existing code ...
}
```

### Step 3: Update ShipmentService.js

Add inco_term and freight_charges to the createShipment method:

```javascript
async createShipment(shipmentData, userId) {
  const { error } = await this.supabase
    .from('shipment')
    .insert({
      reference_code: shipmentData.reference_code,
      type: shipmentData.type,
      mode_of_transport: shipmentData.mode_of_transport,
      inco_term: shipmentData.inco_term,  // NEW
      freight_charges: shipmentData.freight_charges,  // NEW
      payment_term_id: shipmentData.payment_term_id,
      created_by: userId,
      current_stage: 'forecast',
      status: 'active'
    })
    .select()
    .single();
    
  if (error) throw error;
  return data;
}
```

### Step 4: Update FormValidator.js

Add validation for new fields:

```javascript
static validateShipmentForm(formData) {
  const errors = {};
  
  // Existing validations...
  
  // Inco-term validation
  if (!formData.inco_term) {
    errors.inco_term = 'Inco-term is required';
  }
  
  // Freight charges validation (only if FOB)
  if (formData.inco_term === 'FOB') {
    if (!formData.freight_charges || parseFloat(formData.freight_charges) <= 0) {
      errors.freight_charges = 'Freight charges are required for FOB inco-term';
    }
  }
  
  return errors;
}
```

---

## 📋 Part 3: Frontend - Documents Stage

### Step 1: Add Documents Modal to shipment_tracker.html

Add the content from:
```
07_documents_stage_modal.html
```

**Location:** After the last modal (clearing-agent-bill-modal), before the closing `</body>` tag

### Step 2: Add JavaScript Functions

Create new file: `js/documents-manager.js`

Copy content from:
```
08_documents_stage_functions.js
```

### Step 3: Import in shipment_tracker.html

```html
<script type="module" src="js/documents-manager.js"></script>
```

### Step 4: Add "Documents" Button to Tracker

In shipment_tracker.html, add a floating action button or sidebar button:

```html
<!-- Add to tracker sidebar or as floating button -->
<button class="documents-btn" onclick="openDocumentsModal()">
  <i class="fas fa-folder-open"></i>
  <span>Manage Documents</span>
</button>
```

**CSS for floating button:**
```css
.documents-btn {
  position: fixed;
  bottom: 30px;
  right: 30px;
  background: #7C3AED;
  color: white;
  border: none;
  padding: 15px 25px;
  border-radius: 50px;
  font-size: 16px;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(124, 58, 237, 0.3);
  display: flex;
  align-items: center;
  gap: 10px;
  z-index: 1000;
  transition: all 0.3s ease;
}

.documents-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(124, 58, 237, 0.4);
}
```

### Step 5: Remove Document Uploads from Individual Stages

In shipment_tracker.html, remove or comment out:
```html
<!-- Remove these from stage modals: -->
<div id="document-upload-container">
  <label for="document">Document</label>
  <input type="file" id="document" name="document">
</div>
```

**Location:** Inside each stage modal's edit form

---

## 📋 Part 4: Merged LC Stage Updates

### Step 1: Update Stage Names in shipment-tracker.js

Find references to 'lc_shared_with_supplier' and update:

```javascript
// OLD
case 'lc_shared_with_supplier':
  return 'LC Shared with Supplier';

// NEW
case 'lc_opening':
  return 'LC Opening & Sharing';
```

### Step 2: Update LC Stage Modal

In the LC stage modal handler, add fields for LC sharing:

```javascript
function renderLCStageEdit(shipmentId) {
  // Existing LC opening fields...
  
  // Add LC sharing fields
  const lcShareFields = `
    <div class="form-section">
      <h3>LC Sharing with Supplier</h3>
      <div class="form-grid">
        <div class="form-group">
          <label for="lc_shared">LC Shared?</label>
          <input type="checkbox" id="lc_shared" name="lc_shared">
        </div>
        <div class="form-group">
          <label for="lc_shared_date">Shared Date</label>
          <input type="date" id="lc_shared_date" name="lc_shared_date">
        </div>
        <div class="form-group">
          <label for="lc_shared_notes">Notes</label>
          <textarea id="lc_shared_notes" name="lc_shared_notes"></textarea>
        </div>
      </div>
    </div>
  `;
  
  // Add to form
}
```

---

## 📋 Part 5: CFR Skip Logic

### Already Implemented in Database

The `stage_requirements_met` function now checks inco_term and auto-returns TRUE for:
- `shipment_details_from_supplier`
- `freight_query`
- `award_shipment`

When inco_term = 'CFR'

### Frontend Indicators (Optional)

Add visual indicators in shipment tracker for skipped stages:

```javascript
function renderStageCircle(stage, shipmentData) {
  const circle = createStageCircle(stage);
  
  // Check if stage should be skipped
  if (shipmentData.inco_term === 'CFR') {
    const skippedStages = [
      'shipment_details_from_supplier',
      'freight_query',
      'award_shipment'
    ];
    
    if (skippedStages.includes(stage)) {
      circle.classList.add('skipped');
      circle.title = 'Skipped (CFR Inco-term)';
    }
  }
  
  return circle;
}
```

**CSS for skipped stages:**
```css
.stage-circle.skipped {
  background: #95a5a6;
  opacity: 0.6;
  text-decoration: line-through;
}

.stage-circle.skipped::after {
  content: '⊘';
  position: absolute;
  font-size: 24px;
  color: white;
}
```

---

## 🧪 Testing Checklist

### Shipment Creation
- [ ] Air mode shows: FCA, EXW, CPT inco-terms
- [ ] Sea mode shows: EXW, FOB, CFR inco-terms
- [ ] Selecting FOB shows freight charges field
- [ ] Freight charges is required when FOB selected
- [ ] Other inco-terms hide freight charges field
- [ ] Review step shows inco-term and freight charges
- [ ] Shipment saves with inco_term and freight_charges

### Documents Stage
- [ ] Documents modal opens from tracker
- [ ] Can upload documents to different categories
- [ ] Documents display in correct category tabs
- [ ] Search filters documents correctly
- [ ] Can view/download/delete documents
- [ ] Document counts update correctly

### LC Stage
- [ ] LC opening form includes sharing fields
- [ ] Can mark LC as shared
- [ ] Stage advances only when LC is shared
- [ ] Old lc_share data was migrated

### CFR Skip Logic
- [ ] CFR shipments skip supplier details stage
- [ ] CFR shipments skip freight query stage
- [ ] CFR shipments skip award shipment stage
- [ ] Non-CFR shipments go through all stages
- [ ] Skipped stages show as completed/skipped visually

---

## 🐛 Troubleshooting

### Issue: Inco-term dropdown is disabled
**Solution:** Ensure mode_of_transport is selected first

### Issue: Freight charges not showing for FOB
**Solution:** Check if `toggleFreightChargesField()` is being called on inco-term change

### Issue: Documents not uploading
**Solution:** 
1. Check Supabase storage bucket 'shipment-docs' exists
2. Verify storage policies allow authenticated uploads
3. Check file size < 10MB

### Issue: CFR stages not being skipped
**Solution:**
1. Verify inco_term is saved correctly in database
2. Check `stage_requirements_met` function is updated
3. Run: `SELECT inco_term FROM shipment WHERE id = '<id>'`

### Issue: LC stages still showing as separate
**Solution:**
1. Run migration 02_update_stage_enum_merge_lc.sql
2. Update any hardcoded stage references in JavaScript
3. Clear browser cache

---

## 📊 New Database Schema

### shipment table (additions)
```sql
inco_term text CHECK (inco_term IN ('EXW', 'FOB', 'CFR', 'FCA', 'CPT', 'DDP'))
freight_charges numeric
```

### letter_of_credit table (additions)
```sql
lc_shared boolean DEFAULT false
lc_shared_date date
lc_shared_notes text
```

### stage enum (changes)
- Removed: `lc_shared_with_supplier`
- Merged into: `lc_opening`

### stage_edge (changes)
- Removed: lc_opening → lc_shared_with_supplier
- Removed: lc_shared_with_supplier → invoice
- Added: lc_opening → invoice

---

## 🎯 Success Criteria

✅ **Shipment Creation:**
- Inco-term options change based on transport mode
- Freight charges appear only for FOB
- All new fields save correctly

✅ **Documents Stage:**
- Can upload/view/download/delete documents
- Documents categorized correctly
- Always accessible from tracker

✅ **LC Merge:**
- Single LC stage handles both opening and sharing
- Data from lc_share table migrated
- Stage progression works correctly

✅ **CFR Logic:**
- Supplier/freight stages auto-skip for CFR
- Visual indicators show skipped stages
- Stage progression continues correctly

---

## 📞 Support

If you encounter issues:

1. **Check Browser Console** for JavaScript errors
2. **Check Supabase Logs** for database errors
3. **Verify Migrations** ran successfully
4. **Test with Sample Data** before production use

---

## 🎉 Congratulations!

You've successfully implemented:
- ✅ Dynamic inco-term selection
- ✅ Conditional freight charges field
- ✅ Comprehensive documents management stage
- ✅ Merged LC workflow
- ✅ Intelligent CFR skip logic

Your Imports 360 application is now more efficient and user-friendly! 🚀
