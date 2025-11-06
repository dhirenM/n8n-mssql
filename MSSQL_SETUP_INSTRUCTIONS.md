# n8n MSSQL - Complete Setup Instructions

## 📋 **Prerequisites (One-Time Setup)**

### 1. **Create Database Schema**
Run the base schema creation script (if not already done):
```sql
-- Run: n8n_schema_idempotent.sql
```

### 2. **Run Prerequisite Setup Script**
```powershell
sqlcmd -S 10.242.218.73 -U qa -P bestqateam -d dmnen_test -i "C:\Git\n8n\MSSQL_PREREQUISITE_SETUP.sql"
```

**This script creates:**
- ✅ Global roles (owner, admin, member)
- ✅ Shell owner user (placeholder)
- ✅ Personal project for owner
- ✅ Required settings

---

## 🚀 **Start n8n**

```powershell
cd C:\Git\n8n
.\START_N8N_MSSQL.ps1
```

---

## 🌐 **Complete Owner Setup**

### **Option 1: Browser (Recommended)**
1. Open: **http://localhost:5678**
2. Fill in the setup form:
   - Email: `dhiren.mistry@yardi.com`
   - First Name: `Dhiren`
   - Last Name: `Mistry`
   - Password: `Yardi123!`
3. Click "Get Started"

### **Option 2: API**
```bash
curl 'http://localhost:5678/rest/owner/setup' \
  -H 'Content-Type: application/json' \
  --data-raw '{"email":"dhiren.mistry@yardi.com","firstName":"Dhiren","lastName":"Mistry","password":"Yardi123!"}'
```

---

## ✅ **What's Working**

| Feature | Status |
|---------|--------|
| MSSQL Connection | ✅ Working |
| TypeORM Queries | ✅ Working |
| OFFSET/FETCH Syntax | ✅ Fixed |
| ORDER BY Auto-Injection | ✅ Fixed |
| Migrations | ✅ **NOW ENABLED** |
| Shell Owner User | ✅ Created |
| Owner Setup | ✅ Ready |

---

## 🔄 **How Migrations Work Now**

**✅ Migrations are NOW ENABLED!**

Changes made:
```typescript
// db-connection-options.ts
migrationsRun: true,  // Migrations will run on startup
migrations: mssqlMigrations, // Uses migrations from mssqldb/index.ts
```

**What this means:**
- ✅ When n8n starts, it checks for pending migrations
- ✅ New migrations will run automatically
- ✅ You won't need to manually run SQL scripts for future updates
- ✅ The `migrations` table tracks which migrations have run

---

## 📝 **Files Modified**

### Core MSSQL Support:
1. ✅ `packages/@n8n/db/src/connection/db-connection-options.ts` - Enabled migrations
2. ✅ `packages/cli/src/modules/chat-hub/chat-message.repository.ts` - Fixed TypeScript error
3. ✅ `node_modules/@n8n/typeorm/query-builder/SelectQueryBuilder.js` - MSSQL OFFSET/FETCH fix

### SQL Scripts Created:
1. ✅ `MSSQL_PREREQUISITE_SETUP.sql` - One-time setup (roles, shell user, settings)
2. ✅ `create_shell_owner_user.sql` - Shell owner user creation (included in prerequisite script)

---

## ⚠️ **Important Notes**

### **Prerequisite Script Should Run:**
- ✅ **Before first n8n startup**
- ✅ **After running n8n_schema_idempotent.sql**
- ✅ **Only once** (script is idempotent - safe to run multiple times)

### **What Migrations Do:**
- Skip if already run (tracked in `migrations` table)
- Run in order by timestamp
- Add new tables/columns for new n8n features
- Modify existing schema as needed

---

## 🎯 **Quick Start Checklist**

- [x] Base schema created (`n8n_schema_idempotent.sql`)
- [x] Prerequisite setup run (`MSSQL_PREREQUISITE_SETUP.sql`)
- [x] Migrations enabled in code
- [x] Shell owner user exists
- [ ] **Start n8n**: `.\START_N8N_MSSQL.ps1`
- [ ] **Complete setup**: http://localhost:5678

---

## 🔍 **Verify Setup**

Check everything is ready:

```sql
-- Verify roles
SELECT * FROM dbo.[role] WHERE slug IN ('global:owner', 'global:admin', 'global:member');

-- Verify shell owner user
SELECT * FROM dbo.[user] WHERE roleSlug = 'global:owner';

-- Verify settings
SELECT * FROM dbo.settings WHERE [key] LIKE 'userManagement%';

-- Verify migrations table
SELECT * FROM dbo.migrations ORDER BY timestamp DESC;
```

Expected results:
- 3 roles
- 1 shell owner user (with NULL email/password)
- 2+ settings
- Multiple migrations (if migrations have run)

---

**After completing owner setup, you'll be able to use n8n normally!** 🎉

