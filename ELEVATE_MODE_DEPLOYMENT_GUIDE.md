# n8n Elevate Mode - Deployment Guide

## Overview
This guide explains how to deploy n8n in Elevate Mode with JWT authentication and multi-tenant MSSQL support.

## Architecture
- **Elevate DB**: Central multi-tenant database with tenant connection strings
- **Voyager DB**: Per-tenant databases (one per customer/subdomain)
- **JWT Auth**: Users authenticate via .NET Core API, auto-register in n8n
- **Default Project**: All JWT users join a shared "n8nnet" team project

---

## Prerequisites

### 1. Elevate Database Setup
The central Elevate database should already have:
- `dbo.TenantConnections` table with connection strings for each subdomain

### 2. Required Files
- `ELEVATE_MODE_PREREQUISITES.sql` - Run once per tenant database
- `START_N8N_MSSQL.ps1` - Startup script with environment variables
- JWT middleware - Already integrated in n8n CLI

---

## Deployment Steps

### Step 1: Start n8n FIRST (Auto-creates Roles)

⚠️ **IMPORTANT**: n8n auto-creates all system roles at startup!

```powershell
# Start n8n once to let it create roles
.\START_N8N_MSSQL.ps1
```

Wait for n8n to start up. It will automatically create:
- ✅ All system roles (global:member, project:editor, etc.)
- ✅ All permission scopes
- ✅ Role-scope mappings

You'll see messages like:
```
Database type: mssqldb
n8n ready on http://localhost:5678
```

### Step 2: Create Default Project (Per Tenant)

For **each customer/tenant database**, run the prerequisite script:

```sql
-- Connect to the tenant's Voyager database
USE [CustomerVoyagerDB];
GO

-- Run the prerequisite script
-- (Update database name in the script first)
-- File: ELEVATE_MODE_PREREQUISITES.sql
```

This script creates:
- ✅ Default "n8nnet" team project
- ✅ Verification checks (confirms roles exist)

**You only need to run this ONCE per tenant database.**

### Step 3: Configure JWT Settings

Update your environment variables in `START_N8N_MSSQL.ps1`:

```powershell
# .NET Core JWT Authentication Settings
$env:DOTNET_AUDIENCE_ID = "your-audience-id"
$env:DOTNET_AUDIENCE_SECRET = "your-secret-key"
$env:DOTNET_ISSUER = "your-issuer"
$env:USE_DOTNET_JWT = "true"
$env:IS_VIRTUOSO_AI = "false"  # or "true" if using VirtuosoAI

# Default project name (optional, defaults to "n8nnet")
$env:N8N_DEFAULT_PROJECT_NAME = "n8nnet"
```

**These must match your .NET Core API JWT configuration exactly!**

### Step 4: Configure Elevate Database

```powershell
# Elevate Database (Multi-Tenant Central DB)
$env:ELEVATE_DB_HOST = "your-sql-server"
$env:ELEVATE_DB_PORT = "1433"
$env:ELEVATE_DB_NAME = "elevate_multitenant_db"
$env:ELEVATE_DB_USER = "username"
$env:ELEVATE_DB_PASSWORD = "password"
```

### Step 5: Enable Multi-Tenant Mode

```powershell
$env:ENABLE_MULTI_TENANT = "true"
$env:DEFAULT_SUBDOMAIN = "default"  # Fallback subdomain
```

### Step 6: Restart n8n with JWT Enabled

```powershell
.\START_N8N_MSSQL.ps1
```

---

## How It Works

### User Authentication Flow

1. **User authenticates** via your .NET Core API
2. **.NET API issues JWT** with user claims (sub, email, name, etc.)
3. **User accesses n8n** with JWT in cookie or Authorization header
4. **n8n validates JWT** using configured secret
5. **n8n looks up user** by email in tenant database
6. **If user doesn't exist:**
   - Generate UUID for user
   - Create user with `global:member` role
   - Find existing "n8nnet" project
   - Link user to "n8nnet" project as `project:editor`
7. **User is authenticated** and can use n8n

### Database Schema

**User Table** (`n8n.user`):
```sql
id          UNIQUEIDENTIFIER  -- Auto-generated UUID
email       NVARCHAR(255)     -- From JWT email claim
firstName   NVARCHAR(100)     -- From JWT given_name
lastName    NVARCHAR(100)     -- From JWT family_name
roleSlug    VARCHAR(50)       -- "global:member"
password    NVARCHAR(MAX)     -- NULL (JWT auth only)
```

**Project Table** (`n8n.project`):
```sql
id          UNIQUEIDENTIFIER  -- Created by prerequisite script
name        NVARCHAR(255)     -- "n8nnet"
type        VARCHAR(36)       -- "team"
```

**ProjectRelation Table** (`n8n.project_relation`):
```sql
userId      UNIQUEIDENTIFIER  -- FK to user.id
projectId   UNIQUEIDENTIFIER  -- FK to project.id (n8nnet)
role        VARCHAR(50)       -- "project:editor"
```

---

