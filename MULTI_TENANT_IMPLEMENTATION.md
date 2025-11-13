# Multi-Tenant Implementation Guide

## Overview

This implementation enables n8n to work across three deployment scenarios:

1. **Elevate** - Multi-tenant with dynamic Voyager database connections per client
2. **Virtuoso.ai** - Single instance with hardcoded connection
3. **n8n Native** - Standard n8n functionality

## Architecture

### Frontend: Axios Interceptor
**File:** `packages/frontend/editor-ui/src/plugins/axios-interceptor.ts`

Automatically adds headers to all HTTP requests:
- `Authorization`: Bearer token from localStorage/cookie
- `Role`: User role from localStorage/cookie
- `Database`: Database name from localStorage/cookie

Only activates when `VITE_MULTI_TENANT_ENABLED=true`

### Backend: Voyager DataSource Factory  
**File:** `packages/cli/src/databases/voyager.datasource.factory.ts`

Uses Flowise pattern to fetch database credentials:
- Reads `Database` header/cookie/query parameter
- Queries Elevate DB with encrypted credentials (DecryptByPassphrase)
- Creates/caches DataSource connection to Voyager database

## Configuration

### Elevate Mode (Multi-Tenant)

```bash
# Frontend
VITE_MULTI_TENANT_ENABLED=true

# Backend
ELEVATE_DATABASE_HOST=localhost
ELEVATE_DATABASE_NAME=ElevateDB
ELEVATE_PASSPHRASE=YourSecretKey
```

### Virtuoso.ai Mode (Single Instance)

```bash
# Frontend
VITE_MULTI_TENANT_ENABLED=true

# Backend (hardcoded database)
DATABASE_HOST=localhost
DATABASE_NAME=virtuoso_db
```

### Native n8n Mode

```bash
# Frontend (disabled)
VITE_MULTI_TENANT_ENABLED=false

# Backend (standard)
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=localhost
```

## Key Files

- `packages/frontend/editor-ui/src/plugins/axios-interceptor.ts` - Header injection
- `packages/frontend/editor-ui/src/main.ts` - Interceptor initialization
- `packages/cli/src/databases/voyager.datasource.factory.ts` - Database routing
- `packages/cli/src/middlewares/subdomain-validation.middleware.ts` - Subdomain handling

## Usage

### Login Component
```typescript
import { updateAuthData } from '@/plugins/axios-interceptor';

updateAuthData({
  token: response.token,
  role: response.role,
  database: response.database
});
```

### Logout Component
```typescript
import { clearAuthData } from '@/plugins/axios-interceptor';

clearAuthData();
```

