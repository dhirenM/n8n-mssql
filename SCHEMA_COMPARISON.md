# n8n Schema Comparison: Initialization File vs Migrations

## Summary

This document compares the `n8n_schema_initialization.sql` file with what the n8n migrations expect, highlighting missing elements.

---

## ✅ **What EXISTS in Schema Initialization File**

| Component | Status | Notes |
|-----------|--------|-------|
| `role` table | ✅ Complete | Correct new schema with slug, displayName, roleType, systemRole |
| `scope` table | ✅ Complete | Has slug, displayName, description |
| `role_scope` junction table | ✅ Complete | Links roles to scopes with composite PK and FKs |
| `user` table | ✅ Complete | Has roleSlug column |
| `user.roleSlug` FK | ✅ Exists | Links to role.slug |
| `project` table | ✅ Complete | Standard project fields |
| `project_relation` table | ✅ Mostly Complete | Has role column but... |

---

## ❌ **What is MISSING from Schema Initialization File**

### 1. Foreign Key Constraint ❌

**Missing FK**: `project_relation.role` → `role.slug`

**In Schema File**:
```sql
CREATE TABLE [n8n].[project_relation] (
    ...
    [role] NVARCHAR(255) NOT NULL,
    ...
    -- FK is MISSING!
);
```

**Should Be**:
```sql
CREATE TABLE [n8n].[project_relation] (
    ...
    [role] NVARCHAR(255) NOT NULL,
    ...
    CONSTRAINT [FK_project_relation_role] FOREIGN KEY ([role]) 
        REFERENCES [n8n].[role]([slug])
);
```

**Added By Migration**: `LinkRoleToProjectRelationTable1753953244168`

**Impact**: Without this FK, role validation on project_relation inserts can fail silently.

---

### 2. Default System Roles ❌

**Missing Data**: Default role records

The migrations auto-insert these roles:

**Global Roles**:
- `global:owner` (roleType: 'global', systemRole: true)
- `global:admin` (roleType: 'global', systemRole: true)
- `global:member` (roleType: 'global', systemRole: true)

**Project Roles**:
- `project:admin` (roleType: 'project', systemRole: true)
- `project:editor` (roleType: 'project', systemRole: true)
- `project:viewer` (roleType: 'project', systemRole: true)

**Added By Migrations**:
- `LinkRoleToUserTable1750252139168` - Creates global roles
- `LinkRoleToProjectRelationTable1753953244168` - Creates project roles

**Impact**: Without these roles, user and project_relation inserts will fail due to FK constraints.

---

### 3. Permission Scopes ❌

**Missing Data**: Permission scope records

n8n auto-creates many scopes at startup, including:
- `project:create`, `project:read`, `project:update`, `project:delete`
- `workflow:create`, `workflow:read`, `workflow:update`, `workflow:delete`, `workflow:execute`
- `credential:create`, `credential:read`, `credential:update`, `credential:delete`
- Many more...

**Created By**: n8n at startup (through AuthRolesService or similar)

**Impact**: Minimal if n8n creates them at startup, but may cause issues if running with `N8N_SKIP_MIGRATIONS=true`.

---

### 4. Role-Scope Mappings ❌

**Missing Data**: Records in `role_scope` junction table

These link roles to their permissions. Examples:
- `global:member` → workflow:read, workflow:create, etc.
- `project:editor` → workflow:read, workflow:update, etc.
- `project:admin` → All project & workflow & credential scopes

**Created By**: n8n at startup

**Impact**: Without these, users won't have permissions even with assigned roles.

---

## 🔧 **How to Fix**

### Option 1: Let n8n Create Everything (Recommended)

1. Start n8n with migrations enabled:
   ```powershell
   # Remove N8N_SKIP_MIGRATIONS from environment
   .\START_N8N_MSSQL.ps1
   ```

2. n8n will automatically:
   - Run migrations
   - Create default roles
   - Create permission scopes
   - Create role-scope mappings

3. Then run `ELEVATE_MODE_PREREQUISITES.sql` to create "n8nnet" project

**Pros**:
- Most reliable
- Gets all scopes and mappings
- Future-proof for n8n updates

**Cons**:
- Requires migration system to work

---

### Option 2: Run MISSING_SCHEMA_FIX.sql (Quick Fix)

1. Run the schema initialization SQL (if not already):
   ```sql
   sqlcmd -S Server -d Database -i n8n_schema_initialization.sql
   ```

2. Run the missing schema fix:
   ```sql
   sqlcmd -S Server -d Database -i MISSING_SCHEMA_FIX.sql
   ```

