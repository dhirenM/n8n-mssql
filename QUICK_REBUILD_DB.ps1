# ==================================================
# Quick Rebuild - DB Repositories Only
# ==================================================
# Use this when you only changed repository files
# Much faster than full rebuild
# ==================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Quick Rebuild - DB Repositories" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Rebuilding @n8n/db package (repositories)..." -ForegroundColor Yellow
cd C:\Git\n8n-mssql\packages\@n8n\db
pnpm build

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ DB package rebuilt successfully!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Build Complete - Repository Changes Applied" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Start n8n: .\START_N8N_MSSQL.ps1" -ForegroundColor White
Write-Host "2. Test workflows endpoint" -ForegroundColor White
Write-Host "3. Check SQL logs in console for generated queries`n" -ForegroundColor White

