# ============================================================================
# Stage Target Dates Feature - Deployment Script
# ============================================================================
# This script helps deploy the stage target dates feature to your Supabase project
# ============================================================================

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  STAGE TARGET DATES FEATURE - DEPLOYMENT SCRIPT" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Supabase CLI is installed
$supabaseCLI = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseCLI) {
    Write-Host "❌ Supabase CLI not found!" -ForegroundColor Red
    Write-Host "Please install it first: https://supabase.com/docs/guides/cli" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Supabase CLI found" -ForegroundColor Green
Write-Host ""

# Check if logged in
Write-Host "Checking Supabase login status..." -ForegroundColor Yellow
$loginCheck = supabase projects list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not logged in to Supabase CLI" -ForegroundColor Red
    Write-Host "Please run: supabase login" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Logged in to Supabase" -ForegroundColor Green
Write-Host ""

# List available projects
Write-Host "Available Supabase projects:" -ForegroundColor Cyan
supabase projects list
Write-Host ""

# Ask for project reference
$projectRef = Read-Host "Enter your Supabase project reference ID"
if ([string]::IsNullOrWhiteSpace($projectRef)) {
    Write-Host "❌ Project reference is required!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  STEP 1: DEPLOYING EDGE FUNCTION" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

$deployFunction = Read-Host "Deploy edge function? (y/n)"
if ($deployFunction -eq "y") {
    Write-Host "Deploying send-stage-target-alerts function..." -ForegroundColor Yellow
    
    # Link to project
    supabase link --project-ref $projectRef
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to link to project" -ForegroundColor Red
        exit 1
    }
    
    # Deploy function
    supabase functions deploy send-stage-target-alerts
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Edge function deployed successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to deploy edge function" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "⏭️  Skipping edge function deployment" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  STEP 2: ENVIRONMENT VARIABLES" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Please set the following environment variables in Supabase Dashboard:" -ForegroundColor Yellow
Write-Host "  Dashboard → Settings → Edge Functions → Environment Variables" -ForegroundColor Gray
Write-Host ""
Write-Host "  1. RESEND_API_KEY - Your Resend API key for sending emails" -ForegroundColor White
Write-Host "  2. APP_URL - Your application URL (e.g., https://yourapp.com)" -ForegroundColor White
Write-Host ""

$envDone = Read-Host "Have you set the environment variables? (y/n)"
if ($envDone -ne "y") {
    Write-Host "⚠️  Please set environment variables before proceeding" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  STEP 3: DATABASE SETUP" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

$runSQL = Read-Host "Run database setup SQL? This will create tables and functions (y/n)"
if ($runSQL -eq "y") {
    Write-Host "Applying database migrations..." -ForegroundColor Yellow
    
    $sqlFile = "add_stage_target_dates.sql"
    if (Test-Path $sqlFile) {
        # Run SQL using Supabase CLI
        Get-Content $sqlFile | supabase db execute
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Database setup completed!" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to run database setup" -ForegroundColor Red
            Write-Host "You can manually run the SQL file in Supabase Dashboard → SQL Editor" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ SQL file not found: $sqlFile" -ForegroundColor Red
        Write-Host "Please ensure add_stage_target_dates.sql is in the current directory" -ForegroundColor Yellow
    }
} else {
    Write-Host "⏭️  Skipping database setup" -ForegroundColor Yellow
    Write-Host "💡 Remember to run add_stage_target_dates.sql manually in SQL Editor" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  STEP 4: CONFIGURE ALERT EMAILS" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "You need to configure email recipients for alerts." -ForegroundColor Yellow
Write-Host "Add emails to the alert_emails_list table:" -ForegroundColor White
Write-Host ""
Write-Host "  INSERT INTO alert_emails_list (emails)" -ForegroundColor Gray
Write-Host "  VALUES ('email1@example.com,email2@example.com');" -ForegroundColor Gray
Write-Host ""

$emailsDone = Read-Host "Have you configured alert email recipients? (y/n)"
if ($emailsDone -ne "y") {
    Write-Host "⚠️  Remember to add email recipients to alert_emails_list table" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  STEP 5: SETUP CRON JOB" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "To enable automated alerts, you need to set up a scheduled job." -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1: Supabase Cron Extension (Recommended)" -ForegroundColor White
Write-Host "  Go to: Dashboard → Database → Cron Jobs → New Cron Job" -ForegroundColor Gray
Write-Host "  Schedule: 0 9 * * * (daily at 9:00 AM)" -ForegroundColor Gray
Write-Host "  Command:" -ForegroundColor Gray
Write-Host "    SELECT net.http_post(" -ForegroundColor DarkGray
Write-Host "      url := 'https://$projectRef.supabase.co/functions/v1/send-stage-target-alerts'," -ForegroundColor DarkGray
Write-Host "      headers := jsonb_build_object(" -ForegroundColor DarkGray
Write-Host "        'Content-Type', 'application/json'," -ForegroundColor DarkGray
Write-Host "        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'" -ForegroundColor DarkGray
Write-Host "      )" -ForegroundColor DarkGray
Write-Host "    );" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Option 2: External Cron Service" -ForegroundColor White
Write-Host "  Use GitHub Actions, cron-job.org, or similar services" -ForegroundColor Gray
Write-Host "  Endpoint: https://$projectRef.supabase.co/functions/v1/send-stage-target-alerts" -ForegroundColor Gray
Write-Host ""

$cronDone = Read-Host "Have you set up the cron job? (y/n)"
if ($cronDone -ne "y") {
    Write-Host "⚠️  Remember to set up the cron job for automated alerts" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  STEP 6: TEST THE FUNCTION" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

$testFunction = Read-Host "Test the function now? (y/n)"
if ($testFunction -eq "y") {
    Write-Host "Testing edge function..." -ForegroundColor Yellow
    Write-Host ""
    
    $anonKey = Read-Host "Enter your Supabase anon key (for testing)"
    if (-not [string]::IsNullOrWhiteSpace($anonKey)) {
        $url = "https://$projectRef.supabase.co/functions/v1/send-stage-target-alerts"
        
        try {
            $response = Invoke-RestMethod -Uri $url -Method Post `
                -Headers @{
                    "Authorization" = "Bearer $anonKey"
                    "Content-Type" = "application/json"
                } `
                -Body "{}" `
                -ErrorAction Stop
            
            Write-Host "✅ Function test successful!" -ForegroundColor Green
            Write-Host "Response:" -ForegroundColor Cyan
            $response | ConvertTo-Json -Depth 10
        } catch {
            Write-Host "❌ Function test failed!" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    } else {
        Write-Host "⏭️  Skipping function test" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  DEPLOYMENT SUMMARY" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Deployment script completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Integrate UI changes (see STAGE_TARGET_DATES_INTEGRATION.txt)" -ForegroundColor White
Write-Host "  2. Test setting target dates in the shipment tracker" -ForegroundColor White
Write-Host "  3. Monitor edge function logs for any issues" -ForegroundColor White
Write-Host "  4. Verify email alerts are being sent correctly" -ForegroundColor White
Write-Host ""
Write-Host "Documentation:" -ForegroundColor Cyan
Write-Host "  - Full integration guide: STAGE_TARGET_DATES_INTEGRATION.txt" -ForegroundColor Gray
Write-Host "  - Database setup: add_stage_target_dates.sql" -ForegroundColor Gray
Write-Host "  - Edge function: supabase/functions/send-stage-target-alerts/index.ts" -ForegroundColor Gray
Write-Host "  - Frontend module: js/stage-target-dates.js" -ForegroundColor Gray
Write-Host "  - Styles: css/stage-target-dates.css" -ForegroundColor Gray
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  Thank you for using Stage Target Dates Feature!" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
