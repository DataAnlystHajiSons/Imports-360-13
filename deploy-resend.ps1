# 🚀 Deploy Resend Email Functions

Write-Host "🚀 Deploying Updated Email Functions to Resend..." -ForegroundColor Cyan

# Check if supabase CLI is installed
try {
    $null = Get-Command supabase -ErrorAction Stop
} catch {
    Write-Host "❌ Supabase CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "npm install -g supabase"
    exit 1
}

Write-Host ""
Write-Host "📧 Deploying send-freight-query-email function..." -ForegroundColor Green
supabase functions deploy send-freight-query-email

Write-Host ""
Write-Host "📧 Deploying send-sowing-alerts function..." -ForegroundColor Green
supabase functions deploy send-sowing-alerts

Write-Host ""
Write-Host "📧 Deploying send-supplier-docs function..." -ForegroundColor Green
supabase functions deploy send-supplier-docs

Write-Host ""
Write-Host "✅ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🔧 Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 📝 Add Environment Variable:" -ForegroundColor White  
Write-Host "   • RESEND_API_KEY=your_resend_api_key_here"
Write-Host ""
Write-Host "2. 🎯 Test the Updated Functions:" -ForegroundColor White
Write-Host "   • Ensure emails are being sent and received successfully."
Write-Host ""
Write-Host "📚 For detailed setup instructions, see Resend's documentation: https://resend.com/docs/" -ForegroundColor Cyan
Write-Host ""
