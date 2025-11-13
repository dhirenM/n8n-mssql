# Simplified Permissions for Elevate Mode

## Overview

For Elevate mode, we're giving JWT users **full admin access** by default. This simplifies deployment and ensures the application works smoothly without complex permission configuration.

**Why?**
- .NET API already handles authorization
- n8n just needs to work for authenticated users
- Can fine-tune permissions later if needed

---

## Default Role Assignment

JWT users are automatically created with **admin roles** instead of limited member roles:

| Role Type | Default Value | Provides |
|-----------|---------------|----------|
| **Global Role** | `global:admin` | Full system access (all features) |
| **Project Role** | `project:admin` | Full project access (all workflows/credentials) |

---

## Configuration

### Current Settings (Full Access)

In `START_N8N_MSSQL.ps1`:

```powershell
# JWT users get full admin access
$env:JWT_USER_DEFAULT_ROLE = "global:admin"      # System-wide admin
$env:JWT_USER_PROJECT_ROLE = "project:admin"     # Project admin
```

### To Restrict Access Later

If you want to limit permissions in the future:

```powershell
# JWT users get limited access
$env:JWT_USER_DEFAULT_ROLE = "global:member"     # Basic user
$env:JWT_USER_PROJECT_ROLE = "project:editor"    # Can edit but not delete
```

Or even more restrictive:

```powershell
# JWT users are read-only
$env:JWT_USER_DEFAULT_ROLE = "global:member"     # Basic user
$env:JWT_USER_PROJECT_ROLE = "project:viewer"    # Read-only
```

---

## Permission Levels Explained

### Global Roles

| Role | Level | Description |
|------|-------|-------------|
| `global:owner` | Highest | Full system control, can manage all users/projects |
| `global:admin` | High | Can do almost everything, limited user management |
| `global:member` | Basic | Can use workflows, limited admin features |

### Project Roles

| Role | Level | Description |
|------|-------|-------------|
| `project:admin` | Full Access | Can do everything in the project (create/edit/delete workflows, credentials, etc.) |
| `project:editor` | Edit Access | Can create and edit workflows/credentials, but not delete projects |
| `project:viewer` | Read-Only | Can view workflows and executions, but cannot modify |

---

## What JWT Users Can Do

### With Current Settings (Admin Roles)

✅ **Everything!**
- Create/edit/delete workflows
- Create/edit/delete credentials
- Execute workflows
- View all executions
- Manage project settings
- Share workflows
- Create variables
- Access all n8n features

### If Changed to Member/Editor Roles

✅ **Can Do:**
- Create and edit workflows
- Create and edit credentials
- Execute workflows
- View executions
- Use most features

❌ **Cannot Do:**
- Delete projects
- Manage global settings
- Access certain admin features

### If Changed to Member/Viewer Roles

✅ **Can Do:**
- View workflows
- View executions
- View credentials (metadata only)

❌ **Cannot Do:**
- Create or edit anything
- Execute workflows
- Modify any settings

---

## How It Works

### User Creation Flow

When a JWT user authenticates:

1. **JWT Validated** ✅
2. **User Not Found** → Create new user:
   ```typescript
   // Get admin role (configurable via env var)
   const roleSlug = process.env.JWT_USER_DEFAULT_ROLE || 'global:admin';
   
   // Create user with admin role
   const newUser = {
     email: "user@example.com",
     roleSlug: "global:admin",  // ← FULL ACCESS
     ...
   };
   ```

3. **Link to "n8nnet" Project**:
   ```typescript
   // Get project admin role (configurable via env var)
   const projectRoleSlug = process.env.JWT_USER_PROJECT_ROLE || 'project:admin';
   
   // Link user to project as admin
   const projectRelation = {
     userId: user.id,
     projectId: "n8nnet-project-id",
     role: "project:admin",  // ← FULL PROJECT ACCESS
   };
   ```

4. **User Has Full Access** ✅

---

## Permission Check Example

When user tries to create a workflow, n8n checks:

```typescript
// n8n permission check
const userProjectIds = await findProjectsWithScopes(
  user.id, 
  ['workflow:create']  // Required scope
);

// With global:admin + project:admin:
// ✅ User has ALL scopes → Permission granted

// With global:member + project:editor:
// ✅ User has workflow:create scope → Permission granted

// With global:member + project:viewer:
// ❌ User lacks workflow:create scope → 403 FORBIDDEN
```

---

## Verification

### Check User Permissions

After JWT user is created:

```sql
-- See what a user can do
SELECT 
    u.email,
    u.roleSlug AS globalRole,
    pr.role AS projectRole,
    STRING_AGG(rs.scopeSlug, ', ') AS scopes
FROM n8n.[user] u
INNER JOIN n8n.project_relation pr ON u.id = pr.userId
INNER JOIN n8n.role_scope rs ON pr.role = rs.roleSlug
WHERE u.email = 'jwt-user@example.com'
GROUP BY u.email, u.roleSlug, pr.role;
```

**Expected Result (Current Settings):**
```
email: jwt-user@example.com
globalRole: global:admin
projectRole: project:admin
scopes: project:read, project:update, project:delete, workflow:read, workflow:create, workflow:update, workflow:delete, workflow:execute, credential:read, credential:create, credential:update, credential:delete, [... many more ...]
```

---

## Troubleshooting

### Issue: User Gets 403 FORBIDDEN

**Cause**: User doesn't have required scope for the action

**Solution**:
1. Check current roles:
   ```sql
   SELECT email, roleSlug FROM n8n.[user] WHERE email = 'user@example.com';
   ```

2. If not admin, update environment variables:
   ```powershell
   $env:JWT_USER_DEFAULT_ROLE = "global:admin"
   $env:JWT_USER_PROJECT_ROLE = "project:admin"
   ```

3. Delete and recreate the user (or update manually):
   ```sql
   -- Update existing user to admin
   UPDATE n8n.[user] SET roleSlug = 'global:admin' WHERE email = 'user@example.com';
   UPDATE n8n.project_relation SET role = 'project:admin' WHERE userId = (SELECT id FROM n8n.[user] WHERE email = 'user@example.com');
   ```

### Issue: User Has No Scopes

**Cause**: Role-scope mappings missing in `role_scope` table

**Solution**: Run `MISSING_SCHEMA_FIX.sql` which creates role-scope mappings

---

## Migration Path

### Now: Full Access (Simple)
```
JWT User → global:admin → ALL permissions ✅
```

### Later: Restricted Access (When Needed)
```
JWT User → global:member → Limited permissions
         → project:editor → Can edit but not delete
```

### Future: Custom Roles (Advanced)
```
JWT User → custom:analyst → Only view & execute workflows
         → custom:developer → Can create & edit workflows
```

---

## Summary

✅ **Current Setup**: JWT users = Full admin access  
✅ **Why**: .NET API handles authorization, n8n just needs to work  
✅ **Benefit**: Zero permission issues, smooth operation  
✅ **Future**: Can restrict later by changing 2 environment variables  

**Bottom Line**: Your JWT users will have **full access to everything** and won't hit any permission errors! 🎉

---

## Files Modified

1. **`dotnet-jwt-auth.middleware.ts`** - Uses admin roles by default
2. **`START_N8N_MSSQL.ps1`** - Sets environment variables for admin roles
3. **This guide** - Documents the simplified approach

---

## Quick Reference

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `JWT_USER_DEFAULT_ROLE` | `global:admin` | Role assigned to new JWT users |
| `JWT_USER_PROJECT_ROLE` | `project:admin` | Role assigned in "n8nnet" project |

**To change**: Update environment variables and restart n8n. New users will get the new roles.

