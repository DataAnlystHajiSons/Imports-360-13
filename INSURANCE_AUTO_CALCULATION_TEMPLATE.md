# Insurance Auto-Calculation Template

This document provides a complete template for implementing auto-calculations in the Bills stage modals. The Insurance modal has been fully implemented as a working example that can be replicated for FBR Duty and Bank Charges.

## 🎯 Overview

The template implements:
- **Backend calculations** using Supabase Edge Functions
- **Real-time frontend updates** with visual feedback
- **Calculation auditing** for compliance and debugging
- **Error handling** and validation
- **Responsive design** with user-friendly interfaces

## 📁 Files Created/Modified

### Backend Function
- `supabase/functions/calculate-insurance/index.ts` - Main calculation logic
- `supabase/functions/calculate-insurance/deno.json` - Deno configuration

### Database Schema
- `create_calculation_audit_table.sql` - Audit table for tracking calculations

### Frontend Updates
- `js/shipment-tracker.js` - Updated with calculation integration
- `shipment_tracker.html` - Enhanced insurance modal with UX improvements
- `css/shipment-tracker.css` - Styling for calculated fields and animations

### Deployment
- `deploy-insurance-calculation.ps1` - Automated deployment script

## 🔧 Implementation Details

### 1. Backend Function Structure

```typescript
// Input interface
interface InsuranceInput {
  value: number;
  rate: number;
  marine_perc: number;
  war_perc: number;
  asc_1: number;
  fif_perc: number;
  sts_perc: number;
  stamp: number;
}

// Calculation logic follows the criteria exactly:
// amount = value * rate
// ten_perc = amount * 10%
// total_value = amount + ten_perc
// marine_amount = total_value * marine_perc %
// war_amount = total_value * war_perc %
// fif_amount = (marine_amount + war_amount + asc_1) * fif_perc
// sts_amount = (marine_amount + war_amount + asc_1) * sts_perc
// grand_total = (marine_amount + war_amount + asc_1) + fif_amount + sts_amount + stamp
```

### 2. Frontend Integration

**Event Listeners**
- Input fields trigger calculations on `blur` and `input` events
- Debounced to prevent excessive API calls
- Visual feedback during calculation process

**Field Updates**
- Calculated fields are read-only with special styling
- Animation feedback when values update
- Error states for failed calculations

**User Experience**
- 🔄 indicators show auto-calculated fields
- Required field indicators (`*`)
- Tooltips explain calculation formulas
- Loading states during calculations

### 3. Database Auditing

All calculations are logged in the `calculation_audit` table:
```sql
CREATE TABLE calculation_audit (
  id uuid PRIMARY KEY,
  shipment_id uuid REFERENCES shipment(id),
  calculation_type text NOT NULL,
  input_data jsonb NOT NULL,
  output_data jsonb NOT NULL,
  calculated_at timestamp with time zone DEFAULT now(),
  calculated_by uuid REFERENCES app_user(id)
);
```

## 🚀 Deployment Instructions

### Step 1: Apply Database Schema
1. Open your Supabase dashboard
2. Go to SQL Editor
3. Run the contents of `create_calculation_audit_table.sql`

### Step 2: Deploy Backend Function
```powershell
# Run the deployment script
.\deploy-insurance-calculation.ps1

# Or manually deploy
supabase functions deploy calculate-insurance
```

### Step 3: Test the Implementation
1. Open shipment tracker
2. Navigate to Bills stage
3. Open Insurance modal
4. Enter Value and Rate to see auto-calculations

## 🎨 Visual Features

### Field Styling
- **Input fields**: Standard styling with purple focus states
- **Calculated fields**: Green gradient background with lock icon
- **Grand total**: Special gold styling to highlight importance
- **Error states**: Red styling for calculation failures

### Animations
- **Calculation feedback**: Green flash when values update
- **Loading shimmer**: Animated shimmer during calculations
- **Hover effects**: Tooltips showing calculation formulas

### Responsive Design
- Mobile-optimized form layouts
- Touch-friendly interaction areas
- Proper spacing and typography scaling

## 📋 Template Replication Guide

To implement this pattern for other modals (FBR Duty, Bank Charges):

### 1. Create Backend Function
```bash
# Create new function directory
mkdir supabase/functions/calculate-fbr-duty
mkdir supabase/functions/calculate-bank-charges

# Copy template and modify calculation logic
cp supabase/functions/calculate-insurance/index.ts supabase/functions/calculate-fbr-duty/
cp supabase/functions/calculate-insurance/deno.json supabase/functions/calculate-fbr-duty/
```

### 2. Update Calculation Logic
Modify the calculation function to match your criteria:
- FBR Duty: 18-step cascade calculation
- Bank Charges: Rate conversion and percentage calculations

### 3. Frontend Integration
```javascript
// Add calculation function
async function calculateFBRDuty() {
  const { data } = await supabase.functions.invoke('calculate-fbr-duty', {
    body: { input: collectInputValues() }
  });
  updateCalculatedFields(data.calculations);
}

// Add event listeners
setupFBRDutyCalculationListeners();
```

### 4. HTML Updates
- Mark calculated fields as `readonly`
- Add `calculated-field` CSS class
- Include 🔄 indicators
- Add tooltips with formulas

## 📊 Calculation Criteria Implementation

### Insurance ✅ COMPLETE
- 9 calculation steps
- Real-time updates
- Full audit trail
- Error handling

### FBR Duty 🔄 TEMPLATE READY
- 18 calculation steps needed
- Complex cascading logic
- Multiple tax rates and values
- Use insurance template as base

### Bank Charges 🔄 TEMPLATE READY  
- 6 calculation steps needed
- Currency conversion logic
- Percentage calculations
- Use insurance template as base

## 🐛 Testing & Debugging

### Browser Console
Check for JavaScript errors and calculation logs:
```javascript
// Calculation breakdown is logged
console.log('Insurance Calculation Breakdown:', calc.calculation_breakdown);
```

### Supabase Function Logs
Monitor backend function execution:
1. Go to Supabase Dashboard
2. Functions section
3. View logs for calculate-insurance

### Database Queries
Verify calculations are logged:
```sql
SELECT * FROM calculation_audit 
WHERE calculation_type = 'insurance'
ORDER BY calculated_at DESC;
```

## 🔒 Security Considerations

- All calculations run on the backend (tamper-proof)
- Input validation prevents invalid data
- RLS policies protect audit data
- User authentication required for calculations

## 📈 Performance Optimizations

- Debounced input events (500ms delay)
- Efficient calculation algorithms
- Minimal DOM updates
- Cached calculation results where possible

## 🎯 Next Steps

1. **Test thoroughly** with various input combinations
2. **Deploy FBR Duty** calculations using this template
3. **Deploy Bank Charges** calculations using this template
4. **Add calculation history** viewing capabilities
5. **Implement calculation comparison** features

## 🤝 Support

For issues or questions:
1. Check browser console for frontend errors
2. Check Supabase function logs for backend errors
3. Verify database schema and RLS policies
4. Ensure all required environment variables are set

---

**Template Status**: ✅ Production Ready  
**Last Updated**: January 2025  
**Version**: 1.0.0

This template provides a solid foundation for implementing auto-calculations across all Bills stage modals with consistency, reliability, and excellent user experience.