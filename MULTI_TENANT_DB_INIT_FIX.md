# 🔧 Multi-Tenant Database Initialization Fix

## Problem

n8n tries to initialize a default DataSource on startup (line 114-119 in base-command.ts), but in multi-tenant mode:
- No default Voyager DB credentials are set
- It defaults to localhost:1433 which doesn't exist
- Causes: "Failed to connect to localhost:1433"

## Solutions

### **Option 1: Use Default Subdomain's Voyager DB** (Recommended)

Set n8n's default DB configuration to point to the default subdomain's Voyager DB.

**Add to START_N8N_MSSQL.ps1:**

```powershell
# ============================================================
# Default Voyager Database (for n8n's default DataSource)
# This is used for CLI commands, migrations, and non-request contexts
# Point this to your default/primary Voyager database
# ============================================================
$env:DB_MSSQLDB_HOST = "10.242.218.73"       # Your Voyager DB server
$env:DB_MSSQLDB_PORT = "1433"
$env:DB_MSSQLDB_DATABASE = "dmnen_test"      # Your default Voyager DB
$env:DB_MSSQLDB_USER = "qa"
$env:DB_MSSQLDB_PASSWORD = "bestqateam"
$env:DB_MSSQLDB_SCHEMA = "n8n"
```

This gives n8n a "home" database for:
- CLI commands (e.g., `n8n user-management:reset`)
- Database migrations
- Background jobs not tied to a request

**Pros:**
- ✅ n8n starts successfully
- ✅ CLI commands work
- ✅ Has a default DB for non-HTTP contexts

**Cons:**
- ⚠️ Default DB is for ONE specific client
- ⚠️ CLI commands affect that client's data

---

### **Option 2: Skip Default DB in Multi-Tenant Mode**

Modify base-command.ts to skip default DB initialization when multi-tenant is enabled.

**Modify packages/cli/src/commands/base-command.ts:**

```typescript
// Around line 100-119

// Multi-Tenant: Initialize Elevate DataSource
if (process.env.ENABLE_MULTI_TENANT === 'true') {
    try {
        const { initializeElevateDataSource } = await import('@/databases/elevate.datasource');
        await initializeElevateDataSource();
        this.logger.info('✅ Elevate DataSource initialized for multi-tenant support');
        
        // Skip default DB initialization in multi-tenant mode
        this.logger.warn('⚠️  Multi-tenant mode: Skipping default DataSource initialization');
        this.logger.warn('   Each request will use its own Voyager DataSource');
        
        // Continue without initializing default DB
        // Set a dummy connection state to satisfy n8n's checks
        this.dbConnection.connectionState.connected = true;
        this.dbConnection.connectionState.migrated = true;
        
    } catch (error) {
        this.logger.error('❌ Failed to initialize Elevate DataSource', { error });
        throw error;
    }
} else {
    // Single-tenant mode: Initialize default DB normally
    await this.dbConnection
        .init()
        .catch(
            async (error: Error) =>
                await this.exitWithCrash('There was an error initializing DB', error),
        );
}
```

**Pros:**
- ✅ No default DB needed
- ✅ True multi-tenant (no "primary" client)

**Cons:**
- ⚠️ CLI commands won't work without request context
- ⚠️ Migrations need special handling

---

### **Option 3: Use Elevate DB as Default** (Hybrid)

Use Elevate DB as n8n's default DataSource (for CLI/migrations), but use Voyager DBs for HTTP requests.

**Already partially done!** You could:
- Keep Elevate DB connection
- Use it for CLI/migrations only
- HTTP requests use Voyager DBs

---

## 🎯 Recommended: Option 1

**Quick fix - Add default Voyager DB config:**

**Update START_N8N_MSSQL.ps1:**

```powershell
# Add these lines BEFORE the "Voyager Database Defaults" section:

# ============================================================
# Default Voyager Database (for CLI and migrations)
# ============================================================
$env:DB_MSSQLDB_HOST = "10.242.218.73"       # From your test
$env:DB_MSSQLDB_PORT = "1433"
$env:DB_MSSQLDB_DATABASE = "dmnen_test"      # Your test Voyager DB
$env:DB_MSSQLDB_USER = "qa"
$env:DB_MSSQLDB_PASSWORD = "bestqateam"
$env:DB_MSSQLDB_SCHEMA = "n8n"
```

This will:
1. ✅ Let n8n start successfully
2. ✅ HTTP requests still use dynamic Voyager DBs per subdomain
3. ✅ CLI commands work
4. ✅ Migrations run on the default DB

**Should I add this configuration to START_N8N_MSSQL.ps1?** 🚀

