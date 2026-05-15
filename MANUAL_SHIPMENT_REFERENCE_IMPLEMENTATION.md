# Manual Shipment Reference Number Implementation

## Overview
Changed the shipment creation process from **auto-generated reference numbers** to **user-provided manual input**. Users now enter their own unique reference numbers when creating a new shipment.

---

## Changes Made

### 1. **Backend Logic (JavaScript)**
**File:** `js/components/ShipmentFormManager.js`

#### Changed in `handleSubmit()` method:
- ❌ **REMOVED:** Auto-generation call to `generateReferenceCode()`
- ✅ **ADDED:** Validation to ensure reference code is provided
- ✅ **ADDED:** Uniqueness check against existing shipments in database
- ✅ **ADDED:** Error messages for missing or duplicate reference codes

**Before:**
```javascript
const referenceCode = await this.shipmentService.generateReferenceCode(formData.type);
const shipment = await this.shipmentService.createShipment({
  reference_code: referenceCode,
  // ...
});
```

**After:**
```javascript
// Validate reference code is provided
if (!formData.reference_code || formData.reference_code.trim() === '') {
  this.showMessage('Shipment Reference Number is required', 'error');
  return;
}

// Check if reference code already exists
const { data: existing } = await this.supabase
  .from('shipment')
  .select('id')
  .eq('reference_code', formData.reference_code.trim())
  .maybeSingle();

if (existing) {
  this.showMessage(`Reference code "${formData.reference_code}" already exists.`, 'error');
  return;
}

// Use manually entered reference code
const shipment = await this.shipmentService.createShipment({
  reference_code: formData.reference_code.trim(),
  // ...
});
```

#### Updated `getFormData()` method:
```javascript
getFormData() {
  const referenceCodeValue = this.form.querySelector('[name="reference_code"]')?.value;
  return {
    reference_code: referenceCodeValue ? referenceCodeValue.trim() : '',
    type: this.form.querySelector('[name="type"]').value,
    // ... rest of fields
  };
}
```

#### Updated `populateDetailsReview()` method:
- Added reference code display in the review step
- Shows entered reference code prominently in bold

```javascript
html += `<div class="review-item">
  <span class="review-item-label">Reference Number:</span>
  <span class="review-item-value"><strong>${referenceCode || 'Not provided'}</strong></span>
</div>`;
```

---

### 2. **Frontend UI (HTML)**
**File:** `admin-dashboard.html`

#### Added Input Field in Step 2 (Details):
```html
<div class="form-field">
  <label>Shipment Reference Number: <span class="required">*</span></label>
  <input 
    type="text" 
    name="reference_code" 
    required 
    placeholder="e.g., D-2501, L-2501" 
    maxlength="50" 
  />
  <small class="field-hint">
    Enter a unique reference number for this shipment 
    (e.g., D-2501 for DP or L-2501 for LC)
  </small>
</div>
```

**Position:** Placed at the very top of Step 2, before "Shipment Type" field

---

## How It Works Now

### 1. **User Creates Shipment**
   - Opens "Create New Shipment" modal
   - Adds products in Step 1
   - Clicks "Next" to go to Step 2

### 2. **User Enters Reference Number**
   - First field in Step 2 is "Shipment Reference Number"
   - User manually types their reference (e.g., "D-2501" or "L-2501")
   - Field is required - cannot proceed without it

### 3. **Validation Happens**
   - When form is submitted (Step 3 - Review)
   - System checks if reference code is empty → Shows error
   - System checks database if reference already exists → Shows error
   - Only proceeds if reference is unique

### 4. **Shipment Created**
   - Uses the user-provided reference code
   - No auto-generation occurs

---

## User Experience

### What Users See:

1. **Input Field:**
   - Label: "Shipment Reference Number: *"
   - Placeholder: "e.g., D-2501, L-2501"
   - Hint: "Enter a unique reference number for this shipment (e.g., D-2501 for DP or L-2501 for LC)"
   - Max length: 50 characters
   - Required field (marked with red asterisk)

