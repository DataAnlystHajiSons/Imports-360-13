# Product Management System - Architecture

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │           Manage Products Modal                          │ │
│  │  ┌────────────┬────────────┬──────────────┐             │ │
│  │  │  Current   │    Add     │   Change     │             │ │
│  │  │  Products  │  Product   │   History    │   (Tabs)    │ │
│  │  └────────────┴────────────┴──────────────┘             │ │
│  │                                                          │ │
│  │  Features:                                               │ │
│  │  • View all products in table                           │ │
│  │  • Add new products with smart dropdowns                │ │
│  │  • Edit quantities, rates, units                        │ │
│  │  • Remove products with confirmation                    │ │
│  │  • Timeline of all changes                              │ │
│  └──────────────────────────────────────────────────────────┘ │
│                            │                                   │
└────────────────────────────┼───────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│                    JAVASCRIPT LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         manage-products.js (UI Controller)               │ │
│  │  • Handles user interactions                             │ │
│  │  • Form submissions                                      │ │
│  │  • Tab switching                                         │ │
│  │  • Modal open/close                                      │ │
│  └────────────────────────┬─────────────────────────────────┘ │
│                           │                                    │
│                           ↓                                    │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         ProductManager.js (Business Logic)               │ │
│  │  • Product CRUD operations                               │ │
│  │  • Data validation                                       │ │
│  │  • API calls to Supabase                                 │ │
│  │  • Change history retrieval                              │ │
│  └────────────────────────┬─────────────────────────────────┘ │
│                           │                                    │
│                           ↓                                    │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         CommodityService.js (Helper)                     │ │
│  │  • Load commodities                                      │ │
│  │  • Load product varieties                                │ │
│  │  • Load measurement units                                │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────┼───────────────────────────────────┘
                              │
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    DATABASE LAYER (PostgreSQL)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Stored Functions (API)                      │ │
│  │                                                          │ │
│  │  • add_product_to_shipment()                            │ │
│  │    ├─ Validates product doesn't exist                   │ │
│  │    ├─ Inserts into shipment_products                    │ │
│  │    └─ Trigger logs to audit table                       │ │
│  │                                                          │ │
│  │  • remove_product_from_shipment()                       │ │
│  │    ├─ Validates product exists                          │ │
│  │    ├─ Deletes from shipment_products                    │ │
│  │    └─ Trigger logs to audit table                       │ │
│  │                                                          │ │
│  │  • update_shipment_product()                            │ │
│  │    ├─ Validates product exists                          │ │
│  │    ├─ Updates shipment_products                         │ │
│  │    └─ Trigger logs changes to audit                     │ │
│  │                                                          │ │
│  │  • get_shipment_product_history()                       │ │
│  │    └─ Returns formatted change history                  │ │
│  └──────────────────────────────────────────────────────────┘ │
│                           │                                    │
│                           ↓                                    │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Core Tables                                 │ │
│  │                                                          │ │
│  │  shipment_products (Current State)                      │ │
│  │  ├─ shipment_id                                         │ │
│  │  ├─ product_variety_id                                  │ │
│  │  ├─ quantity                                            │ │
│  │  ├─ unit                                                │ │
│  │  ├─ rate                                                │ │
│  │  └─ amount                                              │ │
│  │                                                          │ │
│  │  shipment_products_audit (Change History) ⭐ NEW        │ │
│  │  ├─ id (uuid)                                           │ │
│  │  ├─ shipment_id                                         │ │
│  │  ├─ product_variety_id                                  │ │
│  │  ├─ action (added/removed/changed)                      │ │
│  │  ├─ old_quantity, old_unit, old_rate, old_amount       │ │
│  │  ├─ new_quantity, new_unit, new_rate, new_amount       │ │
│  │  ├─ changed_by (user_id)                               │ │
│  │  ├─ changed_at (timestamp)                             │ │
│  │  └─ change_reason (text)                               │ │
│  └──────────────────────────────────────────────────────────┘ │
│                           │                                    │
│                           ↓                                    │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         Triggers (Automatic Logging)                     │ │
│  │                                                          │ │
│  │  trigger_log_shipment_product_changes                   │ │
│  │  Fires on: INSERT, UPDATE, DELETE                       │ │
│  │  On table: shipment_products                            │ │
│  │                                                          │ │
│  │  Executes: log_shipment_product_changes()               │ │
│  │  ├─ Captures before/after values                        │ │
│  │  ├─ Determines action type                              │ │
│  │  ├─ Gets current user from auth.uid()                   │ │
│  │  └─ Inserts audit record automatically                  │ │
│  └──────────────────────────────────────────────────────────┘ │
│                           │                                    │
│                           ↓                                    │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Views (Query Helpers)                       │ │
│  │                                                          │ │
│  │  v_shipment_products_history                            │ │
│  │  Joins:                                                  │ │
│  │  • shipment_products_audit                              │ │
│  │  • shipment (for reference_code)                        │ │
│  │  • product_variety (for names)                          │ │
│  │  • commodity (for commodity name)                       │ │
│  │  • app_user (for user details)                          │ │
│  │                                                          │ │
│  │  Provides: Complete change history with all context     │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow Diagrams

