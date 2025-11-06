# ============================================================================
# Cleanup Documentation - Remove Debug/Temporary Files
# ============================================================================

Write-Host "Cleaning up debug/temporary documentation files..." -ForegroundColor Cyan
Write-Host ""

# Files to DELETE (debugging/temporary)
$filesToDelete = @(
    "MSSQL_CURRENT_STATUS_AND_NEXT_STEPS.md",
    "MSSQL_INTEGRATION_COMPLETE_SUMMARY.md",
    "AFTER_BUILD_INSTRUCTIONS.md",
    "MSSQL_LIMIT_FIX_APPLIED.md",
    "MSSQL_ORDER_BY_FIX.md",
    "IMPORTANT_MSSQL_NOTE.md",
    "README_MSSQL.md",
    "create_shell_owner_user.sql"
)

foreach ($file in $filesToDelete) {
    $path = "C:\Git\n8n\$file"
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "  ✅ Deleted: $file" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "✅ Cleanup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Kept essential files:" -ForegroundColor Yellow
Write-Host "  - START_HERE.md (master index)" -ForegroundColor White
Write-Host "  - README_PRODUCTION_MSSQL.md (main guide)" -ForegroundColor White
Write-Host "  - PRODUCTION_DEPLOYMENT_GUIDE.md (deployment)" -ForegroundColor White
Write-Host "  - COMPLETE_CHANGES_SUMMARY.md (technical reference)" -ForegroundColor White
Write-Host "  - HOW_TO_UPDATE_PATCH_FILE.md (patch system)" -ForegroundColor White
Write-Host "  - MSSQL_SETUP_INSTRUCTIONS.md (setup guide)" -ForegroundColor White
Write-Host "  - MSSQL_PREREQUISITE_SETUP.sql (database setup)" -ForegroundColor White
Write-Host "  - BACKUP/RESTORE scripts (maintenance)" -ForegroundColor White
Write-Host ""

