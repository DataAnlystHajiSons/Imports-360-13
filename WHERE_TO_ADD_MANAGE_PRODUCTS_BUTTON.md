# 📍 Where to Add "Manage Products" Button

## Quick Answer

The **"Manage Products" button** goes in the **shipment tracker sidebar**, right after the "Manage Documents" button.

---

## 🎯 Exact Location

### File: `shipment_tracker.html`

**Line: ~200-210** (look for "Manage Documents" section)

```html
<!-- EXISTING CODE (you should see this around line 200): -->
<div class="documents-section">
  <button class="documents-stage-btn">
    <i class="fas fa-folder-open"></i>
    <span>Manage Documents</span>
  </button>
</div>

<!-- ADD THIS RIGHT AFTER ⬇️ -->

<!-- Products Management Section -->
<div class="products-section" style="margin-top: 16px;">
  <button class="products-manage-btn" onclick="openManageProductsModal()" style="
    width: 100%;
    padding: 14px 20px;
    background: linear-gradient(135deg, #7c3aed 0%, #6d28d9 100%);
    color: white;
    border: none;
    border-radius: 10px;
    font-size: 15px;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    transition: all 0.3s ease;
    box-shadow: 0 4px 12px rgba(124, 58, 237, 0.3);
  ">
    <i class="fas fa-boxes"></i>
    <span>Manage Products</span>
    <i class="fas fa-chevron-right" style="margin-left: auto; font-size: 12px;"></i>
  </button>
</div>
```

---

## 🖼️ Visual Guide

### Before (What you have now):

```
┌──────────────────────────┐
│   Shipment Tracker       │
├──────────────────────────┤
│                          │
│  Supplier Details        │
│  [View Profile]          │
│                          │
│  Current Stage Details   │
│  Status: In Progress     │
│                          │
│  Progress Bar            │
│  ████████░░░░░░ 36%      │
│                          │
│  ┌────────────────────┐  │
│  │ 📁 Manage Documents│  │
│  └────────────────────┘  │
│                          │  ← ADD BUTTON HERE!
│  Timeline                │
│  • Stage 1 completed     │
│  • Stage 2 in progress   │
└──────────────────────────┘
```

### After (What you'll get):

```
┌──────────────────────────┐
│   Shipment Tracker       │
├──────────────────────────┤
│                          │
│  Supplier Details        │
│  [View Profile]          │
│                          │
│  Current Stage Details   │
│  Status: In Progress     │
│                          │
│  Progress Bar            │
│  ████████░░░░░░ 36%      │
│                          │
│  ┌────────────────────┐  │
│  │ 📁 Manage Documents│  │
│  └────────────────────┘  │
│                          │
│  ┌────────────────────┐  │  ← NEW BUTTON!
│  │ 📦 Manage Products ›│  │
│  └────────────────────┘  │
│                          │
│  Timeline                │
│  • Stage 1 completed     │
│  • Stage 2 in progress   │
└──────────────────────────┘
```

---

## 📝 Complete Integration Steps

### Step 1: Add the Button HTML (2 minutes)

1. Open `shipment_tracker.html`
2. Press `Ctrl+F` and search for: `Manage Documents`
3. Find the `<div class="documents-section">` block
4. Copy the button HTML from above
5. Paste it RIGHT AFTER the documents section
6. Save the file

### Step 2: Add Modal HTML (1 minute)

At the **END** of `shipment_tracker.html`, just before `</body>`:

```html
<!-- Include Product Management Modal -->
<div id="product-management-modal-container"></div>
<script>
  fetch('manage-products-modal.html')
    .then(response => response.text())
    .then(html => {
      document.getElementById('product-management-modal-container').innerHTML = html;
    });
</script>
</body>
</html>
```

### Step 3: Add JavaScript Import (1 minute)

At the **TOP** of `js/shipment-tracker.js`:

```javascript
import { initProductManagement } from './manage-products.js';
```

### Step 4: Initialize Product Management (1 minute)

