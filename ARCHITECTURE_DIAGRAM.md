# Architecture Diagram: Create Shipment Modal

## Component Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                    admin-dashboard.html                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         Create New Shipment Modal                      │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │          ShipmentFormManager                     │ │ │
│  │  │  (Orchestrates entire form lifecycle)           │ │ │
│  │  │                                                  │ │ │
│  │  │  ┌────────────────────────────────────────────┐ │ │ │
│  │  │  │       ProductRow #1                        │ │ │ │
│  │  │  │  ┌──────────────┬──────────────┬─────────┐│ │ │ │
│  │  │  │  │SearchableDD  │SearchableDD  │  Input  ││ │ │ │
│  │  │  │  │ (Commodity)  │ (Variety)    │ (Qty)   ││ │ │ │
│  │  │  │  └──────────────┴──────────────┴─────────┘│ │ │ │
│  │  │  └────────────────────────────────────────────┘ │ │ │
│  │  │                                                  │ │ │
│  │  │  ┌────────────────────────────────────────────┐ │ │ │
│  │  │  │       ProductRow #2                        │ │ │ │
│  │  │  │  (Dynamically added/removed)               │ │ │ │
│  │  │  └────────────────────────────────────────────┘ │ │ │
│  │  │                                                  │ │ │
│  │  │  ┌────────────────────────────────────────────┐ │ │ │
│  │  │  │     Shipment Details Section               │ │ │ │
│  │  │  │  - Type (LC/DP)                            │ │ │ │
│  │  │  │  - Mode of Transport ⭐ (NEW!)             │ │ │ │
│  │  │  │  - Payment Term                            │ │ │ │
│  │  │  └────────────────────────────────────────────┘ │ │ │
│  │  │                                                  │ │ │
│  │  │  Uses:                                           │ │ │
│  │  │  ├── ShipmentService (API calls)                │ │ │
│  │  │  ├── CommodityService (API calls)               │ │ │
│  │  │  └── FormValidator (validation)                 │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

```
┌─────────────────┐
│  User clicks    │
│  "Create New    │
│   Shipment"     │
└────────┬────────┘
         │
         v
┌─────────────────────────────────────────┐
│  ShipmentFormManager.openModal()        │
│  ├─ Load payment terms                  │
│  ├─ Load product varieties              │
│  └─ Add initial ProductRow              │
└────────┬────────────────────────────────┘
         │
         v
┌─────────────────────────────────────────┐
│  User fills form                        │
│  ├─ Selects commodity (searchable)      │
│  ├─ Selects variety (auto-filtered)     │
│  ├─ Enters quantity                     │
│  ├─ Selects unit (auto-populated)       │
│  ├─ Adds more products (optional)       │
│  ├─ Selects shipment type               │
│  ├─ Selects mode of transport ⭐        │
│  └─ Selects payment term                │
└────────┬────────────────────────────────┘
         │
         v
┌─────────────────────────────────────────┐
│  User clicks "Create Shipment"          │
└────────┬────────────────────────────────┘
         │
         v
┌─────────────────────────────────────────┐
│  FormValidator.validateShipmentForm()   │
│  ├─ Check all required fields           │
│  ├─ Validate mode_of_transport          │
│  ├─ Validate products                   │
│  └─ Return errors or proceed            │
└────────┬────────────────────────────────┘
         │
         v
┌─────────────────────────────────────────┐
│  ShipmentService.generateReferenceCode()│
│  (e.g., "LC-2024-001")                  │
└────────┬────────────────────────────────┘
         │
         v
┌─────────────────────────────────────────┐
│  ShipmentService.createShipment()       │
│  ├─ Insert into 'shipment' table        │
│  ├─ Include mode_of_transport ⭐        │
│  └─ Return shipment ID                  │
└────────┬────────────────────────────────┘
         │
         v
┌─────────────────────────────────────────┐
│  ShipmentService.addProductsToShipment()│
│  ├─ Insert into 'shipment_products'     │
│  └─ Link all products to shipment       │
└────────┬────────────────────────────────┘
         │
         v
┌─────────────────────────────────────────┐
│  Success!                               │
│  ├─ Show success message                │
│  ├─ Reset form                          │
│  ├─ Close modal                         │
│  ├─ Refresh shipments table             │
│  └─ Update dashboard stats              │
└─────────────────────────────────────────┘
```

## Class Diagram

