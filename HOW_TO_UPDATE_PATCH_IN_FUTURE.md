# How to Update the @n8n/typeorm Patch in the Future

## Scenario: You Need to Fix MSSQL/ORM Syntax Errors

If you encounter MSSQL-related errors and need to update the TypeORM patch, here's how to do it:

---

## ✅ **Option 1: Proper pnpm Patch Workflow (Recommended)**

### **You DON'T need backup files!** Just use pnpm's built-in workflow:

### Step 1: Start a Patch Session

```powershell
cd C:\Git\n8n-mssql
pnpm patch @n8n/typeorm
```

**Output:**
```
Patch: You can now edit the package at:
  C:\Git\n8n-mssql\node_modules\.pnpm_patches\@n8n\typeorm@0.3.20-15

To commit your changes, run:
  pnpm patch-commit "C:\Git\n8n-mssql\node_modules\.pnpm_patches\@n8n\typeorm@0.3.20-15"
```

### Step 2: Make Your Changes

Edit files in the temp directory. For example, if you need to fix a query builder issue:

```powershell
# Open the file you need to fix
code "C:\Git\n8n-mssql\node_modules\.pnpm_patches\@n8n\typeorm@0.3.20-15\query-builder\SelectQueryBuilder.js"

# Make your changes
# Save the file
```

### Step 3: Commit the Patch

```powershell
pnpm patch-commit "C:\Git\n8n-mssql\node_modules\.pnpm_patches\@n8n\typeorm@0.3.20-15"
```

**This will:**
- ✅ Update `patches/@n8n__typeorm.patch` with your new changes
- ✅ Update `pnpm-lock.yaml` with new patch hash
- ✅ Apply the patch to your actual `node_modules/`
- ✅ Auto-install the updated patch

### Step 4: Test and Commit

```powershell
# Test n8n
.\START_N8N_MSSQL.ps1

# If everything works, commit to Git
git add patches/@n8n__typeorm.patch
git add pnpm-lock.yaml
git commit -m "Fix: Update MSSQL query builder for <specific issue>"
```

---

## 🔄 **Option 2: Using Backup Files (If You Have Them)**

If you already have working fixes in `C:\n8n-typeorm-mssql-fixes-backup\`, you can use those:

### Step 1: Start Patch Session

```powershell
pnpm patch @n8n/typeorm
```

### Step 2: Copy Fixed Files

```powershell
# Copy your working fixes to the patch temp directory
$patchDir = "C:\Git\n8n-mssql\node_modules\.pnpm_patches\@n8n\typeorm@0.3.20-15"
$backupDir = "C:\n8n-typeorm-mssql-fixes-backup"

Copy-Item "$backupDir\*.js" "$patchDir\query-builder\" -Force
```

### Step 3: Commit the Patch

```powershell
pnpm patch-commit "C:\Git\n8n-mssql\node_modules\.pnpm_patches\@n8n\typeorm@0.3.20-15"
```

---

## 🎯 **Common Scenarios**

### Scenario 1: Fix a Query Syntax Error

**Example:** n8n crashes with "Invalid SQL syntax for MSSQL"

```powershell
# 1. Start patch
pnpm patch @n8n/typeorm

# 2. Edit the problematic file
code "C:\Git\n8n-mssql\node_modules\.pnpm_patches\@n8n\typeorm@0.3.20-15\query-builder\SelectQueryBuilder.js"

# Find the problematic line and fix it
# Example: Change invalid LIMIT syntax to OFFSET/FETCH

# 3. Save and commit
pnpm patch-commit "C:\Git\n8n-mssql\node_modules\.pnpm_patches\@n8n\typeorm@0.3.20-15"

# 4. Test
.\START_N8N_MSSQL.ps1
```

### Scenario 2: Add New MSSQL Features

**Example:** You want to add support for a new MSSQL data type

```powershell
# 1. Start patch
pnpm patch @n8n/typeorm

# 2. Edit SQL Server driver
code "C:\Git\n8n-mssql\node_modules\.pnpm_patches\@n8n\typeorm@0.3.20-15\driver\sqlserver\SqlServerDriver.ts"

# Add new data type support
# Save

# 3. Commit patch
pnpm patch-commit "..."

# 4. Test and commit to Git
```

### Scenario 3: Upgrade n8n Version

When you upgrade n8n to a newer version:

```powershell
# 1. Upgrade n8n
pnpm upgrade n8n

# 2. Install (patch auto-applies)
pnpm install

# 3. If patch fails to apply:
#    - Start new patch session
#    - Manually reapply your MSSQL fixes
#    - Commit new patch

# 4. Test thoroughly
.\START_N8N_MSSQL.ps1
```

---

## 📋 **What You DON'T Need**

### **Backup Files Are Optional**

The external backup directory `C:\n8n-typeorm-mssql-fixes-backup\` is:
- ✅ A **convenience backup** for you
- ❌ NOT required for the patch system
- ❌ NOT needed by other developers

**Why?** Because everything is already in `patches/@n8n__typeorm.patch`!

### **You Can Delete the Backup If You Want**

Since the patch file contains everything:

```powershell
# Optional: Remove external backup
Remove-Item -Recurse "C:\n8n-typeorm-mssql-fixes-backup"

# The patch file has everything you need!
```

---

## 🛠️ **Quick Reference Commands**

### **Create/Update Patch**
```powershell
# 1. Start
pnpm patch @n8n/typeorm

# 2. Edit files in temp directory
# (path shown in pnpm output)

# 3. Commit
pnpm patch-commit "<temp-directory-path>"
```

### **View Current Patch**
```powershell
# See what's in the current patch
code patches\@n8n__typeorm.patch
```

### **Test Patch**
```powershell
# Remove and reinstall to test patch
Remove-Item -Recurse node_modules
pnpm install

# Start n8n
.\START_N8N_MSSQL.ps1
```

---

## 💡 **Key Points**

1. **Backup files are optional** - Everything is in the patch file
2. **Use pnpm patch workflow** - It's the proper way
3. **Always test after updating** - Make sure n8n still works
4. **Commit the patch file** - That's what matters
5. **Don't commit node_modules** - Ever! ❌

---

## 📝 **Summary**

**Question:** Do I need backup files to create new patches?

**Answer:** **NO!** You can either:

1. ✅ **Use pnpm patch workflow** (edit directly in temp directory)
2. ✅ **Use backup files** if you have them (convenience)

**The patch file (`patches/@n8n__typeorm.patch`) is self-contained!**

All your MSSQL fixes are stored in that single 837 KB file. That's all you need! 🎉


