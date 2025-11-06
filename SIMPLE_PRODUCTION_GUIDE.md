# Simple Production Guide - n8n with MSSQL

## 🤔 **How Does This All Work?**

Think of it in 3 layers:

```
┌─────────────────────────────────────┐
│  1. Your n8n Source Code            │  ← 9 files modified for MSSQL
│     (packages/)                     │
├─────────────────────────────────────┤
│  2. TypeORM Library (dependencies)  │  ← 5 query builder files modified
│     (node_modules/@n8n/typeorm/)    │
├─────────────────────────────────────┤
│  3. MSSQL Database                  │  ← Setup scripts
│     (SQL Server)                    │
└─────────────────────────────────────┘
```

---

## 📦 **Understanding the Pieces**

### **Layer 1: n8n Source Code (Your Changes)**

**9 TypeScript files** you modified in `packages/`:
- Database configuration
- Date functions
- Pagination helpers
- etc.

**How it works:**
- You edit `.ts` files
- TypeScript compiles to `.js` files in `dist/`
- n8n runs the compiled `.js` files

✅ **Easy:** Just commit these to Git!

---

### **Layer 2: TypeORM Library (The Tricky Part)**

**5 JavaScript files** in `node_modules/@n8n/typeorm/query-builder/`:
- SelectQueryBuilder.js
- QueryBuilder.js  
- UpdateQueryBuilder.js
- InsertQueryBuilder.js
- DeleteQueryBuilder.js

**The Problem:**
- These are in `node_modules/` (dependencies folder)
- `node_modules/` is **deleted** every time you run `pnpm install`!
- Your fixes disappear! 😱

**The Solution - Two Options:**

#### **Option A: Patch Files (n8n's Way)**
```
patches/@n8n__typeorm.patch
```
- This file contains "diffs" (changes) to TypeORM
- When you run `pnpm install`, pnpm automatically applies patches
- ❌ Problem: Our changes aren't in this patch yet (it's complex to add)

#### **Option B: Backup/Restore Scripts (Our Way)**  
```
BACKUP_TYPEORM_FIXES.ps1    ← Backup modified files
RESTORE_TYPEORM_FIXES.ps1   ← Restore after pnpm install
```
- Simpler approach
- Works immediately
- ✅ Already set up for you!

---

## 🚀 **Simple Production Strategy**

### **Step 1: Create Your Fork**

```bash
# On GitHub, fork: https://github.com/n8n-io/n8n
# This creates: https://github.com/YOUR-ORG/n8n-mssql

# Clone YOUR fork
git clone https://github.com/YOUR-ORG/n8n-mssql.git
cd n8n-mssql

# Create MSSQL branch
git checkout -b mssql-support
```

---

### **Step 2: Copy All Changes**

Copy from `C:\Git\n8n\` to your fork:

```powershell
# Copy modified source files (9 files)
Copy-Item "C:\Git\n8n\packages\@n8n\db\src\connection\db-connection-options.ts" ".\packages\@n8n\db\src\connection\"
Copy-Item "C:\Git\n8n\packages\@n8n\db\src\repositories\workflow-statistics.repository.ts" ".\packages\@n8n\db\src\repositories\"
Copy-Item "C:\Git\n8n\packages\cli\src\modules\chat-hub\chat-message.repository.ts" ".\packages\cli\src\modules\chat-hub\"
Copy-Item "C:\Git\n8n\packages\cli\src\modules\data-table\data-table.repository.ts" ".\packages\cli\src\modules\data-table\"
Copy-Item "C:\Git\n8n\packages\cli\src\modules\data-table\data-table-rows.repository.ts" ".\packages\cli\src\modules\data-table\"
Copy-Item "C:\Git\n8n\packages\cli\src\services\import.service.ts" ".\packages\cli\src\services\"
Copy-Item "C:\Git\n8n\packages\cli\src\services\export.service.ts" ".\packages\cli\src\services\"
Copy-Item "C:\Git\n8n\packages\cli\src\modules\insights\database\repositories\insights-by-period-query.helper.ts" ".\packages\cli\src\modules\insights\database\repositories\"
Copy-Item "C:\Git\n8n\packages\cli\src\modules\insights\database\repositories\insights-by-period.repository.ts" ".\packages\cli\src\modules\insights\database\repositories\"

# Copy scripts & documentation
Copy-Item "C:\Git\n8n\START_N8N_MSSQL.ps1" ".\"
Copy-Item "C:\Git\n8n\BACKUP_TYPEORM_FIXES.ps1" ".\"
Copy-Item "C:\Git\n8n\RESTORE_TYPEORM_FIXES.ps1" ".\"
Copy-Item "C:\Git\n8n\MSSQL_PREREQUISITE_SETUP.sql" ".\"

# Copy essential docs
Copy-Item "C:\Git\n8n\START_HERE.md" ".\"
Copy-Item "C:\Git\n8n\README_PRODUCTION_MSSQL.md" ".\"
Copy-Item "C:\Git\n8n\PRODUCTION_DEPLOYMENT_GUIDE.md" ".\"
Copy-Item "C:\Git\n8n\COMPLETE_CHANGES_SUMMARY.md" ".\"
Copy-Item "C:\Git\n8n\MSSQL_SETUP_INSTRUCTIONS.md" ".\"
Copy-Item "C:\Git\n8n\HOW_TO_UPDATE_PATCH_FILE.md" ".\"
```

---

### **Step 3: Commit Everything**

```bash
git add .
git commit -m "Add MSSQL support to n8n 1.119.0

