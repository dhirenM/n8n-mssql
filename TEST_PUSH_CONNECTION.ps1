# ==================================================
# Test Push Connection
# ==================================================
# Quick script to test if push endpoint is accessible
# ==================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "n8n Push Connection Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test 1: Check if n8n is running
Write-Host "1. Checking if n8n is running..." -ForegroundColor Yellow
$n8nProcess = Get-Process | Where-Object {$_.ProcessName -eq "node" -and $_.Path -like "*n8n*"}
if ($n8nProcess) {
    Write-Host "   ✓ n8n process found (PID: $($n8nProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "   ✗ n8n process NOT found!" -ForegroundColor Red
    Write-Host "   Start n8n with: .\START_N8N_MSSQL.ps1" -ForegroundColor Yellow
    exit 1
}

# Test 2: Check if push endpoint responds (direct to backend)
Write-Host "`n2. Testing push endpoint (direct to backend)..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5678/n8nnet/rest/push" -Method GET -TimeoutSec 5 -ErrorAction Stop
    Write-Host "   ✓ Push endpoint responds: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Push endpoint error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Write-Host "   → 401 means endpoint exists but needs auth (this is OK)" -ForegroundColor Cyan
    } elseif ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "   → 404 means endpoint NOT registered at /n8nnet/rest/push" -ForegroundColor Red
        Write-Host "   → n8n may need restart to load server.ts changes" -ForegroundColor Yellow
    }
}

# Test 3: Check through nginx
Write-Host "`n3. Testing push endpoint (through nginx)..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://cmqacore.elevatelocal.com:5000/n8nnet/rest/push" -Method GET -TimeoutSec 5 -ErrorAction Stop
    Write-Host "   ✓ Nginx forwards to push endpoint: $($response.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Nginx push endpoint error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Yellow
    
    if ($_.Exception.Response.StatusCode.value__ -eq 502) {
        Write-Host "   → 502 Bad Gateway: nginx can't reach backend" -ForegroundColor Red
    }
}

# Test 4: Check nginx config for WebSocket support
Write-Host "`n4. Checking nginx WebSocket config..." -ForegroundColor Yellow
$nginxConfig = Get-Content "c:\nginx-1.27.4\conf\nginx.conf" -Raw
if ($nginxConfig -match "Upgrade.*http_upgrade" -and $nginxConfig -match 'Connection.*"upgrade"') {
    Write-Host "   ✓ nginx has WebSocket support configured" -ForegroundColor Green
} else {
    Write-Host "   ✗ nginx WebSocket headers NOT found!" -ForegroundColor Red
    Write-Host "   → Add these to /n8nnet/ location block:" -ForegroundColor Yellow
    Write-Host "      proxy_set_header Upgrade `$http_upgrade;" -ForegroundColor White
    Write-Host '      proxy_set_header Connection "upgrade";' -ForegroundColor White
}

# Test 5: Check environment variables
Write-Host "`n5. Checking environment variables..." -ForegroundColor Yellow
Write-Host "   N8N_PATH = $env:N8N_PATH" -ForegroundColor White
Write-Host "   N8N_PUSH_BACKEND = $env:N8N_PUSH_BACKEND" -ForegroundColor White

if ([string]::IsNullOrEmpty($env:N8N_PUSH_BACKEND)) {
    Write-Host "   ⚠️  N8N_PUSH_BACKEND not set (defaults to 'websocket')" -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Diagnostic Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. If you see 404 on push endpoint:" -ForegroundColor White
Write-Host "   → Restart n8n: .\START_N8N_MSSQL.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. If you see 401 (Unauthorized):" -ForegroundColor White
Write-Host "   → Check browser console (F12) for auth errors" -ForegroundColor Cyan
Write-Host "   → JWT token may not be sent with push connection" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. If you see 502 (Bad Gateway):" -ForegroundColor White
Write-Host "   → Restart nginx: nginx -s reload" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Open browser console (F12) and check:" -ForegroundColor White
Write-Host "   → Console tab for WebSocket errors" -ForegroundColor Cyan
Write-Host "   → Network tab → WS filter → Look for /push connection" -ForegroundColor Cyan
Write-Host ""