Find where you load shipment details and add:

```javascript
// After loading shipment data
await initProductManagement(supabase, shipmentId, shipmentData.reference_code);
```

**OR** if you can't find that, add at the end of your initialization code:

```javascript
// Get shipment ID from URL
const urlParams = new URLSearchParams(window.location.search);
const shipmentId = urlParams.get('id');

if (shipmentId) {
  const { data } = await supabase
    .from('shipment')
    .select('reference_code')
    .eq('id', shipmentId)
    .single();
  
  await initProductManagement(supabase, shipmentId, data.reference_code);
}
```

### Step 5: Enable ES6 Modules (30 seconds)

In `shipment_tracker.html`, find your script tag and add `type="module"`:

```html
<!-- Change this: -->
<script src="js/shipment-tracker.js"></script>

<!-- To this: -->
<script type="module" src="js/shipment-tracker.js"></script>
```

---

## ✅ Test It!

1. Open shipment tracker page
2. Look for the purple **"Manage Products"** button
3. Click it
4. Modal should open with 3 tabs
5. Try adding a product
6. Success! 🎉

---

## 🐛 Troubleshooting

### Button doesn't appear?
- Check if you saved `shipment_tracker.html`
- Refresh the page (Ctrl+F5 for hard refresh)
- Check browser console (F12) for errors

### Button appears but nothing happens when clicked?
- Check if `manage-products-modal.html` is in the correct folder
- Open browser console and look for error: "openManageProductsModal is not defined"
- Verify `manage-products.js` is imported

### Modal opens but no products show?
- Check if database migration ran successfully
- Verify `initProductManagement()` was called
- Check browser console for API errors

---

## 🎨 Button Customization (Optional)

### Change Button Color

```css
/* In the button style, change: */
background: linear-gradient(135deg, #7c3aed 0%, #6d28d9 100%);

/* To: */
background: linear-gradient(135deg, #10b981 0%, #059669 100%); /* Green */
background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); /* Blue */
background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%); /* Orange */
```

### Change Button Icon

```html
<!-- Change: -->
<i class="fas fa-boxes"></i>

<!-- To: -->
<i class="fas fa-box-open"></i>
<i class="fas fa-cubes"></i>
<i class="fas fa-shopping-cart"></i>
```

### Change Button Text

```html
<!-- Change: -->
<span>Manage Products</span>

<!-- To: -->
<span>Products</span>
<span>Edit Products</span>
<span>Shipment Products</span>
```

---

## 📍 Summary

**Location:** `shipment_tracker.html` sidebar, after "Manage Documents" button

**What to add:** Purple gradient button that calls `openManageProductsModal()`

**What happens:** Clicking opens a modal with 3 tabs for managing products

**Time needed:** 5 minutes

---

## 🎯 Visual Example

When you're done, your sidebar will look like this:

```
╔══════════════════════════════════╗
║     SHIPMENT TRACKER SIDEBAR     ║
╠══════════════════════════════════╣
║                                  ║
║  👤 Supplier: ABC Company        ║
║  📧 supplier@abc.com             ║
║  📞 +1-234-567-8900              ║
║                                  ║
║  ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬  ║
║                                  ║
║  📊 Current Stage: LC Opening    ║
║  Progress: 36% Complete          ║
║                                  ║
║  ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬  ║
║                                  ║
║  ┌──────────────────────────┐   ║
║  │ 📁 Manage Documents      │   ║
║  └──────────────────────────┘   ║
║                                  ║
║  ┌──────────────────────────┐   ║ ← YOUR NEW BUTTON!
║  │ 📦 Manage Products     › │   ║
║  └──────────────────────────┘   ║
║                                  ║
║  📅 Timeline:                    ║
║  • Forecast ✓                    ║
║  • PO Created ✓                  ║
║  • LC Opening ⏳                 ║
║                                  ║
╚══════════════════════════════════╝
```

---

**Need help?** Check `INTEGRATION_PATCH_MANAGE_PRODUCTS.html` for complete code examples!
