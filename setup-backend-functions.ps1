# ============================================================================
# Backend Functions Setup Script
# ============================================================================
# This script helps you add the missing stage_requirements_met function
# to your Supabase database.

Write-Host "🔧 Backend Functions Setup for Stage Auto-Advancement" -ForegroundColor Cyan
Write-Host ""

# Check if SQL file exists
if (!(Test-Path "stage_requirements_met.sql")) {
    Write-Host "❌ Error: stage_requirements_met.sql not found!" -ForegroundColor Red
    Write-Host "Make sure the SQL file is in the current directory." -ForegroundColor Yellow
    exit 1
}

Write-Host "📋 Setup Instructions:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 🌐 Open your Supabase Dashboard" -ForegroundColor White
Write-Host "   https://supabase.com/dashboard/project/sfknzqkiqxivzcualcau"
Write-Host ""
Write-Host "2. 📝 Go to SQL Editor" -ForegroundColor White
Write-Host "   Click on 'SQL Editor' in the left sidebar"
Write-Host ""
Write-Host "3. 📄 Copy the SQL function" -ForegroundColor White
Write-Host "   Copy the contents of: stage_requirements_met.sql"
Write-Host ""
Write-Host "4. ▶️  Run the SQL" -ForegroundColor White
Write-Host "   Paste and execute the SQL in the editor"
Write-Host ""
Write-Host "5. ✅ Verify creation" -ForegroundColor White
Write-Host "   The function should be created without errors"
Write-Host ""

# Display file content size
$fileSize = (Get-Item "stage_requirements_met.sql").Length
Write-Host "📊 Function Details:" -ForegroundColor Green
Write-Host "   • File size: $fileSize bytes" -ForegroundColor Gray
Write-Host "   • Handles all 22 stages in your workflow" -ForegroundColor Gray
Write-Host "   • Implements forecast and enlistment validation" -ForegroundColor Gray
Write-Host "   • Uses existing v_shipment_stage_checklist view" -ForegroundColor Gray
Write-Host ""

Write-Host "🎯 What this function enables:" -ForegroundColor Green
Write-Host "   ✅ Automatic advancement: forecast → enlistment_verification" -ForegroundColor Gray
Write-Host "   ✅ Automatic advancement: enlistment_verification → availability_confirmation" -ForegroundColor Gray
Write-Host "   ✅ Manual stage progression for all stages" -ForegroundColor Gray
Write-Host "   ✅ Data validation based on forecast table" -ForegroundColor Gray
Write-Host "   ✅ Complete workflow integrity" -ForegroundColor Gray
Write-Host ""

Write-Host "⚠️  IMPORTANT:" -ForegroundColor Red
Write-Host "   Your shipment tracker will NOT work properly until this function is added!" -ForegroundColor Yellow
Write-Host ""

# Option to open SQL file for easy copying
Write-Host "📋 Would you like to open the SQL file for copying? (y/n): " -ForegroundColor Cyan -NoNewline
$response = Read-Host

if ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes') {
    try {
        # Open in default text editor
        Start-Process "stage_requirements_met.sql"
        Write-Host "✅ SQL file opened! Copy the contents and paste into Supabase SQL Editor." -ForegroundColor Green
    } catch {
        Write-Host "❌ Could not open file automatically. Please open stage_requirements_met.sql manually." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🔗 Quick Links:" -ForegroundColor Cyan
Write-Host "   • Supabase Dashboard: https://supabase.com/dashboard/project/sfknzqkiqxivzcualcau" -ForegroundColor Blue
Write-Host "   • SQL Editor: https://supabase.com/dashboard/project/sfknzqkiqxivzcualcau/sql" -ForegroundColor Blue
Write-Host ""

Write-Host "📞 After adding the function:" -ForegroundColor Green
Write-Host "   1. Test your shipment tracker" -ForegroundColor Gray
Write-Host "   2. Try advancing stages manually" -ForegroundColor Gray  
Write-Host "   3. Check if auto-advancement works for forecast/enlistment stages" -ForegroundColor Gray
Write-Host ""

Write-Host "✨ Happy shipping! 🚢" -ForegroundColor Magenta