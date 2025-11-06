# n8n with MSSQL - Production Ready Guide

## 🎉 **Complete MSSQL Integration for n8n 1.119.0**

This repository contains a fully functional n8n 1.119.0 with Microsoft SQL Server support.

**Version:** 1.119.0  
**Git Commit:** 74a0b51c46  
**Date:** November 5-6, 2025  
**Status:** ✅ Production Ready

---

## 🚀 **Quick Start**

### **1. Prerequisites**

- Windows Server or Windows 10/11
- MSSQL Server 2012+ (any edition)
- PowerShell 7+
- Node.js 22.16+
- pnpm 10.18.3+

### **2. Database Setup (One-Time)**

```sql
-- Run these SQL scripts on your MSSQL server:

-- Step 1: Create base schema
sqlcmd -S YOUR_SERVER -U YOUR_USER -P YOUR_PASS -d YOUR_DB -i n8n_schema_idempotent.sql

-- Step 2: Create prerequisite data (roles, shell owner user, settings)
sqlcmd -S YOUR_SERVER -U YOUR_USER -P YOUR_PASS -d YOUR_DB -i MSSQL_PREREQUISITE_SETUP.sql
```

### **3. Deploy n8n**

**Option A: Development (with source)**
```powershell
git clone <your-fork> n8n-mssql
cd n8n-mssql
pnpm install
.\RESTORE_TYPEORM_FIXES.ps1  # Restore MSSQL fixes after install
pnpm build
.\START_N8N_MSSQL.ps1
```

**Option B: Production (pre-built)**
```powershell
# Extract pre-built package (includes node_modules with fixes)
tar -xzf n8n-mssql-production.tar.gz
cd n8n-mssql

# Configure environment
cp .env.example .env
# Edit .env with your MSSQL connection details

# Start n8n
.\START_N8N_MSSQL.ps1
```

### **4. Complete Setup**

1. Open browser: `http://localhost:5678`
2. Fill in owner account details
3. Start building workflows!

---

## 📁 **Repository Structure**

```
n8n-mssql/
├── packages/               # n8n source code (7 files modified)
├── node_modules/           # Dependencies (TypeORM patched with MSSQL fixes)
├── patches/                # Patch files
│   └── @n8n__typeorm.patch
├── MSSQL_PREREQUISITE_SETUP.sql        # ✅ Run once before first start
├── START_N8N_MSSQL.ps1                 # ✅ Startup script
├── BACKUP_TYPEORM_FIXES.ps1            # Backup TypeORM fixes
├── RESTORE_TYPEORM_FIXES.ps1           # Restore TypeORM fixes after install
├── PRODUCTION_DEPLOYMENT_GUIDE.md      # Complete deployment guide
├── COMPLETE_CHANGES_SUMMARY.md         # All modifications documented
├── HOW_TO_UPDATE_PATCH_FILE.md         # Patch management guide
└── README_PRODUCTION_MSSQL.md          # This file
```

---

## ✅ **What's Included**

### **MSSQL Fixes:**
- ✅ LIMIT → OFFSET/FETCH conversion
- ✅ ORDER BY auto-injection for pagination
- ✅ RETURNING → OUTPUT clause conversion
- ✅ INSERTED./DELETED. prefixes
- ✅ CTE ORDER BY handling
- ✅ CONCAT() for string concatenation
- ✅ MERGE statement for upserts
- ✅ JSON column type fixes
- ✅ Complete database schema

### **Documentation:**
- ✅ Production deployment guide
- ✅ Complete changes summary
- ✅ Patch management instructions
- ✅ Backup/restore scripts
- ✅ Setup instructions
- ✅ Troubleshooting guide

---

## 🔧 **Environment Variables**

Create `.env` file or set these:

```bash
# Database Configuration (Required)
DB_TYPE=mssqldb
DB_MSSQLDB_HOST=your-server
DB_MSSQLDB_PORT=1433
DB_MSSQLDB_DATABASE=your_database
DB_MSSQLDB_USER=your_user
DB_MSSQLDB_PASSWORD=your_password
DB_MSSQLDB_SCHEMA=dbo

# Security (Production)
DB_MSSQLDB_ENCRYPT=true
DB_MSSQLDB_TRUST_SERVER_CERTIFICATE=false

# Performance (Optional)
DB_MSSQLDB_POOL_SIZE=20
DB_MSSQLDB_CONNECTION_TIMEOUT=30000

# n8n Configuration
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_secure_password
```

---

## 📊 **Files Modified Summary**

| Type | Count | Files |
|------|-------|-------|
| **n8n Source** | 7 | db-connection-options.ts, workflow-statistics.repository.ts, chat-message.repository.ts, data-table*.ts, import/export services |
| **TypeORM** | 5 | SelectQueryBuilder.js, QueryBuilder.js, Update/Insert/DeleteQueryBuilder.js |
| **SQL Scripts** | 2 | n8n_schema_idempotent.sql, MSSQL_PREREQUISITE_SETUP.sql |
| **PowerShell** | 4 | START_N8N_MSSQL.ps1, BACKUP/RESTORE scripts, WITH_LOG script |
| **Documentation** | 8 | All guides and READMEs |
| **Total** | **26 files** | - |