3. Run prerequisites:
   ```sql
   sqlcmd -S Server -d Database -i ELEVATE_MODE_PREREQUISITES.sql
   ```

**Pros**:
- Works without migration system
- Quick deployment
- All required elements added

**Cons**:
- May not have ALL scopes n8n creates
- Needs manual updates if n8n adds new roles/scopes

---

### Option 3: Update Schema Initialization File

Add the missing FK constraint directly to `n8n_schema_initialization.sql`:

**Line ~332 in n8n_schema_initialization.sql**:

Change from:
```sql
CREATE TABLE [n8n].[project_relation] (
    [projectId] NVARCHAR(36) NOT NULL,
    [userId] NVARCHAR(36) NOT NULL,
    [role] NVARCHAR(255) NOT NULL,
    ...
    CONSTRAINT [FK_project_relation_userId] FOREIGN KEY ([userId]) 
        REFERENCES [n8n].[user]([id]) ON DELETE NO ACTION
);
```

To:
```sql
CREATE TABLE [n8n].[project_relation] (
    [projectId] NVARCHAR(36) NOT NULL,
    [userId] NVARCHAR(36) NOT NULL,
    [role] NVARCHAR(255) NOT NULL,
    ...
    CONSTRAINT [FK_project_relation_userId] FOREIGN KEY ([userId]) 
        REFERENCES [n8n].[user]([id]) ON DELETE NO ACTION,
    CONSTRAINT [FK_project_relation_role] FOREIGN KEY ([role])
        REFERENCES [n8n].[role]([slug])
);
```

Then regenerate the database from the updated schema file.

---

## 📊 **Missing Elements Summary**

| Element | Location | Missing From Schema File | Fixed By |
|---------|----------|--------------------------|----------|
| FK: project_relation.role → role.slug | project_relation table | ❌ Yes | MISSING_SCHEMA_FIX.sql or manual ALTER |
| Default system roles (6 roles) | role table data | ❌ Yes | MISSING_SCHEMA_FIX.sql or n8n startup |
| Permission scopes (~50+ scopes) | scope table data | ❌ Yes | MISSING_SCHEMA_FIX.sql (core) + n8n startup (full) |
| Role-scope mappings | role_scope table data | ❌ Yes | MISSING_SCHEMA_FIX.sql (basic) + n8n startup (full) |

---

## ✅ **Recommended Approach for Production**

For **Elevate Mode with Multi-Tenant Voyager Databases**:

1. **Once per n8n version**: Update `n8n_schema_initialization.sql` with missing FK
2. **Once per tenant**: Run updated `n8n_schema_initialization.sql`
3. **Once per tenant**: Run `MISSING_SCHEMA_FIX.sql` to add roles & scopes
4. **Once per tenant**: Run `ELEVATE_MODE_PREREQUISITES.sql` to add "n8nnet" project
5. **Start n8n**: It will sync any additional scopes/mappings automatically

This approach:
- ✅ Works with `N8N_SKIP_MIGRATIONS=true`
- ✅ Consistent across all tenants
- ✅ Fast deployment
- ✅ No migration dependencies

---

## 🔍 **How to Verify**

After running the fixes, verify with these queries:

```sql
-- Check roles (should have at least 6)
SELECT COUNT(*) AS RoleCount FROM n8n.role;
SELECT * FROM n8n.role ORDER BY roleType, slug;

-- Check scopes (should have at least 13 core scopes)
SELECT COUNT(*) AS ScopeCount FROM n8n.scope;

-- Check role-scope mappings (should have mappings)
SELECT COUNT(*) AS MappingCount FROM n8n.role_scope;

-- Check FK exists
SELECT 
    fk.name AS ForeignKeyName,
    OBJECT_NAME(fk.parent_object_id) AS TableName,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS ColumnName
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
WHERE fk.name = 'FK_project_relation_role';
```

---

## 📝 **Files Reference**

- **n8n_schema_initialization.sql** - Base schema (has tables but missing FK and data)
- **MISSING_SCHEMA_FIX.sql** - Adds missing FK constraint, roles, scopes, mappings
- **ELEVATE_MODE_PREREQUISITES.sql** - Creates "n8nnet" default project
- **Schema Comparison** (this file) - Documents what's missing and how to fix

---

## 🎯 **Conclusion**

The schema initialization file has the **correct table structures** but is missing:
1. One foreign key constraint
2. Default role data
3. Permission scope data
4. Role-scope mapping data

Use `MISSING_SCHEMA_FIX.sql` to add these missing elements, or let n8n create them at startup.