## Configuration Options

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DOTNET_AUDIENCE_ID` | JWT audience claim | - | Yes |
| `DOTNET_AUDIENCE_SECRET` | JWT signing secret | - | Yes |
| `DOTNET_ISSUER` | JWT issuer claim | - | Yes |
| `USE_DOTNET_JWT` | Enable JWT auth | `false` | Yes |
| `IS_VIRTUOSO_AI` | VirtuosoAI mode | `false` | No |
| `N8N_DEFAULT_PROJECT_NAME` | Default project name | `n8nnet` | No |
| `N8N_LOG_LEVEL` | Log verbosity | `info` | No |
| `SKIP_JWT_ISSUER_AUDIENCE_CHECK` | Debug mode | `false` | No |

### JWT Secret Formats

The middleware automatically tries multiple secret encoding formats:
1. Primary (Flowise-style) - Raw for VirtuosoAI, decoded otherwise
2. Raw AUDIENCE_SECRET (string)
3. Base64url decoded (Buffer)
4. UTF-8 Buffer
5. Direct base64url decode

This ensures compatibility with various .NET JWT implementations.

---

## Verification

### After Running Prerequisites Script

Check the logs for:
```
✓ Created default project: n8nnet
• Project ID: [UUID]
✓ All prerequisites verified successfully!
• Roles created: 8
• Default project exists: Yes
```

### After Starting n8n

Check the logs for:
```
[INFO] .NET JWT: ✅ Successfully verified with secret format: [name]
[INFO] .NET JWT: User not found, creating minimal records (Option C)
[INFO] ✅ Step 1: Get global:member role
[INFO] ✅ Step 2: Created user record { userId: '...', email: '...', role: 'global:member' }
[INFO] ✅ Step 3: Found default project { projectId: '...', projectName: 'n8nnet' }
[INFO] ✅ Step 4: Created project relation { userId: '...', projectId: '...', role: 'project:editor' }
[INFO] ✅ Successfully created minimal n8n user from JWT
```

### Verify in Database

```sql
-- Check roles
SELECT * FROM n8n.role;

-- Check default project
SELECT * FROM n8n.project WHERE name = 'n8nnet';

-- Check users (after first JWT login)
SELECT u.id, u.email, u.firstName, u.lastName, u.roleSlug
FROM n8n.[user] u;

-- Check project relations
SELECT pr.userId, pr.projectId, pr.role, p.name AS projectName
FROM n8n.project_relation pr
JOIN n8n.project p ON pr.projectId = p.id;
```

---

## Troubleshooting

### "Default project not found" Error

**Cause**: ELEVATE_MODE_PREREQUISITES.sql was not run on the tenant database.

**Solution**: Connect to the tenant database and run the prerequisite script.

### "Invalid signature" Error

**Cause**: JWT secret mismatch between .NET API and n8n.

**Solution**: 
1. Check `DOTNET_AUDIENCE_SECRET` matches .NET API configuration
2. Enable debug logging: `$env:N8N_LOG_LEVEL = "debug"`
3. Check which secret format succeeds in the logs

### "Cannot insert NULL into roleSlug" Error

**Cause**: Prerequisite script didn't create the roles.

**Solution**: Re-run ELEVATE_MODE_PREREQUISITES.sql.

### Users can't see workflows

**Cause**: Project relation not created correctly.

**Solution**: Check `project_relation` table for the user's entry.

---

## Maintenance

### Adding a New Tenant

1. Create new Voyager database for the tenant
2. Run n8n schema migrations (or copy schema from existing tenant)
3. **Start n8n once** to let it auto-create roles (it will connect to the first DB)
4. Run `ELEVATE_MODE_PREREQUISITES.sql` on the new database (creates "n8nnet" project)
5. Add tenant connection string to Elevate DB `TenantConnections` table
6. Users can now authenticate via JWT and auto-register

### Changing Default Project Name

1. Update environment variable:
   ```powershell
   $env:N8N_DEFAULT_PROJECT_NAME = "your-project-name"
   ```
2. Update the prerequisite script to create a project with that name
3. Re-run the script on all tenant databases

### Upgrading n8n

1. Stop n8n
2. Update n8n packages: `pnpm install`
3. Run new migrations if needed
4. Restart n8n with `START_N8N_MSSQL.ps1`

The JWT middleware and default project logic will remain intact.

---

## Security Notes

1. **JWT Secrets**: Keep `DOTNET_AUDIENCE_SECRET` secure and rotated regularly
2. **Database Access**: Use least-privilege SQL accounts for each component
3. **HTTPS**: Always use HTTPS in production for JWT transmission
4. **Token Expiration**: Ensure JWT tokens have reasonable expiration times
5. **Role Assignment**: JWT users get `global:member` + `project:editor` by default

---

## Support

For issues or questions:
1. Check logs with `$env:N8N_LOG_LEVEL = "debug"`
2. Verify prerequisite script ran successfully
3. Check JWT token contents in logs (unverified decode)
4. Verify database schema matches expectations

---

## Summary

✅ **Start n8n first**: Auto-creates all system roles  
✅ **One SQL script per tenant**: Creates "n8nnet" project only  
✅ **Configure once**: Set JWT environment variables  
✅ **Restart n8n**: Run `START_N8N_MSSQL.ps1`  
✅ **Users auto-register**: JWT users join "n8nnet" project automatically  
✅ **Easy deployment**: Roles managed by n8n, script only creates project  

The system is designed for easy multi-tenant deployment with minimal per-tenant configuration!

