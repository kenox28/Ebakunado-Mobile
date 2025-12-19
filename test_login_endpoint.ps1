# PowerShell script to test login endpoint
# This helps verify if the server is accepting POST requests

$baseUrl = "https://ebakunado.com"
$endpoint = "$baseUrl/php/supabase/login_mobile_user.php"

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Testing login endpoint: $endpoint" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test with dummy credentials (should return error but show if endpoint is reachable)
$body = @{
    Email_number = "test@example.com"
    password = "testpassword"
}

# Create headers to mimic a browser request
$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Accept" = "application/json, text/plain, */*"
    "Accept-Language" = "en-US,en;q=0.9"
    "Origin" = $baseUrl
    "Referer" = "$baseUrl/"
}

Write-Host "Test 1: POST with browser-like headers..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $endpoint -Method POST -Body $body -Headers $headers -UseBasicParsing -ErrorAction Stop
    
    Write-Host "✅ SUCCESS - Server responded!" -ForegroundColor Green
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "❌ Test 1 FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test 2: GET request to check if endpoint exists..." -ForegroundColor Yellow
try {
    $getResponse = Invoke-WebRequest -Uri $endpoint -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop
    Write-Host "✅ GET request succeeded (Status: $($getResponse.StatusCode))" -ForegroundColor Green
    $responsePreview = $getResponse.Content.Substring(0, [Math]::Min(200, $getResponse.Content.Length))
    Write-Host "Response Preview: $responsePreview" -ForegroundColor Green
    
    # Check if domain is suspended
    if ($getResponse.Content -like "*suspended*" -or $getResponse.Content -like "*Suspended*") {
        Write-Host "⚠️  WARNING: Domain appears to still be suspended!" -ForegroundColor Yellow
        Write-Host "   If you just reactivated, wait 15-30 minutes for propagation." -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ GET request also failed" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test 3: Testing base URL connectivity..." -ForegroundColor Yellow
try {
    $baseResponse = Invoke-WebRequest -Uri $baseUrl -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop
    Write-Host "✅ Base URL is accessible (Status: $($baseResponse.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "❌ Base URL is NOT accessible" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "DIAGNOSIS:" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "If ALL tests failed with 'connection forcibly closed':" -ForegroundColor Yellow
Write-Host "  → Server is blocking/terminating connections" -ForegroundColor Red
Write-Host "  → Check Hostinger mod_security/firewall settings" -ForegroundColor Red
Write-Host "  → Contact Hostinger support to whitelist your IP" -ForegroundColor Red
Write-Host ""
Write-Host "If GET works but POST fails:" -ForegroundColor Yellow
Write-Host "  → mod_security is blocking POST requests" -ForegroundColor Red
Write-Host "  → Need to disable mod_security or whitelist endpoint" -ForegroundColor Red
Write-Host ""
Write-Host "If you see 'Invalid email/phone or password':" -ForegroundColor Yellow
Write-Host "  → Endpoint is working! The issue is in Flutter app" -ForegroundColor Green
Write-Host ""
Write-Host "If domain shows 'suspended' but you just reactivated:" -ForegroundColor Yellow
Write-Host "  → Wait 15-30 minutes for DNS/CDN propagation" -ForegroundColor Cyan
Write-Host "  → Try testing Flutter app directly (may work before PowerShell test)" -ForegroundColor Cyan
Write-Host "  → Clear browser cache and test again" -ForegroundColor Cyan
