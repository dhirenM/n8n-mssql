# Quick Migration Guide - Top Priority Repositories

## Start Here: Migrate Core Repositories First

These are the **most critical** repositories to migrate for basic multitenant functionality:

### 1. UserRepository ⭐️
**Why:** Users are tenant-specific. Without this, all tenants share the same users!

### 2. WorkflowRepository ⭐️⭐️⭐️
**Why:** THE core feature. Each tenant must have isolated workflows.

### 3. CredentialsRepository ⭐️⭐️
**Why:** Security critical! Credentials must be isolated per tenant.

### 4. ExecutionRepository ⭐️⭐️
**Why:** Execution history must be tenant-specific.

### 5. SharedWorkflowRepository ⭐️
**Why:** Workflow sharing/permissions are tenant-specific.

---

## Migration Steps

### Step 1: UserRepository

<function_calls>
<invoke name="read_file">
<parameter name="target_file">C:\Git\n8n-mssql\packages\@n8n\db\src\repositories\user.repository.ts
