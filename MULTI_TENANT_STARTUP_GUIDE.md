# 🚀 Multi-Tenant n8n - Startup Guide

## ✅ Final Configuration

### **How It Works:**

```
n8n Startup:
    ↓
Check: IS_ELEVATE=true OR ENABLE_MULTI_TENANT=true?
    ↓ YES
Initialize ONLY Elevate DB
    ↓
Mock connection state (connected + migrated)
    ↓
Skip default Voyager DB initialization
    ↓
Skip migrations (run separately per Voyager DB)
    ↓
n8n ready! ✅

HTTP Request arrives:
    ↓
Subdomain validation middleware
    ↓
Query Elevate DB:
  SELECT db_server, db_name, db_user, db_password
  FROM company WHERE domain = '<subdomain>'
    ↓
Create/Get Voyager DataSource for that subdomain
    ↓
Store in req.dataSource
    ↓
Process request with client-specific database ✅
```

---

## 📋 Environment Variables

**Only Elevate DB credentials are needed in .env:**

```bash
# Elevate Database (Central - Required)
ELEVATE_DB_HOST=10.242.1.65\SQL2K19
ELEVATE_DB_PORT=1433
ELEVATE_DB_NAME=elevate_multitenant_mssql_dev
ELEVATE_DB_USER=elevate_multitenant_mssql_dev
ELEVATE_DB_PASSWORD=q9Q68cKQdBFIzC

# Multi-Tenant Settings
ENABLE_MULTI_TENANT=true
IS_ELEVATE=true  # Optional, ENABLE_MULTI_TENANT is enough

# Voyager DB credentials come from Elevate DB dynamically!
# No need to set DB_MSSQLDB_HOST, DB_MSSQLDB_DATABASE, etc.
```

---

## 🎯 What Happens on Startup

### **With ENABLE_MULTI_TENANT=true:**

```
[Node] Initializing Elevate DataSource...
[Node] ✅ Elevate DataSource initialized successfully
[Node]    Server: 10.242.1.65\SQL2K19
[Node]    Database: elevate_multitenant_mssql_dev
[Node] ⚠️  Multi-tenant mode: Skipping default Voyager DB initialization
[Node]    Each HTTP request will use its own Voyager DataSource
[Node] ⚠️  Multi-tenant mode: Skipping default database migrations
[Node]    Migrations should be run separately for each Voyager database
[Node] ✅ Multi-tenant DataSource proxy installed
[Node] ✅ Multi-tenant middleware registered
[Node] n8n ready on ::, port 5678
```

**No "Failed to connect" errors!** ✅

---

## 🧪 Testing

### **Test 1: Startup**

```powershell
.\START_N8N_MSSQL.ps1

# Should see:
# ✅ Elevate DataSource initialized
# ✅ Multi-tenant mode messages
# ✅ n8n ready on port 5678
# ❌ NO "Failed to connect to localhost:1433"
```

### **Test 2: HTTP Request**

```powershell
# Access with localhost (uses DEFAULT_SUBDOMAIN)
curl http://localhost:5678/n8nnet/

# Logs should show:
# Subdomain validation for host: localhost
# Using default subdomain: pmgroup
# Querying Elevate DB for subdomain: pmgroup
# Creating Voyager DataSource for subdomain: pmgroup
# ✅ Voyager DataSource initialized for: pmgroup → <db_name>
```

### **Test 3: With Real Subdomain**

```powershell
# If you have DNS configured:
curl http://client1.yourdomain.com:5678/n8nnet/

# Logs should show:
# Extracted subdomain: client1
# Querying Elevate DB for subdomain: client1
# Creating Voyager DataSource for subdomain: client1
# ✅ Voyager DataSource initialized for: client1 → client1_voyager
```

---

## 🗄️ Database Setup Per Client

### **For Each New Client:**

1. **Create entry in Elevate DB:**

```sql
USE elevate_multitenant_mssql_dev;

INSERT INTO company (domain, db_server, db_name, db_user, db_password, inactive, issql)
VALUES (
  'newclient',              -- Subdomain
  'server.domain.com',      -- Voyager DB server
  'newclient_voyager',      -- Voyager DB name
  'voyager_user',           -- DB user
  'password',               -- DB password
  0,                        -- Active
  1                         -- Is SQL
);
```

2. **Create Voyager Database:**

```sql
CREATE DATABASE newclient_voyager;
GO

USE newclient_voyager;
GO

-- Create n8n schema
CREATE SCHEMA [n8n] AUTHORIZATION dbo;
GO

-- Run n8n migrations (manually)
-- Or let n8n create tables on first use
```

3. **Access n8n:**

```
http://newclient.yourdomain.com/n8nnet/
```

That's it! n8n automatically connects to `newclient_voyager.n8n.*` 🎉

---

## 🔧 Migrations Handling

### **Option 1: Manual Migrations**

Run migrations separately for each Voyager DB:

```powershell
# For each client database:
$env:DB_MSSQLDB_HOST = "server.domain.com"
$env:DB_MSSQLDB_DATABASE = "client1_voyager"
$env:DB_MSSQLDB_USER = "user"
$env:DB_MSSQLDB_PASSWORD = "password"
$env:DB_MSSQLDB_SCHEMA = "n8n"
$env:ENABLE_MULTI_TENANT = "false"  # Disable for migrations

# Run migrations
pnpm start -- db:migrate
```

### **Option 2: Let n8n Auto-Create Tables**

If `synchronize: true` is enabled (not recommended for production), n8n will create tables automatically on first access.

### **Option 3: Migration Script**

Create a script to run migrations on all Voyager DBs:

```sql
-- Get all companies
SELECT domain, db_server, db_name, db_user, db_password
FROM elevate_multitenant_mssql_dev.dbo.company
WHERE inactive = 0;

-- For each result, run n8n migrations
```

---

## 📝 Summary

### **Initialization Flow:**

**Multi-Tenant Mode (ENABLE_MULTI_TENANT=true):**
1. ✅ Initialize Elevate DB (queries company table)
2. ❌ Skip default Voyager DB (no credentials needed!)
3. ✅ Mock connection state
4. ✅ Install DataSource proxy
5. ✅ Register middleware
6. ✅ n8n ready!

**Per-Request Flow:**
1. HTTP request arrives
2. Extract subdomain
3. Query Elevate DB for Voyager credentials
4. Create Voyager DataSource
5. Use for that request only

**No default Voyager DB needed at startup!** 🎉

---

## 🚀 Ready to Test!

```powershell
# Rebuild
cd packages\cli
pnpm build

# Start n8n
cd ..\..
.\START_N8N_MSSQL.ps1
```

**Should start without errors now!** ✅

