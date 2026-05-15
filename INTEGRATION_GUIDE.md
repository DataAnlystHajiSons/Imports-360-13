# Integration Guide: New Modal Architecture

## Overview
This guide shows how to integrate the new component-based architecture into `admin-dashboard.js`.

## Step 1: Add Imports at the Top

```javascript
// Add these imports after the Supabase import
import { ShipmentFormManager } from './components/ShipmentFormManager.js';
import { ShipmentService } from './services/ShipmentService.js';
import { CommodityService } from './services/CommodityService.js';
```

## Step 2: Initialize Services (after supabase client)

```javascript
// Add after: const supabase = createClient(...)
const shipmentService = new ShipmentService(supabase);
const commodityService = new CommodityService(supabase);
let shipmentFormManager = null;
```

## Step 3: Replace Modal Functions

### Remove these functions entirely:
- `openCreateShipmentModal()` (line ~536)
- `loadPaymentTerms()` (line ~538)
- `createSearchableDropdown()` (line ~547)
- `loadCommodities()` (line ~672)
- `populateUnits()` (line ~693)
- `openAddCommodityModal()` (line ~716)
- `closeAddCommodityModal()` (line ~722)
- `loadProductVarieties()` (line ~726)
- `addProductForm()` (line ~734)
- All searchable dropdown implementation code

### Replace with:

```javascript
// Initialize the form manager in window.onload after user authentication
window.onload = async () => {
  // ... existing code ...
  
  if (user) {
    // Initialize shipment form manager
    shipmentFormManager = new ShipmentFormManager(
      supabase,
      shipmentService,
      commodityService
    );
    
    // ... rest of existing code ...
  }
}
```

## Step 4: Update Event Listeners

### Replace this:

```javascript
document.getElementById('create-shipment-form').addEventListener('submit', async (event) => {
  // ... 50+ lines of form submission logic ...
});

document.getElementById('create-shipment-btn').addEventListener('click', openCreateShipmentModal);
document.getElementById('close-modal-btn').addEventListener('click', closeCreateShipmentModal);
document.getElementById('add-product-btn').addEventListener('click', addProductForm);
document.getElementById('add-commodity-form').addEventListener('submit', async (event) => {
  // ... commodity logic ...
});
```

### With this:

```javascript
// Create shipment button
document.getElementById('create-shipment-btn').addEventListener('click', () => {
  if (shipmentFormManager) {
    shipmentFormManager.openModal();
  }
});

// Cancel button in modal
document.getElementById('cancel-shipment-btn')?.addEventListener('click', () => {
  if (shipmentFormManager) {
    shipmentFormManager.closeModal();
  }
});
```

Note: Close button and form submission are already handled inside ShipmentFormManager!

## Step 5: Update Functions to Work with New Architecture

The ShipmentFormManager automatically calls these global functions after successful shipment creation:
- `window.loadShipments()`
- `window.loadDashboardStats()`

Make sure they're available globally (already done in current code).

## Lines to Delete from Original File

You can safely delete these sections from `admin-dashboard.js`:

1. **Lines ~536-672**: Old modal open and payment terms loading
2. **Lines ~547-670**: Entire searchable dropdown implementation
3. **Lines ~672-716**: Commodity and unit loading functions
4. **Lines ~716-734**: Add commodity modal functions
5. **Lines ~734-900**: addProductForm and all product row logic
6. **Lines ~1452-1550**: Old form submission handler and commodity form handler

This removes approximately **550+ lines** of code!

## Benefits of New Architecture

### Before:
- 1,734 lines in one file
- Mixed concerns (UI, API, validation, state)
- Hard to test
- Difficult to maintain
- No reusability

### After:
- Main file reduced to ~1,200 lines
- Clear separation of concerns
- Each component is testable
- Easy to maintain and extend
- Components are reusable
- **mode_of_transport field** integrated seamlessly
- Better error handling
- Loading states
- Form validation centralized

## File Structure

```
js/
├── admin-dashboard.js (cleaned up, ~1,200 lines)
├── components/
│   ├── SearchableDropdown.js (reusable dropdown)
│   ├── ProductRow.js (manages product entries)
│   └── ShipmentFormManager.js (orchestrates form)
├── services/
│   ├── ShipmentService.js (API calls for shipments)
│   └── CommodityService.js (API calls for commodities)
└── utils/
    └── FormValidator.js (validation logic)
```

## Testing the Integration

1. Open admin-dashboard.html
2. Click "Create New Shipment"
3. Add products (searchable dropdowns work)
4. Select Mode of Transport (new field!)
5. Fill all required fields
6. Submit form
7. Verify shipment is created with mode_of_transport

## Troubleshooting

### Issue: Modal doesn't open
**Solution**: Check console for import errors. Ensure all component files exist.

### Issue: Dropdowns don't work
**Solution**: Check if SearchableDropdown.js is properly imported in ProductRow.js

### Issue: Form submission fails
**Solution**: Check browser console for validation errors. Verify all required fields are filled.

## Next Steps

1. Apply the changes to admin-dashboard.js
2. Test the new modal thoroughly
3. Consider refactoring other modals using same pattern
4. Add unit tests for components
5. Add JSDoc comments for better IDE support