- Modified 9 n8n source files for MSSQL compatibility
- Added backup/restore scripts for TypeORM fixes
- Included database setup scripts
- Complete documentation

Changes:
- LIMIT → OFFSET/FETCH
- RETURNING → OUTPUT  
- NOW() → GETDATE()
- strftime → DATEADD/DATEDIFF
- GROUP BY alias fix
- CTE ORDER BY handling
- And more...

See COMPLETE_CHANGES_SUMMARY.md for details"

git push origin mssql-support
```

---

### **Step 4: Tag the Release**

```bash
git tag v1.119.0-mssql-1
git push origin v1.119.0-mssql-1
```

---

## 🎯 **How to Use This Fork**

### **For Development Team:**

```bash
git clone https://github.com/YOUR-ORG/n8n-mssql.git
cd n8n-mssql
git checkout mssql-support

# Install dependencies
pnpm install

# ⚠️ IMPORTANT: Restore TypeORM fixes after install!
.\RESTORE_TYPEORM_FIXES.ps1

# Build
pnpm run build

# Start
.\START_N8N_MSSQL.ps1
```

---

### **For Production:**

**Option A: Pre-Built Package (Recommended)**

```bash
# On build server:
git clone https://github.com/YOUR-ORG/n8n-mssql.git
pnpm install
.\RESTORE_TYPEORM_FIXES.ps1
pnpm build

# Create production package (includes node_modules with fixes!)
tar -czf n8n-mssql-production.tar.gz .

# On production server:
tar -xzf n8n-mssql-production.tar.gz
.\START_N8N_MSSQL.ps1
```

**Option B: Build on Production**

```bash
# Same as development, but on production server
git clone https://github.com/YOUR-ORG/n8n-mssql.git
pnpm install
.\RESTORE_TYPEORM_FIXES.ps1
pnpm build
.\START_N8N_MSSQL.ps1
```

---

## 💡 **Simple Explanation**

### **What are "patches"?**

Think of patches like **stickers on a book**:
- Original book = Official n8n/TypeORM
- Stickers = Your MSSQL changes
- When someone photocopies the book, stickers are lost
- You need to reapply the stickers!

### **What does `RESTORE_TYPEORM_FIXES.ps1` do?**

```
1. Backup has your modified TypeORM files
   ↓
2. pnpm install replaces them with originals
   ↓
3. RESTORE script copies your versions back
   ↓
4. TypeORM now has MSSQL support again! ✅
```

---

## 📋 **Your Workflow**

### **Daily Development:**
```powershell
# Edit code
# TypeScript auto-compiles
# Restart n8n: rs
```

### **After `pnpm install`:**
```powershell
pnpm install
.\RESTORE_TYPEORM_FIXES.ps1  # ← Don't forget this!
```

### **Before Deployment:**
```powershell
.\BACKUP_TYPEORM_FIXES.ps1   # Make sure backup is current
```

---

## 🎯 **Repository Structure (Your Fork)**

```
your-org/n8n-mssql (GitHub)
├── mssql-support branch
│   ├── packages/                    ← 9 modified .ts files ✅ IN GIT
│   ├── BACKUP_TYPEORM_FIXES.ps1     ← Backup script ✅ IN GIT
│   ├── RESTORE_TYPEORM_FIXES.ps1    ← Restore script ✅ IN GIT
│   ├── START_N8N_MSSQL.ps1          ← Startup script ✅ IN GIT
│   ├── MSSQL_PREREQUISITE_SETUP.sql ← DB setup ✅ IN GIT
│   └── *.md documentation           ← Guides ✅ IN GIT
│
└── NOT in Git:
    ├── node_modules/                ← Created by pnpm install
    │   └── @n8n/typeorm/            ← Modified by RESTORE script
    └── C:\n8n-typeorm-mssql-fixes-backup\  ← Local backup
```

---

## ✅ **What Gets Committed to Git**

**DO commit:**
- ✅ All `.ts` files in `packages/`
- ✅ `*.ps1` scripts
- ✅ `*.sql` scripts  
- ✅ `*.md` documentation

**DON'T commit:**
- ❌ `node_modules/` (too large, auto-generated)
- ❌ `dist/` (compiled files, auto-generated)
- ❌ Log files

---

## 🚀 **Quick Commands**

```powershell
# Fresh start
git clone <your-fork>
pnpm install
.\RESTORE_TYPEORM_FIXES.ps1
pnpm build
.\START_N8N_MSSQL.ps1

# After code changes
# (TypeScript auto-compiles)
# Just restart: rs

# After pnpm install
.\RESTORE_TYPEORM_FIXES.ps1

# Before production deploy
.\BACKUP_TYPEORM_FIXES.ps1
```

---

## 📝 **Summary**

### **What You Need to Understand:**

1. **Source code changes** (9 files) → **Git commits them** ✅
2. **TypeORM changes** (5 files in node_modules) → **Backup/restore scripts** ✅
3. **Database setup** → **SQL scripts** ✅

### **For Production:**

**Easiest way:** Build once, package everything (including `node_modules`), deploy the package!

Then `node_modules` already has the fixes, no restore needed! 🎉

---

**Does this make sense? Any questions?** 🤔

