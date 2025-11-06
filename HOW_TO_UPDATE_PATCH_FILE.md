# How to Update the TypeORM Patch File for Production

## 🎯 **Understanding n8n's Patch System**

n8n uses **pnpm's built-in patch system**, not patch-package!

**Configuration:** `package.json`
```json
"patchedDependencies": {
    "@n8n/typeorm": "patches/@n8n__typeorm.patch"
}
```

---

## 📝 **Current Situation**

### **Files Modified (in node_modules):**
1. `SelectQueryBuilder.js` - 6 MSSQL fixes
2. `QueryBuilder.js` - 2 MSSQL fixes
3. `UpdateQueryBuilder.js` - 1 MSSQL fix
4. `InsertQueryBuilder.js` - 1 MSSQL fix
5. `DeleteQueryBuilder.js` - 1 MSSQL fix

### **Current Patch:**
- **File:** `patches/@n8n__typeorm.patch`
- **Size:** 10,902 lines
- **Status:** ⚠️ Contains only SQL Server driver, NOT our new fixes

---

## ⚠️ **Why Patch Update Doesn't Work Normally**

```bash
pnpm patch-commit <path>  
# ❌ ERROR: Not a valid patch directory
```

**Reason:** We manually edited files in `node_modules`. pnpm's patch system expects you to use `pnpm patch` workflow.

---

## 🔧 **Option 1: Manual Patch File Update (Quick Fix)**

Since we already modified the files, manually append our changes to the existing patch:

### **Step 1: Create a Diff of Our Changes**

```powershell
# This is complex - pnpm patches use a specific format
# For now, the fixes are in node_modules and will work
# BUT they will be lost on `pnpm install`!
```

### **Step 2: Document What Needs to be Reapplied**

Keep this document + all the modified files backed up:
- All TypeORM query builder `.js` files with our changes
- Document showing line numbers and exact changes

---

## 🚀 **Option 2: Proper pnpm Patch Workflow (Recommended for Next Time)**

**For future changes**, use this workflow:

### **Step 1: Start a Patch**
```bash
pnpm patch @n8n/typeorm
# This creates a temp directory and prints the path
# Example output: /tmp/abc123/@n8n/typeorm
```

### **Step 2: Make Your Changes**
```bash
# Edit files in the temp directory
code /tmp/abc123/@n8n/typeorm/query-builder/SelectQueryBuilder.js
# Make your MSSQL fixes
```

### **Step 3: Commit the Patch**
```bash
pnpm patch-commit /tmp/abc123/@n8n/typeorm
# This updates patches/@n8n__typeorm.patch automatically
```

---

## 📦 **Option 3: Keep Modified node_modules (Current Approach)**

### **What We're Doing Now:**

✅ **Modified files directly in node_modules**  
✅ **Files work when n8n runs**  
⚠️ **Files are LOST on `pnpm install`!**

### **To Preserve for Production:**

**Create a backup script:**

```powershell
# BACKUP_TYPEORM_FIXES.ps1

$backupDir = "C:\n8n-typeorm-fixes-backup"
$nodeModulesPath = "C:\Git\n8n\node_modules\.pnpm\@n8n+typeorm@0.3.20-15_patc_b1474cc396604d67f6ce1db21e4fd8aa\node_modules\@n8n\typeorm\query-builder"

New-Item -ItemType Directory -Force -Path $backupDir

# Backup all modified query builders
Copy-Item "$nodeModulesPath\SelectQueryBuilder.js" "$backupDir\SelectQueryBuilder.js"
Copy-Item "$nodeModulesPath\QueryBuilder.js" "$backupDir\QueryBuilder.js"  
Copy-Item "$nodeModulesPath\UpdateQueryBuilder.js" "$backupDir\UpdateQueryBuilder.js"
Copy-Item "$nodeModulesPath\InsertQueryBuilder.js" "$backupDir\InsertQueryBuilder.js"
Copy-Item "$nodeModulesPath\DeleteQueryBuilder.js" "$backupDir\DeleteQueryBuilder.js"

Write-Host "✅ TypeORM fixes backed up to: $backupDir"
```

**Restore script:**

