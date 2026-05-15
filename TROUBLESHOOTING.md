# Troubleshooting Guide - Create Shipment Wizard

## Issues Fixed

### ✅ Next Button Not Responding
**Fixed with:**
- Added `e.preventDefault()` to prevent form submission
- Added console logging for debugging
- Added existence checks for all buttons
- Enhanced event listener attachment with error handling

### ✅ Field Validation Checks
**Enhanced with:**
- **Commodity must be selected first** - Variety and Unit are disabled until commodity is selected
- **Visual feedback** - Disabled fields are grayed out and have "not-allowed" cursor
- **Error highlighting** - Invalid fields show red border and light red background
- **Detailed error messages** - Shows exactly which product and which field is missing

### ✅ Better User Experience
- Fields are clearly disabled (opacity 0.6) until requirements met
- Error messages specify product number and missing field
- Visual highlights clear when validation passes
- Smooth enable/disable transitions

## How to Test

### 1. Open Browser Console (F12)
Check for any errors in the console. You should see:
```
All event listeners attached successfully
```

### 2. Click "Create New Shipment"
Modal should open on Step 1.

### 3. Try Clicking Next Without Products
You should see:
```
⚠️ Please add at least one product to continue
```

### 4. Add Product and Test Field Dependencies
1. **Initially**: Variety and Unit dropdowns are disabled (grayed out)
2. **Select Commodity**: Variety and Unit become enabled (full color)
3. **Try Next with incomplete fields**: See specific errors like:
   ```
   ⚠️ Please complete the following:
   Product 1: Please select a product variety
   Product 1: Please enter a valid quantity
   ```
4. **Invalid fields highlighted**: Red border on left side

### 5. Complete All Fields
When all fields are filled, "Next" button should work.

## Common Issues & Solutions

### Issue: Console shows "Wizard buttons not found!"
**Solution**: 
- Check that HTML has been updated with wizard structure
- Verify IDs: `wizard-next-btn`, `wizard-back-btn`, `wizard-cancel-btn`
- Clear browser cache and reload

### Issue: Commodity dropdown not appearing
**Solution**:
- Check console for import errors
- Verify `SearchableDropdown.js` exists in `js/components/`
- Check CSS is loaded

### Issue: Variety dropdown stays disabled
**Solution**:
- Select a commodity first
- Check console for errors in `handleCommodityChange()`
- Verify product varieties are loaded

### Issue: Validation not showing errors
**Solution**:
- Check that ProductRow has `highlightError()` and `clearErrors()` methods
- Verify CSS has error color defined: `--error-color: #DC2626`

### Issue: Next button still not responding
**Debug Steps**:
1. Open console (F12)
2. Type: `console.log(shipmentFormManager)`
3. Should show the ShipmentFormManager object
4. If undefined, check initialization in admin-dashboard.js

## Validation Rules

### Step 1: Products
Each product must have:
- ✅ **Commodity** (required first)
- ✅ **Product Variety** (enabled after commodity)
- ✅ **Quantity** (must be > 0)
- ✅ **Unit** (enabled after commodity)

**Dependency Chain:**
```
Select Commodity → Variety Enabled → Select Variety
                 → Unit Enabled → Select Unit
```

### Step 2: Shipment Details
All fields required:
- ✅ **Shipment Type** (LC or DP)
- ✅ **Mode of Transport** (5 options)
- ✅ **Payment Term**

### Step 3: Review
- No validation
- Just display and confirm

## Visual Feedback Guide

### Disabled Fields
- **Opacity**: 0.6 (grayed out)
- **Cursor**: not-allowed
- **Background**: #f5f5f5
- **Pointer Events**: none

### Enabled Fields
- **Opacity**: 1 (full color)
- **Cursor**: pointer
- **Background**: white
- **Clickable**: yes

### Error State
- **Border Left**: 3px solid red
- **Background**: light red (rgba(220, 38, 38, 0.05))
- **Message**: Specific error shown above form

### Valid State
- **Border**: Normal
- **Background**: White
- **No highlights**

## Console Commands for Debugging

### Check if FormManager is initialized:
```javascript
console.log(shipmentFormManager);
```

### Check current step:
```javascript
console.log(shipmentFormManager.currentStep);
```

### Check product rows:
```javascript
console.log(shipmentFormManager.productRows);
```

### Check button elements:
```javascript
console.log(document.getElementById('wizard-next-btn'));
console.log(document.getElementById('wizard-back-btn'));
```

### Manually test validation:
```javascript
shipmentFormManager.validateCurrentStep();
```

### Check form data:
```javascript
console.log(shipmentFormManager.getFormData());
```

## Still Having Issues?

### 1. Clear Browser Cache
- Chrome: Ctrl + Shift + Delete
- Select "Cached images and files"
- Clear data

### 2. Hard Reload
- Chrome: Ctrl + Shift + R
- Firefox: Ctrl + Shift + R

### 3. Check File Versions
Verify you have the latest versions:
```
js/components/ShipmentFormManager.js  (updated)
js/components/ProductRow.js           (updated)
css/admin-dashboard.css               (updated)
admin-dashboard.html                  (updated)
```

### 4. Verify Integration
Check `admin-dashboard.js` has:
```javascript
// Imports
import { ShipmentFormManager } from './components/ShipmentFormManager.js';
import { ShipmentService } from './services/ShipmentService.js';
import { CommodityService } from './services/CommodityService.js';

// Services
const shipmentService = new ShipmentService(supabase);
const commodityService = new CommodityService(supabase);
let shipmentFormManager = null;

// Initialization in window.onload
shipmentFormManager = new ShipmentFormManager(
  supabase,
  shipmentService,
  commodityService
);
```

## Expected Behavior Summary

### When Opening Modal:
1. ✅ See Step 1 active (purple)
2. ✅ One product row added automatically
3. ✅ Commodity dropdown enabled
4. ✅ Variety dropdown **disabled** (grayed)
5. ✅ Unit dropdown **disabled** (grayed)
6. ✅ Next button visible

### When Selecting Commodity:
1. ✅ Variety dropdown **enables** (full color)
2. ✅ Unit dropdown **enables** (full color)
3. ✅ Varieties filtered by commodity
4. ✅ Units loaded for commodity

### When Clicking Next:
1. ✅ Validates all fields
2. ✅ Shows specific errors if invalid
3. ✅ Highlights invalid fields in red
4. ✅ Moves to Step 2 if valid

### On Step 2:
1. ✅ Step 1 shows green checkmark
2. ✅ Step 2 active (purple)
3. ✅ All 3 fields required
4. ✅ Back button visible

### On Step 3 (Review):
1. ✅ Steps 1 & 2 green
2. ✅ Step 3 active
3. ✅ Products table shows all data
4. ✅ Details card shows selections
5. ✅ Edit buttons work
6. ✅ Submit button visible

## Success Checklist

After fixes, verify:
- [ ] Console shows no errors
- [ ] "All event listeners attached successfully" logged
- [ ] Modal opens correctly
- [ ] Variety/Unit disabled until commodity selected
- [ ] Disabled fields are visually grayed out
- [ ] Next button responds to click
- [ ] Validation shows specific errors
- [ ] Invalid fields highlighted in red
- [ ] Can navigate through all 3 steps
- [ ] Review shows correct data
- [ ] Can submit successfully

If all checked, wizard is working correctly! ✅
