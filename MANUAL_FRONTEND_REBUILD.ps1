# ==================================================
# Manual Frontend Rebuild with Verification
# ==================================================
# Step-by-step frontend rebuild with checks
# ==================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Manual Frontend Rebuild" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$frontendPath = "C:\Git\n8n-mssql\packages\frontend\editor-ui"
$distPath = "$frontendPath\dist"

# STEP 1: Clean old build
Write-Host "STEP 1: Cleaning old build..." -ForegroundColor Yellow
if (Test-Path $distPath) {
    Write-Host "  Removing old dist folder..." -ForegroundColor White
    Remove-Item $distPath -Recurse -Force
    Write-Host "  ✓ Old build removed" -ForegroundColor Green
} else {
    Write-Host "  No old dist folder found" -ForegroundColor Gray
}

# Clear vite cache
Remove-Item "$frontendPath\node_modules\.vite" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$frontendPath\.vite" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  ✓ Vite cache cleared`n" -ForegroundColor Green

# STEP 2: Set environment variables
Write-Host "STEP 2: Setting environment variables..." -ForegroundColor Yellow
$env:VUE_APP_URL_BASE_API = "/n8nnet/"
$env:VUE_APP_PUBLIC_PATH = "/n8nnet/"
$env:VITE_MULTI_TENANT_ENABLED = "true"
$env:IS_VIRTUOSO_AI = "true"
$env:ELEVATE_MODE = "true"
$env:NODE_ENV = "production"

Write-Host "  VUE_APP_URL_BASE_API = $env:VUE_APP_URL_BASE_API" -ForegroundColor White
Write-Host "  VUE_APP_PUBLIC_PATH = $env:VUE_APP_PUBLIC_PATH" -ForegroundColor White
Write-Host "  VITE_MULTI_TENANT_ENABLED = $env:VITE_MULTI_TENANT_ENABLED" -ForegroundColor White
Write-Host "  ✓ Environment variables set`n" -ForegroundColor Green

# STEP 3: Navigate to frontend
Write-Host "STEP 3: Navigating to frontend directory..." -ForegroundColor Yellow
cd $frontendPath
Write-Host "  Current directory: $(Get-Location)" -ForegroundColor White
Write-Host "  ✓ In frontend directory`n" -ForegroundColor Green

# STEP 4: Build
Write-Host "STEP 4: Building frontend..." -ForegroundColor Yellow
Write-Host "  This will take 1-2 minutes..." -ForegroundColor Gray
Write-Host ""

# Delete old dist
Remove-Item dist -Recurse -Force -ErrorAction SilentlyContinue

$buildStart = Get-Date
pnpm build
$buildEnd = Get-Date
$buildDuration = ($buildEnd - $buildStart).TotalSeconds

Write-Host ""

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ BUILD FAILED!" -ForegroundColor Red
    Write-Host "   Exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "`nCheck the error messages above" -ForegroundColor Yellow
    exit 1
}

Write-Host "  ✓ Build completed in $([math]::Round($buildDuration, 1)) seconds`n" -ForegroundColor Green

# STEP 5: Verify output
Write-Host "STEP 5: Verifying build output..." -ForegroundColor Yellow

if (!(Test-Path $distPath)) {
    Write-Host "  ❌ dist folder was NOT created!" -ForegroundColor Red
    Write-Host "     Build failed silently" -ForegroundColor Red
    exit 1
}

$assetsPath = "$distPath\assets"
if (!(Test-Path $assetsPath)) {
    Write-Host "  ❌ assets folder was NOT created!" -ForegroundColor Red
    exit 1
}

$jsFiles = Get-ChildItem -Path $assetsPath -Filter "*.js" -File
$cssFiles = Get-ChildItem -Path $assetsPath -Filter "*.css" -File

Write-Host "  ✓ dist folder exists" -ForegroundColor Green
Write-Host "  ✓ Found $($jsFiles.Count) JavaScript files" -ForegroundColor Green
Write-Host "  ✓ Found $($cssFiles.Count) CSS files" -ForegroundColor Green

# Check if files are actually new
$newestFile = $jsFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$fileAge = (Get-Date) - $newestFile.LastWriteTime
$fileAgeSeconds = [math]::Round($fileAge.TotalSeconds, 1)

if ($fileAgeSeconds -lt 10) {
    Write-Host "  ✓ Files are BRAND NEW ($fileAgeSeconds seconds old)" -ForegroundColor Green
} else {
    Write-Host "  ❌ Files are NOT new! ($fileAgeSeconds seconds old)" -ForegroundColor Red
    Write-Host "     Something went wrong with the build!" -ForegroundColor Red
}

# List some sample files
Write-Host "`nSample files created:" -ForegroundColor Cyan
$jsFiles | Select-Object -First 3 | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor White
}

# STEP 6: Check index.html
Write-Host "`nSTEP 6: Checking index.html..." -ForegroundColor Yellow
$indexPath = "$distPath\index.html"
if (Test-Path $indexPath) {
    $content = Get-Content $indexPath -Raw
    if ($content -match "/n8nnet/") {
        Write-Host "  ✓ index.html contains /n8nnet/ base path" -ForegroundColor Green
    } else {
        Write-Host "  ❌ index.html does NOT contain /n8nnet/ base path!" -ForegroundColor Red
        Write-Host "     Environment variables were not applied!" -ForegroundColor Red
    }
} else {
    Write-Host "  ❌ index.html not found!" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✅ FRONTEND BUILD VERIFICATION COMPLETE" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Build duration: $([math]::Round($buildDuration, 1)) seconds" -ForegroundColor White
Write-Host "  JavaScript files: $($jsFiles.Count)" -ForegroundColor White
Write-Host "  CSS files: $($cssFiles.Count)" -ForegroundColor White
Write-Host "  Newest file age: $fileAgeSeconds seconds" -ForegroundColor White
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: .\START_N8N_MSSQL.ps1" -ForegroundColor White
Write-Host "2. Clear browser cache (Ctrl+Shift+Delete → Clear ALL)" -ForegroundColor White
Write-Host "3. Close and reopen browser" -ForegroundColor White
Write-Host "4. Access: http://cmqacore.elevatelocal.com:5000/n8nnet/" -ForegroundColor White
Write-Host ""
Write-Host "To verify files changed in browser:" -ForegroundColor Yellow
Write-Host "  F12 → Network tab → Look for useTelemetry-[hash].js" -ForegroundColor White
Write-Host "  The [hash] should be DIFFERENT from BN91iK9b" -ForegroundColor White
Write-Host ""