### Adding a Product

```
User fills form
    ↓
Clicks "Add Product"
    ↓
manage-products.js: handleAddProduct()
    ↓
ProductManager.addProduct()
    ↓
Supabase RPC: add_product_to_shipment()
    ↓
Database Function validates:
    - Shipment exists? ✓
    - Product variety exists? ✓
    - Product not already in shipment? ✓
    ↓
INSERT INTO shipment_products
    ↓
Trigger fires automatically ⚡
    ↓
log_shipment_product_changes()
    - Captures: NEW values
    - Action: 'added'
    - User: auth.uid()
    - Timestamp: now()
    ↓
INSERT INTO shipment_products_audit
    ↓
Returns success to frontend
    ↓
UI refreshes:
    - Current Products table updated
    - Change History shows new entry
    ↓
User sees: "Product added successfully!" ✅
```

### Editing a Product

```
User clicks Edit button
    ↓
Edit modal opens with current values
    ↓
User changes quantity: 100 → 200
    ↓
Clicks "Save Changes"
    ↓
manage-products.js: handleEditProduct()
    ↓
ProductManager.updateProduct()
    ↓
Supabase RPC: update_shipment_product()
    ↓
UPDATE shipment_products
SET quantity = 200
WHERE shipment_id = X AND product_variety_id = Y
    ↓
Trigger fires automatically ⚡
    ↓
log_shipment_product_changes()
    - Captures: OLD.quantity = 100
    - Captures: NEW.quantity = 200
    - Action: 'quantity_changed'
    - User: auth.uid()
    - Reason: user-provided text
    ↓
INSERT INTO shipment_products_audit
    (old_quantity=100, new_quantity=200, ...)
    ↓
Returns success to frontend
    ↓
UI refreshes:
    - Current Products shows 200
    - Change History: "Quantity Changed: 100 → 200"
    ↓
User sees: "Product updated successfully!" ✅
```

### Removing a Product

```
User clicks Delete button
    ↓
Confirmation modal: "Are you sure?"
    ↓
User enters reason (optional)
    ↓
Clicks "Yes, Remove Product"
    ↓
manage-products.js: confirmRemoveProduct()
    ↓
ProductManager.removeProduct()
    ↓
Supabase RPC: remove_product_from_shipment()
    ↓
DELETE FROM shipment_products
WHERE shipment_id = X AND product_variety_id = Y
    ↓
Trigger fires automatically ⚡
    ↓
log_shipment_product_changes()
    - Captures: OLD values (quantity, unit, rate, amount)
    - Action: 'removed'
    - User: auth.uid()
    - Reason: user-provided text
    ↓
INSERT INTO shipment_products_audit
    (old_quantity, old_unit, ..., action='removed')
    ↓
Returns success to frontend
    ↓
UI refreshes:
    - Product removed from table
    - Change History: "Removed: Product Name (100 KG)"
    ↓
User sees: "Product removed successfully!" ✅
```

### Viewing Change History

```
User clicks "Change History" tab
    ↓
manage-products.js: loadChangeHistory()
    ↓
ProductManager.getDetailedHistory()
    ↓
Supabase query: v_shipment_products_history
    ↓
Database view joins:
    - shipment_products_audit (changes)
    - product_variety (product names)
    - commodity (commodity names)
    - app_user (user details)
    - shipment (reference code)
    ↓
Returns array of change records:
    [
      {
        action: 'added',
        product_name: 'Wheat',
        variety_name: 'Premium',
        new_quantity: 100,
        changed_by_name: 'John Doe',
        changed_at: '2026-01-28T14:30:00Z',
        change_reason: 'Customer request'
      },
      ...
    ]
    ↓
Frontend renders timeline:
    • Visual timeline with dots
    • Most recent at top
    • Color-coded by action
    • Shows user, time, reason
    ↓
User sees complete audit trail! ✅
```

---

## 🔐 Security Architecture

```
┌────────────────────────────────────────────┐
│         Row-Level Security (RLS)           │
├────────────────────────────────────────────┤
│                                            │
│  shipment_products                         │
│  • Users can view products in their        │
│    authorized shipments                    │
│  • Users can insert/update/delete          │
│    with proper role                        │
│                                            │
│  shipment_products_audit                   │
│  • Users can view audit logs for           │
│    shipments they have access to           │
│  • System can insert (via trigger)         │
│  • Users cannot modify audit logs          │
│    (append-only)                           │
│                                            │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│         Authentication Flow                │
├────────────────────────────────────────────┤
│                                            │
│  1. User logs in via Supabase Auth         │
│  2. JWT token stored in browser            │
│  3. Every API call includes token          │
│  4. Database uses auth.uid() to get user   │
│  5. RLS policies check permissions         │
│  6. Audit logs capture user ID             │
│                                            │
└────────────────────────────────────────────┘
```

