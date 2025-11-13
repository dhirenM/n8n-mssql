# ==================================================
# Check Settings Response
# ==================================================
# Checks what the /rest/settings endpoint returns
# This determines if push uses WebSocket or SSE
# ==================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "n8n Settings Check" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get your JWT token from browser
Write-Host "To get your JWT token:" -ForegroundColor Yellow
Write-Host "1. Open browser (F12)" -ForegroundColor White
Write-Host "2. Go to Application tab → Cookies" -ForegroundColor White
Write-Host "3. Find 'n8n-auth' cookie value" -ForegroundColor White
Write-Host "4. Paste it here`n" -ForegroundColor White

$jwtToken = Read-Host "Enter your JWT token (or press Enter to try without auth)"

Write-Host "`nTesting /rest/settings endpoint..." -ForegroundColor Yellow
Write-Host ""

# Test with token if provided
$headers = @{}
if ($jwtToken) {
    $headers["Cookie"] = "n8n-auth=$jwtToken"
}

try {
    $response = Invoke-WebRequest -Uri "http://localhost:5678/n8nnet/rest/settings" -Headers $headers -UseBasicParsing
    
    Write-Host "✓ Settings endpoint responded: $($response.StatusCode)" -ForegroundColor Green
    Write-Host ""
    
    # Parse JSON
    $settings = $response.Content | ConvertFrom-Json
    
    # Check push backend setting
    Write-Host "Push Configuration:" -ForegroundColor Cyan
    Write-Host "  pushBackend: $($settings.pushBackend)" -ForegroundColor White
    
    if ($settings.pushBackend -eq 'websocket') {
        Write-Host "  ✓ Using WebSocket (bidirectional)" -ForegroundColor Green
    } elseif ($settings.pushBackend -eq 'sse') {
        Write-Host "  ⚠️  Using SSE (Server-Sent Events)" -ForegroundColor Yellow
        Write-Host "  → This is why you don't see /rest/push WebSocket!" -ForegroundColor Yellow
        Write-Host "  → Solution: Set N8N_PUSH_BACKEND=websocket" -ForegroundColor Cyan
    } else {
        Write-Host "  ? Unknown backend: $($settings.pushBackend)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Other Settings:" -ForegroundColor Cyan
    Write-Host "  isDocker: $($settings.isDocker)" -ForegroundColor White
    Write-Host "  n8nMetadata.userId: $($settings.n8nMetadata.userId)" -ForegroundColor White
    Write-Host "  userManagement.enabled: $($settings.userManagement.enabled)" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Full Settings Response:" -ForegroundColor Cyan
    Write-Host $response.Content -ForegroundColor Gray
    
} catch {
    Write-Host "✗ Settings endpoint failed!" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Response) {
        Write-Host "  Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  1. n8n not running - Start with: .\START_N8N_MSSQL.ps1" -ForegroundColor White
    Write-Host "  2. Wrong base path - Check N8N_PATH setting" -ForegroundColor White
    Write-Host "  3. Settings endpoint error - Check n8n logs" -ForegroundColor White
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "If pushBackend is 'sse' instead of 'websocket':" -ForegroundColor Yellow
Write-Host "1. Set in START_N8N_MSSQL.ps1:" -ForegroundColor White
Write-Host '   $env:N8N_PUSH_BACKEND = "websocket"' -ForegroundColor Cyan
Write-Host "2. Restart n8n" -ForegroundColor White
Write-Host "3. Hard refresh browser (Ctrl+F5)" -ForegroundColor White
Write-Host ""

Write-Host "If pushBackend is already 'websocket':" -ForegroundColor Yellow
Write-Host "1. Check browser console (F12) for JavaScript errors" -ForegroundColor White
Write-Host "2. Look for WebSocket connection attempt" -ForegroundColor White
Write-Host "3. Check if JWT auth is blocking WebSocket" -ForegroundColor White
Write-Host ""

