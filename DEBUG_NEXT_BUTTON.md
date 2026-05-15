# Debug: Next Button Not Working

## Step-by-Step Debugging

### 1. Open Browser Console (F12)
Press F12 to open Developer Tools and go to the Console tab.

### 2. Clear Console
Click the 🚫 icon to clear previous logs.

### 3. Open the Modal
Click "Create New Shipment" button.

**Expected Console Output:**
```
All event listeners attached successfully
```

### 4. Fill Out Product Form
1. Select a commodity (e.g., "Wheat")
2. Select a variety
3. Enter quantity (e.g., 1000)
4. Select unit

### 5. Click "Next" Button

**Watch Console - You Should See:**
```
Next button clicked, current step: 1
goToNextStep called, current step: 1
validateCurrentStep called for step: 1
Number of product rows: 1
Product 1 data: {commodity_id: "xxx", product_variety_id: "xxx", quantity: "1000", unit: "KG"}
All products valid, clearing errors
Validation passed for step 1
Validation result: true
Validation passed, moving to next step
```

### 6. What to Check Based on Console Output

#### If You See: "Next button clicked, current step: 1"
✅ Button click is working

#### If You DON'T See: "Next button clicked"
❌ **Problem: Event listener not attached**

**Fix:**
```javascript
// Run in console:
console.log(document.getElementById('wizard-next-btn'));
// Should show: <button id="wizard-next-btn">...

// If null, check HTML has the wizard structure
```

#### If You See: "Validation errors: [...]"
❌ **Problem: Validation is failing**

**Check what the error says:**
- "Please select a commodity" → Commodity dropdown value is empty
- "Please select a product variety" → Variety dropdown value is empty
- "Please enter a valid quantity" → Quantity is 0 or empty
- "Please select a unit" → Unit dropdown value is empty

**Common Issue: Searchable Dropdown Not Setting Value**

The searchable dropdown might not be updating the hidden select element. Let's check:

```javascript
// Run in console after selecting a commodity:
let commoditySelect = document.querySelector('[name="commodity"]');
console.log('Commodity value:', commoditySelect.value);
// Should show the UUID, not empty string

// If empty, the SearchableDropdown isn't working
```

#### If Validation Passes But Still Doesn't Move
❌ **Problem: goToStep() might be failing**

Look for errors after "Validation passed, moving to next step"

### 7. Manual Test in Console

Try manually calling the methods:

```javascript
// Check if shipmentFormManager exists:
console.log(shipmentFormManager);

// Check current step:
console.log('Current step:', shipmentFormManager.currentStep);

// Check product rows:
console.log('Product rows:', shipmentFormManager.productRows.length);

// Get product data:
shipmentFormManager.productRows[0].getData();

// Try validation manually:
let valid = shipmentFormManager.validateCurrentStep();
console.log('Valid:', valid);

// If valid, try moving to next step manually:
if (valid) {
  shipmentFormManager.goToStep(2);
}
```

## Common Issues & Fixes

### Issue 1: SearchableDropdown Not Updating Select Value

**Symptom:** Commodity value is empty string even though you selected something

**Fix:** Check SearchableDropdown.js `selectOption()` method:

```javascript
// Should have this line:
this.selectElement.value = value;
```

**Test in Console:**
```javascript
// After selecting commodity in UI:
let select = document.querySelector('[name="commodity"]');
console.log('Select element:', select);
console.log('Select value:', select.value);
console.log('Select options:', select.options);

// Find the selected option:
let selectedOption = select.options[select.selectedIndex];
console.log('Selected option:', selectedOption);
```

### Issue 2: Product Row Not Getting Value

**Symptom:** `getData()` returns empty values

**Fix:** Check that the selects exist and have values:

```javascript
// In console:
let productRow = shipmentFormManager.productRows[0];
console.log('Commodity select:', productRow.commoditySelect);
console.log('Commodity value:', productRow.commoditySelect.value);
console.log('Variety select:', productRow.varietySelect);
console.log('Variety value:', productRow.varietySelect.value);
console.log('Quantity:', productRow.quantityInput.value);
console.log('Unit:', productRow.unitSelect.value);
```

### Issue 3: Event Listener Not Firing

**Symptom:** No "Next button clicked" in console

**Fix:** Check button exists and has listener:

```javascript
// In console:
let nextBtn = document.getElementById('wizard-next-btn');
console.log('Next button:', nextBtn);
console.log('Button type:', nextBtn?.type); // Should be "button" not "submit"

// Try clicking programmatically:
nextBtn.click();
// Should see console logs if listener attached
```

### Issue 4: Form Submitting Instead of Going to Next Step

**Symptom:** Page refreshes when clicking Next

**Fix:** Verify button type is "button" not "submit":

In HTML, should be:
```html
<button type="button" class="button" id="wizard-next-btn">
```

NOT:
```html
<button type="submit" class="button" id="wizard-next-btn">
```

## Quick Fix Script

If nothing works, paste this in console to manually debug:

```javascript
// 1. Check if everything exists
console.log('=== DEBUGGING START ===');
console.log('shipmentFormManager:', shipmentFormManager);
console.log('Current step:', shipmentFormManager?.currentStep);
console.log('Next button:', document.getElementById('wizard-next-btn'));
console.log('Product rows:', shipmentFormManager?.productRows?.length);

// 2. If product rows exist, check their data
if (shipmentFormManager?.productRows?.length > 0) {
  shipmentFormManager.productRows.forEach((row, i) => {
    console.log(`Product ${i+1}:`, row.getData());
  });
}

// 3. Try validation
if (shipmentFormManager) {
  console.log('Attempting validation...');
  let valid = shipmentFormManager.validateCurrentStep();
  console.log('Validation result:', valid);
  
  // 4. If valid, try moving
  if (valid) {
    console.log('Moving to step 2...');
    shipmentFormManager.goToStep(2);
  }
}

console.log('=== DEBUGGING END ===');
```

## What to Report

After running the debug steps, please report:

1. **What console logs you see** (copy-paste the output)
2. **At which point it stops** (which log is the last one you see)
3. **Any error messages** (red text in console)
4. **The output of the "Quick Fix Script"** above

This will help identify exactly where the issue is!