```
┌─────────────────────────────────────────┐
│       ShipmentFormManager               │
├─────────────────────────────────────────┤
│ - supabase: SupabaseClient              │
│ - shipmentService: ShipmentService      │
│ - commodityService: CommodityService    │
│ - productRows: ProductRow[]             │
│ - modal: HTMLElement                    │
│ - form: HTMLFormElement                 │
├─────────────────────────────────────────┤
│ + openModal(): void                     │
│ + closeModal(): void                    │
│ + addProductRow(): void                 │
│ + removeProductRow(row): void           │
│ + handleSubmit(event): Promise<void>    │
│ + getFormData(): object                 │
│ + showMessage(msg, type): void          │
└─────────────────────────────────────────┘
              │
              │ manages
              │
              v
┌─────────────────────────────────────────┐
│          ProductRow                     │
├─────────────────────────────────────────┤
│ - commodityService: CommodityService    │
│ - productVarieties: array               │
│ - commodityDropdown: SearchableDropdown │
│ - varietyDropdown: SearchableDropdown   │
│ - unitDropdown: SearchableDropdown      │
├─────────────────────────────────────────┤
│ + createElement(): void                 │
│ + loadCommodities(): Promise<void>      │
│ + loadUnits(commodityId): Promise<void> │
│ + getData(): object                     │
│ + isValid(): boolean                    │
│ + destroy(): void                       │
└─────────────────────────────────────────┘
              │
              │ uses
              │
              v
┌─────────────────────────────────────────┐
│       SearchableDropdown                │
├─────────────────────────────────────────┤
│ - selectElement: HTMLSelectElement      │
│ - allOptions: array                     │
│ - filteredOptions: array                │
│ - container: HTMLElement                │
│ - input: HTMLInputElement               │
│ - dropdownList: HTMLElement             │
├─────────────────────────────────────────┤
│ + openDropdown(): void                  │
│ + closeDropdown(): void                 │
│ + filterOptions(term): void             │
│ + selectOption(value, text): void       │
│ + handleKeydown(event): void            │
│ + updateOptions(options): void          │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│       ShipmentService                   │
├─────────────────────────────────────────┤
│ - supabase: SupabaseClient              │
├─────────────────────────────────────────┤
│ + generateReferenceCode(type): Promise  │
│ + createShipment(data, userId): Promise │
│ + addProductsToShipment(id, []): Promise│
│ + deleteShipment(id): Promise           │
│ + getPaymentTerms(): Promise            │
│ + getProductVarieties(): Promise        │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│       CommodityService                  │
├─────────────────────────────────────────┤
│ - supabase: SupabaseClient              │
├─────────────────────────────────────────┤
│ + getCommodities(): Promise             │
│ + addCommodity(name): Promise           │
│ + getMeasurementUnits(id): Promise      │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│       FormValidator (static)            │
├─────────────────────────────────────────┤
│ + validateShipmentForm(data): object    │
│ + validateCommodityName(name): object   │
│ + sanitizeInput(input): string          │
└─────────────────────────────────────────┘
```

## File Dependencies

```
admin-dashboard.html
  │
  ├─ imports: admin-dashboard.js
  │
  └─ admin-dashboard.js
        │
        ├─ imports: ShipmentFormManager
        ├─ imports: ShipmentService
        ├─ imports: CommodityService
        │
        └─ ShipmentFormManager.js
              │
              ├─ imports: ProductRow
              ├─ imports: FormValidator
              │
              └─ ProductRow.js
                    │
                    ├─ imports: SearchableDropdown
                    ├─ imports: CommodityService (injected)
                    │
                    └─ SearchableDropdown.js
                          (No dependencies - pure component)
```

## State Management

```
┌─────────────────────────────────────────────────────┐
│             ShipmentFormManager                     │
│                                                     │
│  State:                                             │
│  ┌───────────────────────────────────────────────┐ │
│  │ isLoading: boolean                            │ │
│  │ productRows: ProductRow[]                     │ │
│  │ productVarieties: array                       │ │
│  │ paymentTerms: array                           │ │
│  │ activeCommodityData: object                   │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
│  Each ProductRow maintains its own state:          │
│  ┌───────────────────────────────────────────────┐ │
│  │ selectedCommodity: string                     │ │
│  │ selectedVariety: string                       │ │
│  │ selectedUnit: string                          │ │
│  │ quantity: number                              │ │
│  └───────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## Benefits Visualization

```
Before:                          After:

┌──────────────────────┐         ┌──────────────────────┐
│ admin-dashboard.js   │         │ admin-dashboard.js   │
│                      │         │ (main logic)         │
│ [1,734 lines]        │         │ [~1,200 lines]       │
│                      │         └──────────┬───────────┘
│ - UI rendering       │                    │
│ - API calls          │                    │ imports
│ - Validation         │                    │
│ - State management   │         ┌──────────▼───────────┐
│ - Form logic         │         │    Components/       │
│ - Dropdowns          │         │    Services/Utils    │
│ - Error handling     │         │                      │
│ - Everything mixed   │         │ [~1,010 lines]       │
│                      │         │                      │
│ ❌ Hard to maintain  │         │ ✅ Organized         │
│ ❌ Hard to test      │         │ ✅ Reusable          │
│ ❌ Monolithic        │         │ ✅ Testable          │
│ ❌ Coupled           │         │ ✅ Maintainable      │
└──────────────────────┘         └──────────────────────┘
```

## Key Improvements Summary

✅ **mode_of_transport** field fully integrated  
✅ Component-based architecture  
✅ Searchable dropdowns with keyboard navigation  
✅ Centralized validation  
✅ Loading states and error handling  
✅ Responsive design  
✅ Clean separation of concerns  
✅ Easy to test and maintain  
✅ Reusable components  
✅ Professional UX  
