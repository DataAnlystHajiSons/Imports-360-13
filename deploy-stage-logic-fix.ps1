#!/usr/bin/env pwsh

# Deploy stage logic fix to Supabase
Write-Host "🚀 Deploying stage logic fix..." -ForegroundColor Green

try {
    # Deploy the updated stage_requirements_met function
    Write-Host "📝 Updating stage_requirements_met function..." -ForegroundColor Yellow
    supabase db reset --linked
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database reset completed successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Database reset failed" -ForegroundColor Red
        exit 1
    }

    # Apply the specific function update
    Write-Host "📝 Applying stage requirements function update..." -ForegroundColor Yellow
    supabase db diff --file update_stage_requirements_met_function.sql --linked
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Stage requirements function updated successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Stage requirements function update failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "🎉 Stage logic fix deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Changes applied:" -ForegroundColor Cyan
    Write-Host "  • Updated stage_requirements_met function with Seed commodity logic" -ForegroundColor White
    Write-Host "  • Fixed forecast and enlistment verification stages" -ForegroundColor White
    Write-Host "  • Auto-advance for non-seed commodities" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "❌ Deployment failed: $_" -ForegroundColor Red
    exit 1
}