```powershell
# RESTORE_TYPEORM_FIXES.ps1

$backupDir = "C:\n8n-typeorm-fixes-backup"
$nodeModulesPath = "C:\Git\n8n\node_modules\.pnpm\@n8n+typeorm@0.3.20-15_patc_b1474cc396604d67f6ce1db21e4fd8aa\node_modules\@n8n\typeorm\query-builder"

# After pnpm install, restore fixes
Copy-Item "$backupDir\SelectQueryBuilder.js" "$nodeModulesPath\SelectQueryBuilder.js"
Copy-Item "$backupDir\QueryBuilder.js" "$nodeModulesPath\QueryBuilder.js"
Copy-Item "$backupDir\UpdateQueryBuilder.js" "$nodeModulesPath\UpdateQueryBuilder.js"
Copy-Item "$backupDir\InsertQueryBuilder.js" "$nodeModulesPath\InsertQueryBuilder.js"
Copy-Item "$backupDir\DeleteQueryBuilder.js" "$nodeModulesPath\DeleteQueryBuilder.js"

Write-Host "✅ TypeORM fixes restored"
```

---

## 🎯 **Recommended Production Strategy**

### **Best Approach: Don't Run `pnpm install` in Production**

Instead:

1. **Build on Dev/Build Server:**
```bash
# Development environment
git clone <repo>
cd n8n-mssql
pnpm install  # Applies official patches
# Manually reapply our MSSQL fixes (or use restore script)
pnpm build
```

2. **Package for Production:**
```bash
# Create deployment package (node_modules included!)
tar -czf n8n-mssql-production.tar.gz \
    packages/ \
    node_modules/ \
    patches/ \
    START_N8N_MSSQL.ps1 \
    MSSQL_PREREQUISITE_SETUP.sql
```

3. **Deploy to Production:**
```bash
# Extract on production server
tar -xzf n8n-mssql-production.tar.gz

# node_modules already has all fixes!
# No pnpm install needed

# Just start n8n
.\START_N8N_MSSQL.ps1
```

---

## ✅ **Production Deployment Checklist**

- [ ] Build n8n on dev machine with all MSSQL fixes
- [ ] Test thoroughly in dev/staging
- [ ] Backup modified TypeORM query builder files
- [ ] Package entire `node_modules` directory
- [ ] Deploy package to production (don't run pnpm install)
- [ ] Run MSSQL prerequisite setup script
- [ ] Start n8n and verify

---

## 🔄 **For Future n8n Upgrades**

When upgrading to newer n8n version:

1. **On new n8n version:**
```bash
git checkout -b upgrade-to-1.120.0
git merge v1.120.0
```

2. **Reapply MSSQL fixes:**
```bash
# Option A: Use restore script
.\RESTORE_TYPEORM_FIXES.ps1

# Option B: Manually reapply each fix
# (Reference COMPLETE_CHANGES_SUMMARY.md for exact changes)
```

3. **Test thoroughly**

4. **Package for production**

---

## 📌 **Critical Files to Keep**

**Never lose these:**

```
C:\n8n-typeorm-fixes-backup\
├── SelectQueryBuilder.js    ✅ All 6 MSSQL fixes
├── QueryBuilder.js           ✅ CTE + RETURNING fixes
├── UpdateQueryBuilder.js     ✅ OUTPUT fix
├── InsertQueryBuilder.js     ✅ OUTPUT fix
└── DeleteQueryBuilder.js     ✅ OUTPUT fix
```

**Backup now:**
```powershell
# Run the backup script
.\BACKUP_TYPEORM_FIXES.ps1

# Or compress manually
Compress-Archive -Path "C:\n8n-typeorm-fixes-backup" -DestinationPath "C:\n8n-mssql-fixes-$(Get-Date -Format 'yyyy-MM-dd').zip"
```

---

## 🎓 **Learning: Why This is Complex**

1. **n8n uses custom TypeORM fork** (@n8n/typeorm)
2. **Our MSSQL fixes are runtime patches** (in node_modules)
3. **pnpm patch system expects proper workflow** (patch → edit → commit)
4. **We edited directly** (faster but harder to maintain)

**For Production:** Package `node_modules` with fixes already applied! ✅

---

**Next Steps:** Test current fixes, then create backup/restore scripts for production deployment.