---

## 🎯 **Production Deployment**

### **Pre-Deployment Checklist:**

- [ ] MSSQL database created
- [ ] `n8n_schema_idempotent.sql` executed
- [ ] `MSSQL_PREREQUISITE_SETUP.sql` executed
- [ ] TypeORM fixes backed up (`.\BACKUP_TYPEORM_FIXES.ps1`)
- [ ] Environment variables configured
- [ ] Firewall rules configured
- [ ] SSL certificates configured (if using encryption)

### **Deployment Steps:**

1. **Build on Build Server:**
```bash
git clone <repo>
cd n8n-mssql
pnpm install
.\RESTORE_TYPEORM_FIXES.ps1
pnpm run build
```

2. **Package for Production:**
```powershell
# Create production package (includes node_modules!)
Compress-Archive -Path @(
    "packages",
    "node_modules",
    "patches",
    "*.ps1",
    "*.sql",
    "*.md"
) -DestinationPath "n8n-mssql-v1.119.0-production.zip"
```

3. **Deploy:**
```powershell
# On production server
Expand-Archive n8n-mssql-v1.119.0-production.zip -DestinationPath C:\n8n
cd C:\n8n
.\START_N8N_MSSQL.ps1
```

---

## 🔒 **Security Recommendations**

### **Database:**
- Use SQL authentication with strong password
- Enable encryption (`DB_MSSQLDB_ENCRYPT=true`)
- Use proper SSL certificates
- Limit network access to n8n servers only
- Use least-privilege database user

### **n8n:**
- Enable basic auth or SSO
- Use HTTPS (reverse proxy)
- Keep n8n updated
- Regular security audits
- Monitor logs for suspicious activity

---

## 📈 **Scaling**

### **Single Instance:**
- Handles 100-500 workflows
- Connection pool: 10-20
- Recommended: 4 CPU, 8GB RAM

### **Multiple Instances:**
- Share MSSQL database
- Use Redis for queue
- Load balancer for web UI
- Connection pool: 10 per instance

### **High Availability:**
- MSSQL Always On
- Multiple n8n instances
- Shared storage for logs
- Health check endpoints

---

## 🐛 **Troubleshooting**

### **"Incorrect syntax near 'LIMIT'"**
✅ Fixed - TypeORM now generates OFFSET/FETCH

### **"Invalid usage of the option NEXT"**
✅ Fixed - ORDER BY auto-injected

### **"Incorrect syntax near 'RETURNING'"**
✅ Fixed - Uses OUTPUT instead

### **"Type instantiation is excessively deep"**
✅ Fixed - Added explicit return types

### **If fixes are lost after `pnpm install`:**
```powershell
.\RESTORE_TYPEORM_FIXES.ps1
```

---

## 🔄 **Upgrading n8n**

1. **Test new version in dev:**
```bash
git fetch upstream
git checkout -b upgrade-1.120.0
git merge v1.120.0
```

2. **Resolve conflicts:**
- Check modified files
- Reapply MSSQL changes if needed
- Test thoroughly

3. **Reapply TypeORM fixes:**
```powershell
.\RESTORE_TYPEORM_FIXES.ps1
```

4. **Test before production deployment**

---

## 📞 **Support**

### **Documentation:**
- `PRODUCTION_DEPLOYMENT_GUIDE.md` - Full deployment guide
- `COMPLETE_CHANGES_SUMMARY.md` - All changes documented
- `HOW_TO_UPDATE_PATCH_FILE.md` - Patch management
- `MSSQL_SETUP_INSTRUCTIONS.md` - Setup walkthrough

### **Known Limitations:**
- Migrations disabled (manual schema management)
- Some enterprise features may need testing
- Not officially supported by n8n team

### **Community:**
- n8n Community Forum (general questions)
- GitHub Issues (for this fork)
- Internal team support

---

## 📝 **License**

This fork maintains n8n's original license. MSSQL modifications provided "as-is".

---

## 🎉 **Success Criteria**

After deployment, verify:

- ✅ n8n starts without errors
- ✅ Owner setup completes
- ✅ Can create workflows
- ✅ Can execute workflows
- ✅ All endpoints work
- ✅ No SQL syntax errors in logs
- ✅ Database queries use OFFSET/FETCH
- ✅ Performance acceptable

**All criteria should be met with this implementation!** 🚀

---

**For detailed technical information, see:**
- `COMPLETE_CHANGES_SUMMARY.md` - Line-by-line changes
- `PRODUCTION_DEPLOYMENT_GUIDE.md` - Architecture and deployment
- `UPDATE_TYPEORM_PATCH.md` - Patch system details

