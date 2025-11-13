# n8n Configuration Guide

## 📁 **File Structure**

### **Configuration File**
- **`N8N_SETTINGS_FOR_JWT_AUTH.ps1`** - All environment variable settings
  - Database connections
  - JWT authentication settings
  - Multi-tenant configuration
  - Security settings
  - Logging options

### **Startup Script**
- **`START_N8N_MSSQL.ps1`** - Starts n8n with configuration
  - Imports `N8N_SETTINGS_FOR_JWT_AUTH.ps1`
  - Displays configuration summary
  - Starts n8n backend

---

## 🚀 **How to Use**

### **To Start n8n:**
```powershell
.\START_N8N_MSSQL.ps1
```

That's it! The script automatically:
1. ✅ Imports all settings from `N8N_SETTINGS_FOR_JWT_AUTH.ps1`
2. ✅ Displays configuration summary
3. ✅ Starts n8n

---

## ⚙️ **To Modify Settings:**

**Edit:** `N8N_SETTINGS_FOR_JWT_AUTH.ps1`

Common settings to change:

### **1. Database Connection:**
```powershell
$env:DB_MSSQLDB_HOST = "your-server"
$env:DB_MSSQLDB_DATABASE = "your-database"
$env:DB_MSSQLDB_USER = "your-username"
$env:DB_MSSQLDB_PASSWORD = "your-password"
```

### **2. JWT Authentication:**
```powershell
$env:DOTNET_AUDIENCE_SECRET = "your-secret"
$env:DOTNET_ISSUER = "your-issuer"
$env:DOTNET_AUDIENCE_ID = "your-audience-id"
```

### **3. User Permissions:**
```powershell
# Full access (current):
$env:JWT_USER_DEFAULT_ROLE = "global:admin"
$env:JWT_USER_PROJECT_ROLE = "project:admin"

# Or limited access:
$env:JWT_USER_DEFAULT_ROLE = "global:member"
$env:JWT_USER_PROJECT_ROLE = "project:editor"
```

### **4. Security:**
```powershell
# Development (HTTP):
$env:N8N_SECURE_COOKIE = "false"

# Production (HTTPS):
$env:N8N_SECURE_COOKIE = "true"
```

### **5. Push Connection:**
```powershell
# Use SSE (simpler, works now):
$env:N8N_PUSH_BACKEND = "sse"

# Or WebSocket (better, needs frontend rebuild):
$env:N8N_PUSH_BACKEND = "websocket"
```

---

## 📋 **All Configuration Files**

| File | Purpose | When to Edit |
|------|---------|--------------|
| `N8N_SETTINGS_FOR_JWT_AUTH.ps1` | Environment variables | Change settings here |
| `START_N8N_MSSQL.ps1` | Startup script | Rarely (just runs n8n) |
| `MISSING_SCHEMA_FIX.sql` | Database roles/scopes | Once per tenant DB |
| `ELEVATE_MODE_PREREQUISITES.sql` | Default "n8nnet" project | Once per tenant DB |
| `CLEANUP_TEST_DATA.sql` | Clean test data | As needed for testing |

---

## 🔧 **Advanced Configuration**

### **Enable Debug Logging:**
In `N8N_SETTINGS_FOR_JWT_AUTH.ps1`:
```powershell
$env:N8N_LOG_LEVEL = "debug"
$env:TYPEORM_LOGGING = "true"
```

### **Disable Debug Logging:**
```powershell
$env:N8N_LOG_LEVEL = "info"
$env:TYPEORM_LOGGING = "false"
```

### **Skip JWT Validation (Debugging):**
```powershell
# Uncomment in settings file:
$env:SKIP_JWT_ISSUER_AUDIENCE_CHECK = "true"
```

---

## 📊 **Configuration Profiles**

### **Development Profile** (Current)
```powershell
N8N_SECURE_COOKIE = "false"       # HTTP allowed
N8N_LOG_LEVEL = "debug"           # Verbose logging
TYPEORM_LOGGING = "true"          # SQL query logging
N8N_PUSH_BACKEND = "sse"          # Simpler push
```

### **Production Profile** (Future)
```powershell
N8N_SECURE_COOKIE = "true"        # HTTPS required
N8N_LOG_LEVEL = "info"            # Less verbose
TYPEORM_LOGGING = "false"         # No SQL logging
N8N_PUSH_BACKEND = "websocket"    # Better performance
```

To switch profiles: Edit values in `N8N_SETTINGS_FOR_JWT_AUTH.ps1`

---

## ✅ **Benefits of This Structure**

| Benefit | Description |
|---------|-------------|
| **Centralized** | All settings in one file |
| **Reusable** | Import in other scripts if needed |
| **Version Control** | Easy to track changes |
| **Documentation** | Settings file is self-documenting |
| **Maintainable** | Clear separation of config vs execution |

---

## 🎯 **Quick Reference**

```powershell
# Start n8n
.\START_N8N_MSSQL.ps1

# Edit configuration
code N8N_SETTINGS_FOR_JWT_AUTH.ps1

# Setup new tenant database
sqlcmd -S Server -d Database -i ELEVATE_MODE_PREREQUISITES.sql

# Clean test data
sqlcmd -S Server -d Database -i CLEANUP_TEST_DATA.sql

# Rebuild after code changes
.\QUICK_REBUILD_DB.ps1  # Just DB repos
# OR
.\MANUAL_FRONTEND_REBUILD.ps1  # Just frontend
```

---

## 📝 **Deployment Checklist**

For new tenant database:

1. ✅ Run `MISSING_SCHEMA_FIX.sql` (creates roles/scopes/FK)
2. ✅ Run `ELEVATE_MODE_PREREQUISITES.sql` (creates "n8nnet" project)
3. ✅ Edit `N8N_SETTINGS_FOR_JWT_AUTH.ps1` (set JWT secrets)
4. ✅ Run `START_N8N_MSSQL.ps1`
5. ✅ Test JWT authentication
6. ✅ Verify users auto-register

---

**All configuration is now in `N8N_SETTINGS_FOR_JWT_AUTH.ps1`!** 🎉

To change any setting, just edit that file and restart n8n.

