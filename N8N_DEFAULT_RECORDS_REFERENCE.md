# n8n Default Records Reference

This document explains what default records need to be inserted into the n8n MSSQL database for it to function properly.

## Overview

For n8n to work correctly, certain default records MUST exist in the database before the application starts. These records are created by the `MSSQL_N8N_PREREQUISITE_SETUP.sql` script.

## Required Records by Table

### 1. n8n.scope - Permission Scopes (31+ records)

Permission scopes define what actions users can perform in the system.

### 2. n8n.role - Global Roles (3 records)

| Slug | Display Name | Description |
|------|--------------|-------------|
| `global:owner` | Owner | Instance owner with full permissions |
| `global:admin` | Admin | Administrator with elevated permissions |
| `global:member` | Member | Regular member with standard permissions |

### 3. n8n.role_scope - Role-Scope Mappings

Maps which scopes each role has access to.

### 4. n8n.user - Shell Owner User (1 record)

A "shell" user that acts as a placeholder for the instance owner.

### 5. n8n.project - Personal Project (1 record)

Every owner needs a personal project for their workflows.

### 6. n8n.settings - System Settings (6+ records)

| Key | Value | Description |
|-----|-------|-------------|
| `userManagement.isInstanceOwnerSetUp` | `'false'` | **CRITICAL**: Must be false for setup wizard |
| `userManagement.skipInstanceOwnerSetup` | `'false'` | Controls whether to skip owner setup |
| `instanceId` | `<UUID>` | Unique instance identifier |

## Setup Flow

```
1. Create Database
   ↓
2. Run n8n_schema_initialization.sql (creates schema + tables)
   ↓
3. Run MSSQL_N8N_PREREQUISITE_SETUP.sql (inserts default records)
   ↓
4. Start n8n
```

## Verification Queries

```sql
-- Check scopes (should be 31+)
SELECT COUNT(*) as ScopeCount FROM [n8n].[scope];

-- Check roles (should be 3)
SELECT * FROM [n8n].[role];

-- Check shell owner user
SELECT * FROM [n8n].[user] WHERE roleSlug = 'global:owner';

-- Check critical settings
SELECT [key], value FROM [n8n].[settings]
WHERE [key] = 'userManagement.isInstanceOwnerSetUp';
```

