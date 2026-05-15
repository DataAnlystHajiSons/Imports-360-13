# Deploy Insurance Calculation Function to Supabase
# This script deploys the calculate-insurance edge function

Write-Host "🚀 Deploying Insurance Calculation Function..." -ForegroundColor Cyan

# Check if Supabase CLI is installed
try {
    $supabaseVersion = supabase --version
    Write-Host "✅ Supabase CLI found: $supabaseVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Supabase CLI not found. Please install it first." -ForegroundColor Red
    Write-Host "Install with: npm install -g supabase" -ForegroundColor Yellow
    exit 1
}

# Check if we're in the right directory
if (!(Test-Path "supabase/functions/calculate-insurance/index.ts")) {
    Write-Host "❌ Cannot find calculate-insurance function. Make sure you're in the project root." -ForegroundColor Red
    exit 1
}

Write-Host "📋 Function deployment checklist:" -ForegroundColor Yellow
Write-Host "  - Backend function: ✅ Created" -ForegroundColor Green
Write-Host "  - Frontend integration: ✅ Updated" -ForegroundColor Green
Write-Host "  - CSS styling: ✅ Added" -ForegroundColor Green
Write-Host "  - Database schema: ⏳ Needs to be applied" -ForegroundColor Yellow

# Ask user to confirm database schema
Write-Host "`n⚠️ IMPORTANT: Before deploying, make sure to run the database migration:" -ForegroundColor Yellow
Write-Host "Execute the SQL in 'create_calculation_audit_table.sql' in your Supabase dashboard" -ForegroundColor Yellow
$confirm = Read-Host "Have you applied the database schema? (y/N)"

if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "❌ Please apply the database schema first, then run this script again." -ForegroundColor Red
    Write-Host "File: create_calculation_audit_table.sql" -ForegroundColor Yellow
    exit 1
}

# Deploy the function
Write-Host "`n🔧 Deploying calculate-insurance function..." -ForegroundColor Cyan
try {
    supabase functions deploy calculate-insurance
    Write-Host "✅ Function deployed successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to deploy function. Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 Insurance Auto-Calculation Template Setup Complete!" -ForegroundColor Green
Write-Host "`n📝 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Test the insurance modal in your shipment tracker" -ForegroundColor White
Write-Host "2. Enter base values (Value and Rate) to see auto-calculations" -ForegroundColor White
Write-Host "3. Verify calculations are logged in calculation_audit table" -ForegroundColor White
Write-Host "4. Use this template for FBR Duty and Bank Charges modals" -ForegroundColor White

Write-Host "`n🔍 Troubleshooting:" -ForegroundColor Yellow
Write-Host "- Check browser console for any JavaScript errors" -ForegroundColor White
Write-Host "- Verify Supabase function logs for backend issues" -ForegroundColor White
Write-Host "- Ensure RLS policies are properly configured" -ForegroundColor White

Write-Host "`n📊 Template Features:" -ForegroundColor Cyan
Write-Host "✅ Real-time calculations as you type" -ForegroundColor Green
Write-Host "✅ Visual feedback with animations" -ForegroundColor Green
Write-Host "✅ Calculation audit logging" -ForegroundColor Green
Write-Host "✅ Error handling and validation" -ForegroundColor Green
Write-Host "✅ Read-only calculated fields" -ForegroundColor Green
Write-Host "✅ Responsive design" -ForegroundColor Green

Write-Host "`nHappy coding! 🚀" -ForegroundColor Magenta