2. **In Review Step (Step 3):**
   - "Reference Number: **D-2501**" (shown prominently in bold)

3. **Error Messages:**
   - If empty: "Shipment Reference Number is required"
   - If duplicate: "Reference code 'D-2501' already exists. Please use a unique reference number."
   - Error displayed in red banner at top of modal

---

## Validation Rules

1. ✅ **Required:** Cannot be empty
2. ✅ **Unique:** Must not exist in database
3. ✅ **Trimmed:** Leading/trailing spaces removed
4. ✅ **Max Length:** 50 characters
5. ✅ **Format:** No specific format enforced (user can use any pattern)

---

## Benefits of This Change

### For Users:
- ✅ **Full Control:** Users decide their own numbering scheme
- ✅ **Flexibility:** Can use company-specific patterns (e.g., "IMP-2025-001")
- ✅ **Consistency:** Can maintain their existing numbering system
- ✅ **Meaningful:** Can encode information in the reference (year, department, etc.)

### For System:
- ✅ **Uniqueness Enforced:** Database validation prevents duplicates
- ✅ **Simple Logic:** No complex auto-generation rules
- ✅ **User-Friendly Errors:** Clear feedback on what went wrong

---

## Removed Functionality

The following is **NO LONGER USED**:

### Database Function:
- `get_next_shipment_reference(p_shipment_type)` - **NOT CALLED**
  - This function still exists in the database but is not invoked
  - Can be kept for backward compatibility or removed if not needed elsewhere

### Service Method:
- `ShipmentService.generateReferenceCode()` - **NOT CALLED**
  - Method still exists in `js/services/ShipmentService.js` but is not invoked
  - Can be removed if not used elsewhere in the codebase

---

## Testing Checklist

When testing this feature, verify:

- [ ] **Empty Reference:** Submit form without entering reference → Should show error
- [ ] **Duplicate Reference:** Enter an existing reference → Should show "already exists" error
- [ ] **Valid Unique Reference:** Enter new unique reference → Should create shipment successfully
- [ ] **Review Display:** Reference should appear in Step 3 review section
- [ ] **Whitespace Handling:** Leading/trailing spaces should be trimmed automatically
- [ ] **Long References:** Enter 50+ characters → Should be limited to 50
- [ ] **Special Characters:** Try references with dashes, underscores, etc. → Should work

---

## Future Enhancements (Optional)

If desired, you can add:

1. **Format Validation:**
   - Regex pattern to enforce specific formats (e.g., `^[DL]-\d{4}$`)
   - Example: Only allow "D-XXXX" or "L-XXXX" format

2. **Suggested References:**
   - Show last used reference as placeholder
   - Auto-suggest next number in sequence

3. **Prefix Dropdown:**
   - Let users select prefix (D- or L-) from dropdown
   - Then only enter the number portion

4. **Real-Time Validation:**
   - Check uniqueness as user types (debounced)
   - Show green checkmark if unique, red X if duplicate

---

## Files Modified

1. **`js/components/ShipmentFormManager.js`**
   - Modified: `handleSubmit()` method
   - Modified: `getFormData()` method
   - Modified: `populateDetailsReview()` method

2. **`admin-dashboard.html`**
   - Added: Reference code input field in Step 2

---

## Rollback Instructions

If you need to revert to auto-generation:

1. **In `ShipmentFormManager.js`:**
   - Restore the `generateReferenceCode()` call
   - Remove reference code validation checks

2. **In `admin-dashboard.html`:**
   - Remove the reference code input field

3. **Backup:**
   - Git: `git checkout HEAD~1 -- js/components/ShipmentFormManager.js admin-dashboard.html`

---

## Summary

**Before:** System automatically generated reference codes (D-2501, L-2501, etc.)
**After:** Users manually enter reference codes with uniqueness validation

This change gives users full control over their shipment numbering scheme while maintaining data integrity through validation.
