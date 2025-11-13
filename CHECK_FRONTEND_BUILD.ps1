# ==================================================
# Check Frontend Build Status
# ==================================================
# Verifies if frontend was actually rebuilt
# ==================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Frontend Build Verification" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$frontendDist = "C:\Git\n8n-mssql\packages\frontend\editor-ui\dist"

# Check if dist folder exists
if (!(Test-Path $frontendDist)) {
    Write-Host "❌ Frontend dist folder does NOT exist!" -ForegroundColor Red
    Write-Host "   Path: $frontendDist" -ForegroundColor Yellow
    Write-Host "`nYou need to BUILD the frontend first!" -ForegroundColor Yellow
    Write-Host "   cd C:\Git\n8n-mssql\packages\frontend\editor-ui" -ForegroundColor White
    Write-Host '   $env:VUE_APP_URL_BASE_API = "/n8nnet/"' -ForegroundColor White
    Write-Host "   pnpm build" -ForegroundColor White
    exit 1
}

Write-Host "✓ Frontend dist folder exists" -ForegroundColor Green

# Check file timestamps
Write-Host "`nChecking file ages..." -ForegroundColor Yellow

$jsFiles = Get-ChildItem -Path "$frontendDist\assets" -Filter "*.js" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 5

if ($jsFiles.Count -eq 0) {
    Write-Host "❌ No JavaScript files found in dist!" -ForegroundColor Red
    Write-Host "   Frontend was not built properly" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nNewest JavaScript files:" -ForegroundColor Cyan
foreach ($file in $jsFiles) {
    $age = (Get-Date) - $file.LastWriteTime
    $ageMinutes = [math]::Round($age.TotalMinutes, 1)
    
    $color = "White"
    $status = ""
    
    if ($ageMinutes -lt 5) {
        $color = "Green"
        $status = "✓ NEW"
    } elseif ($ageMinutes -lt 60) {
        $color = "Yellow"
        $status = "⚠ Recent"
    } else {
        $color = "Red"
        $status = "❌ OLD"
    }
    
    Write-Host "  $status $($file.Name)" -ForegroundColor $color
    Write-Host "      Last modified: $($file.LastWriteTime) ($ageMinutes minutes ago)" -ForegroundColor Gray
}

# Check for specific problematic files
Write-Host "`nLooking for telemetry file..." -ForegroundColor Yellow
$telemetryFile = Get-ChildItem -Path "$frontendDist\assets" -Filter "useTelemetry-*.js" -File

if ($telemetryFile) {
    Write-Host "  Found: $($telemetryFile.Name)" -ForegroundColor White
    $age = (Get-Date) - $telemetryFile.LastWriteTime
    $ageMinutes = [math]::Round($age.TotalMinutes, 1)
    
    if ($ageMinutes -lt 5) {
        Write-Host "  ✓ File is NEW ($ageMinutes minutes old)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ File is OLD ($ageMinutes minutes old)" -ForegroundColor Red
        Write-Host "     Frontend rebuild did NOT work properly!" -ForegroundColor Red
    }
}

# Check if index.html was updated
$indexHtml = "$frontendDist\index.html"
if (Test-Path $indexHtml) {
    $indexAge = (Get-Date) - (Get-Item $indexHtml).LastWriteTime
    $indexMinutes = [math]::Round($indexAge.TotalMinutes, 1)
    
    Write-Host "`nindex.html last modified: $indexMinutes minutes ago" -ForegroundColor White
    
    if ($indexMinutes -lt 5) {
        Write-Host "  ✓ index.html is fresh" -ForegroundColor Green
    } else {
        Write-Host "  ❌ index.html is old - rebuild did not work" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Diagnosis" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$oldestFile = $jsFiles | Sort-Object LastWriteTime | Select-Object -First 1
$newestFile = $jsFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$oldestAge = [math]::Round(((Get-Date) - $oldestFile.LastWriteTime).TotalMinutes, 1)
$newestAge = [math]::Round(((Get-Date) - $newestFile.LastWriteTime).TotalMinutes, 1)

if ($newestAge -lt 5) {
    Write-Host "✓ Frontend was rebuilt recently (newest file: $newestAge min ago)" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. Restart n8n to serve new files" -ForegroundColor White
    Write-Host "2. Clear browser cache completely (Ctrl+Shift+Delete)" -ForegroundColor White
    Write-Host "3. Hard refresh (Ctrl+F5)" -ForegroundColor White
} elseif ($newestAge -lt 60) {
    Write-Host "⚠ Frontend was rebuilt $newestAge minutes ago" -ForegroundColor Yellow
    Write-Host "  If you just rebuilt, something went wrong" -ForegroundColor Yellow
} else {
    Write-Host "❌ Frontend is OLD! Last build: $newestAge minutes ago" -ForegroundColor Red
    Write-Host "`nThe frontend was NOT rebuilt!" -ForegroundColor Red
    Write-Host "`nTo rebuild:" -ForegroundColor Yellow
    Write-Host "1. cd C:\Git\n8n-mssql\packages\frontend\editor-ui" -ForegroundColor White
    Write-Host '2. $env:VUE_APP_URL_BASE_API = "/n8nnet/"' -ForegroundColor White
    Write-Host '3. $env:VUE_APP_PUBLIC_PATH = "/n8nnet/"' -ForegroundColor White
    Write-Host '4. $env:VITE_MULTI_TENANT_ENABLED = "true"' -ForegroundColor White
    Write-Host "5. pnpm build" -ForegroundColor White
    Write-Host "6. Wait for completion (will take 1-2 minutes)" -ForegroundColor White
}

Write-Host ""