---

## 📊 Data Model

```
shipment
├── id (PK)
├── reference_code
└── ... other fields

       │
       │ 1
       │
       │ N
       ↓

shipment_products (CURRENT STATE)
├── shipment_id (FK) ─────────┐
├── product_variety_id (FK)   │
├── quantity                  │
├── unit                      │
├── rate                      │
└── amount                    │
                              │
       ┌──────────────────────┘
       │
       │ Trigger watches this table
       │ Logs all INSERT/UPDATE/DELETE
       │
       ↓

shipment_products_audit (CHANGE HISTORY)
├── id (PK)
├── shipment_id (FK)
├── product_variety_id (FK)
├── action ─────────────────── added/removed/changed
├── old_quantity ───────────── Before value
├── old_unit
├── old_rate
├── old_amount
├── new_quantity ───────────── After value
├── new_unit
├── new_rate
├── new_amount
├── changed_by (FK) ────────── Who made the change
├── changed_at ─────────────── When it happened
├── change_reason ──────────── Why (optional)
└── metadata ───────────────── Extra context (JSON)

       │
       │ Used by
       │
       ↓

v_shipment_products_history (VIEW)
└── Joins all related tables
    └── Provides human-readable history
```

---

## 🎯 Component Interaction

```
┌───────────────────────────────────────────────────────┐
│                manage-products.js                     │
│                 (UI Controller)                       │
│                                                       │
│  Responsibilities:                                    │
│  • Open/close modals                                 │
│  • Tab switching                                     │
│  • Form validation                                   │
│  • Event handling                                    │
│  • UI updates                                        │
│                                                       │
│  Calls ↓                                             │
└───────────────────────┬───────────────────────────────┘
                        │
                        ↓
┌───────────────────────────────────────────────────────┐
│              ProductManager.js                        │
│              (Business Logic)                         │
│                                                       │
│  Responsibilities:                                    │
│  • Data management                                   │
│  • API calls to Supabase                            │
│  • State management                                  │
│  • Data transformation                               │
│  • Error handling                                    │
│                                                       │
│  Uses ↓                                              │
└───────────────────────┬───────────────────────────────┘
                        │
                        ↓
┌───────────────────────────────────────────────────────┐
│            CommodityService.js                        │
│              (Helper Service)                         │
│                                                       │
│  Responsibilities:                                    │
│  • Load commodities                                  │
│  • Load product varieties                            │
│  • Load measurement units                            │
│  • Cache data                                        │
│                                                       │
└───────────────────────────────────────────────────────┘

All components use → Supabase Client → Database
```

---

## 🚀 Performance Considerations

### Database Indexes
```sql
-- Already created in migration:
CREATE INDEX idx_shipment_products_audit_shipment 
  ON shipment_products_audit(shipment_id);

CREATE INDEX idx_shipment_products_audit_changed_at 
  ON shipment_products_audit(changed_at DESC);

-- For fast lookups:
• Get history for shipment → indexed on shipment_id
• Get recent changes → indexed on changed_at
• Join with users → indexed on changed_by
```

### Caching Strategy
```
ProductManager:
├── productVarieties (cached on init)
├── products (reloaded after changes)
└── currentUser (cached on init)

Benefits:
• No redundant API calls
• Fast dropdown population
• Instant variety filtering
```

### Lazy Loading
```
Change History tab:
• Not loaded until user clicks tab
• Limits to 50 most recent changes
• Can be increased if needed
• Query is fast due to indexes
```

---

## 🎨 UI/UX Flow

```
Manage Products Modal
│
├─ Tab 1: Current Products (Default)
│  │
│  ├─ Shows: Table of all products
│  ├─ Actions: Edit, Delete
│  └─ Empty state: "Add Your First Product"
│
├─ Tab 2: Add Product
│  │
│  ├─ Step 1: Select Commodity
│  ├─ Step 2: Select Variety (auto-filtered)
│  ├─ Step 3: Enter Quantity
│  ├─ Step 4: Unit auto-fills
│  ├─ Step 5: Rate auto-fills (if available)
│  ├─ Step 6: Amount auto-calculates
│  └─ Submit: Product added → Switch to Tab 1
│
└─ Tab 3: Change History
   │
   ├─ Shows: Timeline of all changes
   ├─ Format: Newest first
   ├─ Details: Action, User, Time, Reason
   └─ Empty state: "No changes yet"

Modals (Sub-modals):
│
├─ Edit Product Modal
│  ├─ Pre-filled with current values
│  ├─ Can change: Quantity, Unit, Rate
│  └─ Optional: Reason for change
│
└─ Remove Product Modal
   ├─ Confirmation: "Are you sure?"
   ├─ Shows: Product being removed
   └─ Optional: Reason for removal
```

---

**System is production-ready and fully documented!** 🎉
