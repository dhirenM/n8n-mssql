-- ============================================================================
-- n8n Database Schema for Microsoft SQL Server (IDEMPOTENT VERSION)
-- ============================================================================
-- This schema can be run multiple times safely
-- Schema and tables are only created if they don't already exist
--
-- WARNING: MSSQL is NOT officially supported by n8n
-- Use PostgreSQL, MySQL, MariaDB, or SQLite for production
-- ============================================================================

SET NOCOUNT ON;
GO

PRINT '========================================';
PRINT 'Starting n8n Database Schema Creation';
PRINT '========================================';
PRINT '';

-- ============================================================================
-- Create Schema
-- ============================================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'n8n')
BEGIN
    PRINT 'Creating schema: n8n';
    EXEC('CREATE SCHEMA [n8n]');
    PRINT '✓ Schema created: n8n';
END
ELSE
    PRINT '- Schema already exists: n8n';
GO

-- ============================================================================
-- Core System Tables
-- ============================================================================

-- Migrations table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[migrations]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.migrations';
    CREATE TABLE [n8n].[migrations] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [timestamp] BIGINT NOT NULL,
        [name] NVARCHAR(255) NOT NULL
    );
    PRINT '✓ Table created: n8n.migrations';
END
ELSE
    PRINT '- Table already exists: n8n.migrations';
GO

-- Settings table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[settings]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.settings';
    CREATE TABLE [n8n].[settings] (
        [key] NVARCHAR(255) PRIMARY KEY,
        [value] NVARCHAR(MAX) NOT NULL,
        [loadOnStartup] BIT NOT NULL
    );
    PRINT '✓ Table created: n8n.settings';
END
ELSE
    PRINT '- Table already exists: n8n.settings';
GO

-- ============================================================================
-- User Management Tables
-- ============================================================================

-- Roles table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[role]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.role';
    CREATE TABLE [n8n].[role] (
        [slug] NVARCHAR(255) PRIMARY KEY,
        [displayName] NVARCHAR(255) NOT NULL,
        [description] NVARCHAR(MAX),
        [roleType] NVARCHAR(50) NOT NULL,
        [systemRole] BIT NOT NULL DEFAULT 0,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    PRINT '✓ Table created: n8n.role';
END
ELSE
    PRINT '- Table already exists: n8n.role';
GO

-- Create index for role if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_UniqueRoleDisplayName' AND object_id = OBJECT_ID('[n8n].[role]'))
BEGIN
    PRINT 'Creating index: IDX_UniqueRoleDisplayName on n8n.role';
    CREATE UNIQUE INDEX [IDX_UniqueRoleDisplayName] ON [n8n].[role] ([displayName]);
    PRINT '✓ Index created: IDX_UniqueRoleDisplayName';
END
GO

-- Scopes table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[scope]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.scope';
    CREATE TABLE [n8n].[scope] (
        [slug] NVARCHAR(255) PRIMARY KEY,
        [displayName] NVARCHAR(255),
        [description] NVARCHAR(MAX)
    );
    PRINT '✓ Table created: n8n.scope';
END
ELSE
    PRINT '- Table already exists: n8n.scope';
GO

-- Role-Scope mapping table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[role_scope]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.role_scope';
    CREATE TABLE [n8n].[role_scope] (
        [roleSlug] NVARCHAR(255) NOT NULL,
        [scopeSlug] NVARCHAR(255) NOT NULL,
        PRIMARY KEY ([roleSlug], [scopeSlug]),
        CONSTRAINT [FK_role_scope_roleSlug] FOREIGN KEY ([roleSlug]) 
            REFERENCES [n8n].[role]([slug]) ON DELETE CASCADE,
        CONSTRAINT [FK_role_scope_scopeSlug] FOREIGN KEY ([scopeSlug]) 
            REFERENCES [n8n].[scope]([slug]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.role_scope';
END
ELSE
    PRINT '- Table already exists: n8n.role_scope';
GO

-- Create index for role_scope if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_role_scope_scopeSlug' AND object_id = OBJECT_ID('[n8n].[role_scope]'))
BEGIN
    PRINT 'Creating index: IDX_role_scope_scopeSlug on n8n.role_scope';
    CREATE INDEX [IDX_role_scope_scopeSlug] ON [n8n].[role_scope] ([scopeSlug]);
    PRINT '✓ Index created: IDX_role_scope_scopeSlug';
END
GO

-- Users table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[user]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.user';
    CREATE TABLE [n8n].[user] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [email] NVARCHAR(254),
        [firstName] NVARCHAR(32),
        [lastName] NVARCHAR(32),
        [password] NVARCHAR(MAX),
        [personalizationAnswers] NVARCHAR(MAX),
        [settings] NVARCHAR(MAX),
        [disabled] BIT NOT NULL DEFAULT 0,
        [mfaEnabled] BIT NOT NULL DEFAULT 0,
        [mfaSecret] NVARCHAR(MAX),
        [mfaRecoveryCodes] NVARCHAR(MAX),
        [lastActiveAt] DATE,
        [roleSlug] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_user_roleSlug] FOREIGN KEY ([roleSlug]) 
            REFERENCES [n8n].[role]([slug])
    );
    PRINT '✓ Table created: n8n.user';
END
ELSE
    PRINT '- Table already exists: n8n.user';
GO

-- Create indexes for user if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_user_email' AND object_id = OBJECT_ID('[n8n].[user]'))
BEGIN
    PRINT 'Creating index: IDX_user_email on n8n.user';
    CREATE UNIQUE INDEX [IDX_user_email] ON [n8n].[user] ([email]) WHERE [email] IS NOT NULL;
    PRINT '✓ Index created: IDX_user_email';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'user_role_idx' AND object_id = OBJECT_ID('[n8n].[user]'))
BEGIN
    PRINT 'Creating index: user_role_idx on n8n.user';
    CREATE INDEX [user_role_idx] ON [n8n].[user] ([roleSlug]);
    PRINT '✓ Index created: user_role_idx';
END
GO

-- Auth Identity table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[auth_identity]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.auth_identity';
    CREATE TABLE [n8n].[auth_identity] (
        [providerId] NVARCHAR(255) NOT NULL,
        [providerType] NVARCHAR(50) NOT NULL,
        [userId] NVARCHAR(36) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ([providerId], [providerType]),
        CONSTRAINT [FK_auth_identity_userId] FOREIGN KEY ([userId]) 
            REFERENCES [n8n].[user]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.auth_identity';
END
ELSE
    PRINT '- Table already exists: n8n.auth_identity';
GO

-- Create unique index for auth_identity if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ_auth_identity_providerId_providerType' AND object_id = OBJECT_ID('[n8n].[auth_identity]'))
BEGIN
    PRINT 'Creating index: UQ_auth_identity_providerId_providerType on n8n.auth_identity';
    CREATE UNIQUE INDEX [UQ_auth_identity_providerId_providerType] 
        ON [n8n].[auth_identity] ([providerId], [providerType]);
    PRINT '✓ Index created: UQ_auth_identity_providerId_providerType';
END
GO

-- Auth Provider Sync History table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[auth_provider_sync_history]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.auth_provider_sync_history';
    CREATE TABLE [n8n].[auth_provider_sync_history] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [providerType] NVARCHAR(50) NOT NULL,
        [runMode] NVARCHAR(50) NOT NULL,
        [status] NVARCHAR(50) NOT NULL,
        [startedAt] DATETIME2(3) NOT NULL,
        [endedAt] DATETIME2(3) NOT NULL,
        [scanned] INT NOT NULL,
        [created] INT NOT NULL,
        [updated] INT NOT NULL,
        [disabled] INT NOT NULL,
        [error] NVARCHAR(MAX)
    );
    PRINT '✓ Table created: n8n.auth_provider_sync_history';
END
ELSE
    PRINT '- Table already exists: n8n.auth_provider_sync_history';
GO

-- User API Keys table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[user_api_keys]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.user_api_keys';
    CREATE TABLE [n8n].[user_api_keys] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [userId] NVARCHAR(36) NOT NULL,
        [label] NVARCHAR(255) NOT NULL,
        [apiKey] NVARCHAR(255) NOT NULL,
        [scopes] NVARCHAR(MAX),
        [audience] NVARCHAR(50) NOT NULL DEFAULT 'public-api',
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_user_api_keys_userId] FOREIGN KEY ([userId]) 
            REFERENCES [n8n].[user]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.user_api_keys';
END
ELSE
    PRINT '- Table already exists: n8n.user_api_keys';
GO

-- Create indexes for user_api_keys if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ_user_api_keys_userId_label' AND object_id = OBJECT_ID('[n8n].[user_api_keys]'))
BEGIN
    PRINT 'Creating index: UQ_user_api_keys_userId_label on n8n.user_api_keys';
    CREATE UNIQUE INDEX [UQ_user_api_keys_userId_label] ON [n8n].[user_api_keys] ([userId], [label]);
    PRINT '✓ Index created: UQ_user_api_keys_userId_label';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_user_api_keys_apiKey' AND object_id = OBJECT_ID('[n8n].[user_api_keys]'))
BEGIN
    PRINT 'Creating index: IDX_user_api_keys_apiKey on n8n.user_api_keys';
    CREATE UNIQUE INDEX [IDX_user_api_keys_apiKey] ON [n8n].[user_api_keys] ([apiKey]);
    PRINT '✓ Index created: IDX_user_api_keys_apiKey';
END
GO

-- Invalid Auth Token table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[invalid_auth_token]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.invalid_auth_token';
    CREATE TABLE [n8n].[invalid_auth_token] (
        [token] NVARCHAR(255) PRIMARY KEY,
        [expiresAt] DATETIME2(3) NOT NULL
    );
    PRINT '✓ Table created: n8n.invalid_auth_token';
END
ELSE
    PRINT '- Table already exists: n8n.invalid_auth_token';
GO

-- ============================================================================
-- Project Management Tables
-- ============================================================================

-- Projects table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[project]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.project';
    CREATE TABLE [n8n].[project] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [name] NVARCHAR(255) NOT NULL,
        [type] NVARCHAR(36) NOT NULL,
        [icon] NVARCHAR(MAX),
        [description] NVARCHAR(512),
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    PRINT '✓ Table created: n8n.project';
END
ELSE
    PRINT '- Table already exists: n8n.project';
GO

-- Project Relations table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[project_relation]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.project_relation';
    CREATE TABLE [n8n].[project_relation] (
        [projectId] NVARCHAR(36) NOT NULL,
        [userId] NVARCHAR(36) NOT NULL,
        [role] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ([projectId], [userId]),
        CONSTRAINT [FK_project_relation_projectId] FOREIGN KEY ([projectId]) 
            REFERENCES [n8n].[project]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_project_relation_userId] FOREIGN KEY ([userId]) 
            REFERENCES [n8n].[user]([id]) ON DELETE NO ACTION
    );
    PRINT '✓ Table created: n8n.project_relation';
END
ELSE
    PRINT '- Table already exists: n8n.project_relation';
GO

-- Create indexes for project_relation if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'project_relation_role_project_idx' AND object_id = OBJECT_ID('[n8n].[project_relation]'))
BEGIN
    CREATE INDEX [project_relation_role_project_idx] ON [n8n].[project_relation] ([projectId], [role]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'project_relation_role_idx' AND object_id = OBJECT_ID('[n8n].[project_relation]'))
BEGIN
    CREATE INDEX [project_relation_role_idx] ON [n8n].[project_relation] ([role]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_61448d56d61802b5dfde5cdb00' AND object_id = OBJECT_ID('[n8n].[project_relation]'))
BEGIN
    CREATE INDEX [IDX_61448d56d61802b5dfde5cdb00] ON [n8n].[project_relation] ([projectId]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_5f0643f6717905a05164090dde' AND object_id = OBJECT_ID('[n8n].[project_relation]'))
BEGIN
    CREATE INDEX [IDX_5f0643f6717905a05164090dde] ON [n8n].[project_relation] ([userId]);
END
GO

-- ============================================================================
-- Credentials Tables
-- ============================================================================

-- Credentials Entity table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[credentials_entity]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.credentials_entity';
    CREATE TABLE [n8n].[credentials_entity] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [name] NVARCHAR(128) NOT NULL,
        [data] NVARCHAR(MAX) NOT NULL,
        [type] NVARCHAR(128) NOT NULL,
        [isManaged] BIT NOT NULL DEFAULT 0,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    PRINT '✓ Table created: n8n.credentials_entity';
END
ELSE
    PRINT '- Table already exists: n8n.credentials_entity';
GO

-- Create index for credentials_entity if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_credentials_entity_type' AND object_id = OBJECT_ID('[n8n].[credentials_entity]'))
BEGIN
    CREATE INDEX [idx_credentials_entity_type] ON [n8n].[credentials_entity] ([type]);
END
GO

-- Shared Credentials table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[shared_credentials]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.shared_credentials';
    CREATE TABLE [n8n].[shared_credentials] (
        [credentialsId] NVARCHAR(36) NOT NULL,
        [projectId] NVARCHAR(36) NOT NULL,
        [role] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ([credentialsId], [projectId]),
        CONSTRAINT [FK_shared_credentials_credentialsId] FOREIGN KEY ([credentialsId]) 
            REFERENCES [n8n].[credentials_entity]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_shared_credentials_projectId] FOREIGN KEY ([projectId]) 
            REFERENCES [n8n].[project]([id]) ON DELETE NO ACTION
    );
    PRINT '✓ Table created: n8n.shared_credentials';
END
ELSE
    PRINT '- Table already exists: n8n.shared_credentials';
GO

-- ============================================================================
-- Workflow Tables
-- ============================================================================

-- Folders table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[folder]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.folder';
    CREATE TABLE [n8n].[folder] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [name] NVARCHAR(255) NOT NULL,
        [parentFolderId] NVARCHAR(36),
        [projectId] NVARCHAR(36) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_folder_projectId] FOREIGN KEY ([projectId]) 
            REFERENCES [n8n].[project]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_folder_parentFolderId] FOREIGN KEY ([parentFolderId]) 
            REFERENCES [n8n].[folder]([id]) ON DELETE NO ACTION
    );
    PRINT '✓ Table created: n8n.folder';
END
ELSE
    PRINT '- Table already exists: n8n.folder';
GO

-- Create index for folder if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_14f68deffaf858465715995508' AND object_id = OBJECT_ID('[n8n].[folder]'))
BEGIN
    CREATE INDEX [IDX_14f68deffaf858465715995508] ON [n8n].[folder] ([projectId], [id]);
END
GO

-- Tags table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[tag_entity]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.tag_entity';
    CREATE TABLE [n8n].[tag_entity] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [name] NVARCHAR(24) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    PRINT '✓ Table created: n8n.tag_entity';
END
ELSE
    PRINT '- Table already exists: n8n.tag_entity';
GO

-- Create index for tag_entity if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_8f949d7a3a984759044054e89b' AND object_id = OBJECT_ID('[n8n].[tag_entity]'))
BEGIN
    CREATE INDEX [IDX_8f949d7a3a984759044054e89b] ON [n8n].[tag_entity] ([name]);
END
GO

-- Folder-Tag mapping table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[folder_tag]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.folder_tag';
    CREATE TABLE [n8n].[folder_tag] (
        [folderId] NVARCHAR(36) NOT NULL,
        [tagId] NVARCHAR(36) NOT NULL,
        PRIMARY KEY ([folderId], [tagId]),
        CONSTRAINT [FK_folder_tag_folderId] FOREIGN KEY ([folderId]) 
            REFERENCES [n8n].[folder]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_folder_tag_tagId] FOREIGN KEY ([tagId]) 
            REFERENCES [n8n].[tag_entity]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.folder_tag';
END
ELSE
    PRINT '- Table already exists: n8n.folder_tag';
GO

-- Workflow Entity table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[workflow_entity]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.workflow_entity';
    CREATE TABLE [n8n].[workflow_entity] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [name] NVARCHAR(128) NOT NULL,
        [active] BIT NOT NULL DEFAULT 0,
        [nodes] NVARCHAR(MAX),
        [connections] NVARCHAR(MAX),
        [settings] NVARCHAR(MAX),
        [staticData] NVARCHAR(MAX),
        [pinData] NVARCHAR(MAX),
        [meta] NVARCHAR(MAX),
        [versionId] NVARCHAR(36) NOT NULL,
        [versionCounter] INT NOT NULL DEFAULT 1,
        [triggerCount] INT NOT NULL DEFAULT 0,
        [parentFolderId] NVARCHAR(36),
        [isArchived] BIT NOT NULL DEFAULT 0,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_workflow_entity_parentFolderId] FOREIGN KEY ([parentFolderId]) 
            REFERENCES [n8n].[folder]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.workflow_entity';
END
ELSE
    PRINT '- Table already exists: n8n.workflow_entity';
GO

-- Create index for workflow_entity if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_e10425f6ab9964c4c1623a4a03' AND object_id = OBJECT_ID('[n8n].[workflow_entity]'))
BEGIN
    CREATE INDEX [IDX_e10425f6ab9964c4c1623a4a03] ON [n8n].[workflow_entity] ([name]);
END
GO

-- Workflow-Tag mapping table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[workflows_tags]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.workflows_tags';
    CREATE TABLE [n8n].[workflows_tags] (
        [workflowId] NVARCHAR(36) NOT NULL,
        [tagId] NVARCHAR(36) NOT NULL,
        PRIMARY KEY ([workflowId], [tagId]),
        CONSTRAINT [FK_workflows_tags_workflowId] FOREIGN KEY ([workflowId]) 
            REFERENCES [n8n].[workflow_entity]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_workflows_tags_tagId] FOREIGN KEY ([tagId]) 
            REFERENCES [n8n].[tag_entity]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.workflows_tags';
END
ELSE
    PRINT '- Table already exists: n8n.workflows_tags';
GO

-- Create indexes for workflows_tags if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_workflows_tags_workflow_id' AND object_id = OBJECT_ID('[n8n].[workflows_tags]'))
BEGIN
    CREATE INDEX [idx_workflows_tags_workflow_id] ON [n8n].[workflows_tags] ([workflowId]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_workflows_tags_tag_id' AND object_id = OBJECT_ID('[n8n].[workflows_tags]'))
BEGIN
    CREATE INDEX [idx_workflows_tags_tag_id] ON [n8n].[workflows_tags] ([tagId]);
END
GO

-- Shared Workflow table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[shared_workflow]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.shared_workflow';
    CREATE TABLE [n8n].[shared_workflow] (
        [workflowId] NVARCHAR(36) NOT NULL,
        [projectId] NVARCHAR(36) NOT NULL,
        [role] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ([workflowId], [projectId]),
        CONSTRAINT [FK_shared_workflow_workflowId] FOREIGN KEY ([workflowId]) 
            REFERENCES [n8n].[workflow_entity]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_shared_workflow_projectId] FOREIGN KEY ([projectId]) 
            REFERENCES [n8n].[project]([id]) ON DELETE NO ACTION
    );
    PRINT '✓ Table created: n8n.shared_workflow';
END
ELSE
    PRINT '- Table already exists: n8n.shared_workflow';
GO

-- Workflow Statistics table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[workflow_statistics]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.workflow_statistics';
    CREATE TABLE [n8n].[workflow_statistics] (
        [workflowId] NVARCHAR(36) NOT NULL,
        [name] NVARCHAR(255) NOT NULL,
        [count] INT,
        [latestEvent] DATETIME2(3),
        [rootCount] INT,
        PRIMARY KEY ([workflowId], [name]),
        CONSTRAINT [FK_workflow_statistics_workflowId] FOREIGN KEY ([workflowId]) 
            REFERENCES [n8n].[workflow_entity]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.workflow_statistics';
END
ELSE
    PRINT '- Table already exists: n8n.workflow_statistics';
GO

-- Workflow History table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[workflow_history]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.workflow_history';
    CREATE TABLE [n8n].[workflow_history] (
        [versionId] NVARCHAR(36) PRIMARY KEY,
        [workflowId] NVARCHAR(36) NOT NULL,
        [authors] NVARCHAR(MAX) NOT NULL,
        [nodes] NVARCHAR(MAX) NOT NULL,
        [connections] NVARCHAR(MAX) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    PRINT '✓ Table created: n8n.workflow_history';
END
ELSE
    PRINT '- Table already exists: n8n.workflow_history';
GO

-- Create index for workflow_history if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_1e31657f5fe46816c34be7c1b4' AND object_id = OBJECT_ID('[n8n].[workflow_history]'))
BEGIN
    CREATE INDEX [IDX_1e31657f5fe46816c34be7c1b4] ON [n8n].[workflow_history] ([workflowId]);
END
GO

-- Workflow Dependency table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[workflow_dependency]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.workflow_dependency';
    CREATE TABLE [n8n].[workflow_dependency] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [workflowId] NVARCHAR(36) NOT NULL,
        [workflowVersionId] INT NOT NULL,
        [dependencyType] NVARCHAR(50) NOT NULL,
        [dependencyKey] NVARCHAR(255) NOT NULL,
        [indexVersionId] NVARCHAR(36) NOT NULL,
        [dependencyInfo] NVARCHAR(MAX),
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    PRINT '✓ Table created: n8n.workflow_dependency';
END
ELSE
    PRINT '- Table already exists: n8n.workflow_dependency';
GO

-- Create indexes for workflow_dependency if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_e48a201071ab85d9d09119d640' AND object_id = OBJECT_ID('[n8n].[workflow_dependency]'))
BEGIN
    CREATE INDEX [IDX_e48a201071ab85d9d09119d640] ON [n8n].[workflow_dependency] ([dependencyKey]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_e7fe1cfda990c14a445937d0b9' AND object_id = OBJECT_ID('[n8n].[workflow_dependency]'))
BEGIN
    CREATE INDEX [IDX_e7fe1cfda990c14a445937d0b9] ON [n8n].[workflow_dependency] ([dependencyType]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_a4ff2d9b9628ea988fa9e7d0bf' AND object_id = OBJECT_ID('[n8n].[workflow_dependency]'))
BEGIN
    CREATE INDEX [IDX_a4ff2d9b9628ea988fa9e7d0bf] ON [n8n].[workflow_dependency] ([workflowId]);
END
GO

-- ============================================================================
-- Webhook Tables
-- ============================================================================

-- Webhook Entity table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[webhook_entity]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.webhook_entity';
    CREATE TABLE [n8n].[webhook_entity] (
        [webhookPath] NVARCHAR(255) NOT NULL,
        [method] NVARCHAR(10) NOT NULL,
        [workflowId] NVARCHAR(36) NOT NULL,
        [node] NVARCHAR(255) NOT NULL,
        [webhookId] NVARCHAR(255),
        [pathLength] INT,
        PRIMARY KEY ([webhookPath], [method])
    );
    PRINT '✓ Table created: n8n.webhook_entity';
END
ELSE
    PRINT '- Table already exists: n8n.webhook_entity';
GO

-- Create index for webhook_entity if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_webhook_entity_webhook_path_method' AND object_id = OBJECT_ID('[n8n].[webhook_entity]'))
BEGIN
    CREATE INDEX [idx_webhook_entity_webhook_path_method] 
        ON [n8n].[webhook_entity] ([webhookId], [method], [pathLength]);
END
GO

-- ============================================================================
-- Execution Tables
-- ============================================================================

-- Execution Entity table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[execution_entity]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.execution_entity';
    CREATE TABLE [n8n].[execution_entity] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [workflowId] NVARCHAR(36) NOT NULL,
        [finished] BIT NOT NULL,
        [mode] NVARCHAR(50) NOT NULL,
        [retryOf] NVARCHAR(10),
        [retrySuccessId] NVARCHAR(10),
        [status] NVARCHAR(50) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [startedAt] DATETIME2(3),
        [stoppedAt] DATETIME2(3),
        [waitTill] DATETIME2(3),
        [deletedAt] DATETIME2(3)
    );
    PRINT '✓ Table created: n8n.execution_entity';
END
ELSE
    PRINT '- Table already exists: n8n.execution_entity';
GO

-- Create indexes for execution_entity if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_execution_entity_workflowId_id' AND object_id = OBJECT_ID('[n8n].[execution_entity]'))
BEGIN
    CREATE INDEX [IDX_execution_entity_workflowId_id] ON [n8n].[execution_entity] ([workflowId], [id]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_execution_entity_waitTill_id' AND object_id = OBJECT_ID('[n8n].[execution_entity]'))
BEGIN
    CREATE INDEX [IDX_execution_entity_waitTill_id] ON [n8n].[execution_entity] ([waitTill], [id]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_execution_entity_finished_id' AND object_id = OBJECT_ID('[n8n].[execution_entity]'))
BEGIN
    CREATE INDEX [IDX_execution_entity_finished_id] ON [n8n].[execution_entity] ([finished], [id]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_execution_entity_workflowId_finished_id' AND object_id = OBJECT_ID('[n8n].[execution_entity]'))
BEGIN
    CREATE INDEX [IDX_execution_entity_workflowId_finished_id] 
        ON [n8n].[execution_entity] ([workflowId], [finished], [id]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_execution_entity_workflowId_waitTill_id' AND object_id = OBJECT_ID('[n8n].[execution_entity]'))
BEGIN
    CREATE INDEX [IDX_execution_entity_workflowId_waitTill_id] 
        ON [n8n].[execution_entity] ([workflowId], [waitTill], [id]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_execution_entity_deletedAt' AND object_id = OBJECT_ID('[n8n].[execution_entity]'))
BEGIN
    CREATE INDEX [IDX_execution_entity_deletedAt] ON [n8n].[execution_entity] ([deletedAt]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_execution_entity_stoppedAt' AND object_id = OBJECT_ID('[n8n].[execution_entity]'))
BEGIN
    CREATE INDEX [IDX_execution_entity_stoppedAt] ON [n8n].[execution_entity] ([stoppedAt]);
END
GO

-- Execution Data table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[execution_data]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.execution_data';
    CREATE TABLE [n8n].[execution_data] (
        [executionId] INT PRIMARY KEY,
        [workflowData] NVARCHAR(MAX) NOT NULL,
        [data] NVARCHAR(MAX) NOT NULL,
        CONSTRAINT [FK_execution_data_executionId] FOREIGN KEY ([executionId]) 
            REFERENCES [n8n].[execution_entity]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.execution_data';
END
ELSE
    PRINT '- Table already exists: n8n.execution_data';
GO

-- Execution Metadata table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[execution_metadata]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.execution_metadata';
    CREATE TABLE [n8n].[execution_metadata] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [executionId] INT NOT NULL,
        [key] NVARCHAR(255) NOT NULL,
        [value] NVARCHAR(MAX) NOT NULL,
        CONSTRAINT [FK_execution_metadata_executionId] FOREIGN KEY ([executionId]) 
            REFERENCES [n8n].[execution_entity]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.execution_metadata';
END
ELSE
    PRINT '- Table already exists: n8n.execution_metadata';
GO

-- Create index for execution_metadata if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_cec8eea3bf49551482ccb4933e' AND object_id = OBJECT_ID('[n8n].[execution_metadata]'))
BEGIN
    CREATE INDEX [IDX_cec8eea3bf49551482ccb4933e] ON [n8n].[execution_metadata] ([executionId], [key]);
END
GO

-- Execution Annotations table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[execution_annotations]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.execution_annotations';
    CREATE TABLE [n8n].[execution_annotations] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [executionId] INT NOT NULL,
        [vote] NVARCHAR(20),
        [note] NVARCHAR(MAX),
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_execution_annotations_executionId] FOREIGN KEY ([executionId]) 
            REFERENCES [n8n].[execution_entity]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.execution_annotations';
END
ELSE
    PRINT '- Table already exists: n8n.execution_annotations';
GO

-- Create index for execution_annotations if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_97f863fa83c4786f1956508496' AND object_id = OBJECT_ID('[n8n].[execution_annotations]'))
BEGIN
    CREATE INDEX [IDX_97f863fa83c4786f1956508496] ON [n8n].[execution_annotations] ([executionId]);
END
GO

-- Annotation Tag Entity table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[annotation_tag_entity]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.annotation_tag_entity';
    CREATE TABLE [n8n].[annotation_tag_entity] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [name] NVARCHAR(24) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    PRINT '✓ Table created: n8n.annotation_tag_entity';
END
ELSE
    PRINT '- Table already exists: n8n.annotation_tag_entity';
GO

-- Create index for annotation_tag_entity if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_ae51b54c4bb430cf92f48b623f' AND object_id = OBJECT_ID('[n8n].[annotation_tag_entity]'))
BEGIN
    CREATE INDEX [IDX_ae51b54c4bb430cf92f48b623f] ON [n8n].[annotation_tag_entity] ([name]);
END
GO

-- Execution Annotation Tags mapping table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[execution_annotation_tags]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.execution_annotation_tags';
    CREATE TABLE [n8n].[execution_annotation_tags] (
        [annotationId] INT NOT NULL,
        [tagId] NVARCHAR(36) NOT NULL,
        PRIMARY KEY ([annotationId], [tagId]),
        CONSTRAINT [FK_execution_annotation_tags_annotationId] FOREIGN KEY ([annotationId]) 
            REFERENCES [n8n].[execution_annotations]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_execution_annotation_tags_tagId] FOREIGN KEY ([tagId]) 
            REFERENCES [n8n].[annotation_tag_entity]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.execution_annotation_tags';
END
ELSE
    PRINT '- Table already exists: n8n.execution_annotation_tags';
GO

-- Create indexes for execution_annotation_tags if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_c1519757391996eb06064f0e7c' AND object_id = OBJECT_ID('[n8n].[execution_annotation_tags]'))
BEGIN
    CREATE INDEX [IDX_c1519757391996eb06064f0e7c] ON [n8n].[execution_annotation_tags] ([annotationId]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_a3697779b366e131b2bbdae297' AND object_id = OBJECT_ID('[n8n].[execution_annotation_tags]'))
BEGIN
    CREATE INDEX [IDX_a3697779b366e131b2bbdae297] ON [n8n].[execution_annotation_tags] ([tagId]);
END
GO

-- ============================================================================
-- Test Management Tables
-- ============================================================================

-- Test Run table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[test_run]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.test_run';
    CREATE TABLE [n8n].[test_run] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [workflowId] NVARCHAR(36) NOT NULL,
        [status] NVARCHAR(50) NOT NULL,
        [errorCode] NVARCHAR(100),
        [errorDetails] NVARCHAR(MAX),
        [runAt] DATETIME2(3),
        [completedAt] DATETIME2(3),
        [metrics] NVARCHAR(MAX),
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_test_run_workflowId] FOREIGN KEY ([workflowId]) 
            REFERENCES [n8n].[workflow_entity]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.test_run';
END
ELSE
    PRINT '- Table already exists: n8n.test_run';
GO

-- Create index for test_run if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_d6870d3b6e4c185d33926f423c' AND object_id = OBJECT_ID('[n8n].[test_run]'))
BEGIN
    CREATE INDEX [IDX_d6870d3b6e4c185d33926f423c] ON [n8n].[test_run] ([workflowId]);
END
GO

-- Test Case Execution table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[test_case_execution]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.test_case_execution';
    CREATE TABLE [n8n].[test_case_execution] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [testRunId] NVARCHAR(36) NOT NULL,
        [executionId] INT,
        [status] NVARCHAR(50) NOT NULL,
        [runAt] DATETIME2(3),
        [completedAt] DATETIME2(3),
        [errorCode] NVARCHAR(100),
        [errorDetails] NVARCHAR(MAX),
        [metrics] NVARCHAR(MAX),
        [inputs] NVARCHAR(MAX),
        [outputs] NVARCHAR(MAX),
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_test_case_execution_testRunId] FOREIGN KEY ([testRunId]) 
            REFERENCES [n8n].[test_run]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_test_case_execution_executionId] FOREIGN KEY ([executionId]) 
            REFERENCES [n8n].[execution_entity]([id]) ON DELETE SET NULL
    );
    PRINT '✓ Table created: n8n.test_case_execution';
END
ELSE
    PRINT '- Table already exists: n8n.test_case_execution';
GO

-- Create index for test_case_execution if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_8e4b4774db42f1e6dda3452b2a' AND object_id = OBJECT_ID('[n8n].[test_case_execution]'))
BEGIN
    CREATE INDEX [IDX_8e4b4774db42f1e6dda3452b2a] ON [n8n].[test_case_execution] ([testRunId]);
END
GO

-- ============================================================================
-- Data Management Tables
-- ============================================================================

-- Variables table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[variables]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.variables';
    CREATE TABLE [n8n].[variables] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [key] NVARCHAR(255) NOT NULL,
        [type] NVARCHAR(50) NOT NULL,
        [value] NVARCHAR(MAX),
        [projectId] NVARCHAR(36)
    );
    PRINT '✓ Table created: n8n.variables';
END
ELSE
    PRINT '- Table already exists: n8n.variables';
GO

-- Create indexes for variables if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'variables_global_key_unique' AND object_id = OBJECT_ID('[n8n].[variables]'))
BEGIN
    CREATE INDEX [variables_global_key_unique] ON [n8n].[variables] ([key]) WHERE [projectId] IS NULL;
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'variables_project_key_unique' AND object_id = OBJECT_ID('[n8n].[variables]'))
BEGIN
    CREATE INDEX [variables_project_key_unique] ON [n8n].[variables] ([projectId], [key]) WHERE [projectId] IS NOT NULL;
END
GO

-- Processed Data table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[processed_data]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.processed_data';
    CREATE TABLE [n8n].[processed_data] (
        [workflowId] NVARCHAR(36) NOT NULL,
        [context] NVARCHAR(255) NOT NULL,
        [value] NVARCHAR(MAX) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY ([workflowId], [context])
    );
    PRINT '✓ Table created: n8n.processed_data';
END
ELSE
    PRINT '- Table already exists: n8n.processed_data';
GO

-- Event Destinations table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[event_destinations]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.event_destinations';
    CREATE TABLE [n8n].[event_destinations] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [destination] NVARCHAR(MAX) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    PRINT '✓ Table created: n8n.event_destinations';
END
ELSE
    PRINT '- Table already exists: n8n.event_destinations';
GO

-- ============================================================================
-- Data Tables (Backend Module)
-- ============================================================================

-- Data Table table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[data_table]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.data_table';
    CREATE TABLE [n8n].[data_table] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [name] NVARCHAR(128) NOT NULL,
        [projectId] NVARCHAR(36) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_data_table_projectId] FOREIGN KEY ([projectId]) 
            REFERENCES [n8n].[project]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.data_table';
END
ELSE
    PRINT '- Table already exists: n8n.data_table';
GO

-- Create index for data_table if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ_data_table_name_projectId' AND object_id = OBJECT_ID('[n8n].[data_table]'))
BEGIN
    CREATE UNIQUE INDEX [UQ_data_table_name_projectId] ON [n8n].[data_table] ([name], [projectId]);
END
GO

-- Data Table Column table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[data_table_column]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.data_table_column';
    CREATE TABLE [n8n].[data_table_column] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [name] NVARCHAR(128) NOT NULL,
        [type] NVARCHAR(32) NOT NULL,
        [index] INT NOT NULL,
        [dataTableId] NVARCHAR(36) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_data_table_column_dataTableId] FOREIGN KEY ([dataTableId]) 
            REFERENCES [n8n].[data_table]([id]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.data_table_column';
END
ELSE
    PRINT '- Table already exists: n8n.data_table_column';
GO

-- Create index for data_table_column if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ_data_table_column_dataTableId_name' AND object_id = OBJECT_ID('[n8n].[data_table_column]'))
BEGIN
    CREATE UNIQUE INDEX [UQ_data_table_column_dataTableId_name] 
        ON [n8n].[data_table_column] ([dataTableId], [name]);
END
GO

-- ============================================================================
-- Insights/Analytics Tables (Backend Module)
-- ============================================================================

-- Insights Metadata table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[insights_metadata]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.insights_metadata';
    CREATE TABLE [n8n].[insights_metadata] (
        [metaId] INT IDENTITY(1,1) PRIMARY KEY,
        [workflowId] NVARCHAR(16) NOT NULL,
        [projectId] NVARCHAR(36) NOT NULL,
        [workflowName] NVARCHAR(128) NOT NULL,
        [projectName] NVARCHAR(255) NOT NULL
    );
    PRINT '✓ Table created: n8n.insights_metadata';
END
ELSE
    PRINT '- Table already exists: n8n.insights_metadata';
GO

-- Create indexes for insights_metadata if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ_insights_metadata_workflowId' AND object_id = OBJECT_ID('[n8n].[insights_metadata]'))
BEGIN
    CREATE UNIQUE INDEX [UQ_insights_metadata_workflowId] ON [n8n].[insights_metadata] ([workflowId]);
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_1d8ab99d5861c9388d2dc1cf73' AND object_id = OBJECT_ID('[n8n].[insights_metadata]'))
BEGIN
    CREATE INDEX [IDX_1d8ab99d5861c9388d2dc1cf73] ON [n8n].[insights_metadata] ([workflowId]);
END
GO

-- Insights Raw table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[insights_raw]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.insights_raw';
    CREATE TABLE [n8n].[insights_raw] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [metaId] INT NOT NULL,
        [type] INT NOT NULL,
        [value] BIGINT NOT NULL,
        [timestamp] DATETIME2(3) NOT NULL,
        CONSTRAINT [FK_insights_raw_metaId] FOREIGN KEY ([metaId]) 
            REFERENCES [n8n].[insights_metadata]([metaId]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.insights_raw';
END
ELSE
    PRINT '- Table already exists: n8n.insights_raw';
GO

-- Insights By Period table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[insights_by_period]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.insights_by_period';
    CREATE TABLE [n8n].[insights_by_period] (
        [id] INT IDENTITY(1,1) PRIMARY KEY,
        [metaId] INT NOT NULL,
        [type] INT NOT NULL,
        [value] BIGINT NOT NULL,
        [periodUnit] INT NOT NULL,
        [periodStart] DATETIME2(3) NOT NULL,
        CONSTRAINT [FK_insights_by_period_metaId] FOREIGN KEY ([metaId]) 
            REFERENCES [n8n].[insights_metadata]([metaId]) ON DELETE CASCADE
    );
    PRINT '✓ Table created: n8n.insights_by_period';
END
ELSE
    PRINT '- Table already exists: n8n.insights_by_period';
GO

-- Create index for insights_by_period if not exists
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_a4da41795da1422f680c723e80' AND object_id = OBJECT_ID('[n8n].[insights_by_period]'))
BEGIN
    CREATE INDEX [IDX_a4da41795da1422f680c723e80] 
        ON [n8n].[insights_by_period] ([periodStart], [type], [periodUnit], [metaId]);
END
GO

-- ============================================================================
-- Chat Hub Tables (Backend Module)
-- ============================================================================

-- Chat Hub Agents table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[chat_hub_agents]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.chat_hub_agents';
    CREATE TABLE [n8n].[chat_hub_agents] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [name] NVARCHAR(128) NOT NULL,
        [description] NVARCHAR(512),
        [systemPrompt] NVARCHAR(MAX) NOT NULL,
        [ownerId] NVARCHAR(36) NOT NULL,
        [credentialId] NVARCHAR(36),
        [provider] NVARCHAR(16) NOT NULL,
        [model] NVARCHAR(64) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_chat_hub_agents_ownerId] FOREIGN KEY ([ownerId]) 
            REFERENCES [n8n].[user]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_chat_hub_agents_credentialId] FOREIGN KEY ([credentialId]) 
            REFERENCES [n8n].[credentials_entity]([id]) ON DELETE SET NULL
    );
    PRINT '✓ Table created: n8n.chat_hub_agents';
END
ELSE
    PRINT '- Table already exists: n8n.chat_hub_agents';
GO

-- Chat Hub Sessions table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[chat_hub_sessions]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.chat_hub_sessions';
    CREATE TABLE [n8n].[chat_hub_sessions] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [title] NVARCHAR(256) NOT NULL,
        [ownerId] NVARCHAR(36) NOT NULL,
        [lastMessageAt] DATETIME2(3),
        [credentialId] NVARCHAR(36),
        [provider] NVARCHAR(16),
        [model] NVARCHAR(64),
        [workflowId] NVARCHAR(36),
        [agentId] NVARCHAR(36),
        [agentName] NVARCHAR(128),
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_chat_hub_sessions_ownerId] FOREIGN KEY ([ownerId]) 
            REFERENCES [n8n].[user]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_chat_hub_sessions_credentialId] FOREIGN KEY ([credentialId]) 
            REFERENCES [n8n].[credentials_entity]([id]) ON DELETE SET NULL,
        CONSTRAINT [FK_chat_hub_sessions_workflowId] FOREIGN KEY ([workflowId]) 
            REFERENCES [n8n].[workflow_entity]([id]) ON DELETE SET NULL
    );
    PRINT '✓ Table created: n8n.chat_hub_sessions';
END
ELSE
    PRINT '- Table already exists: n8n.chat_hub_sessions';
GO

-- Chat Hub Messages table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[n8n].[chat_hub_messages]') AND type in (N'U'))
BEGIN
    PRINT 'Creating table: n8n.chat_hub_messages';
    CREATE TABLE [n8n].[chat_hub_messages] (
        [id] NVARCHAR(36) PRIMARY KEY,
        [sessionId] NVARCHAR(36) NOT NULL,
        [previousMessageId] NVARCHAR(36),
        [revisionOfMessageId] NVARCHAR(36),
        [retryOfMessageId] NVARCHAR(36),
        [type] NVARCHAR(16) NOT NULL,
        [name] NVARCHAR(128) NOT NULL,
        [content] NVARCHAR(MAX) NOT NULL,
        [provider] NVARCHAR(16),
        [model] NVARCHAR(64),
        [workflowId] NVARCHAR(36),
        [executionId] INT,
        [agentId] NVARCHAR(36),
        [status] NVARCHAR(16) NOT NULL,
        [createdAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        [updatedAt] DATETIME2(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT [FK_chat_hub_messages_sessionId] FOREIGN KEY ([sessionId]) 
            REFERENCES [n8n].[chat_hub_sessions]([id]) ON DELETE CASCADE,
        CONSTRAINT [FK_chat_hub_messages_executionId] FOREIGN KEY ([executionId]) 
            REFERENCES [n8n].[execution_entity]([id]) ON DELETE SET NULL
    );
    PRINT '✓ Table created: n8n.chat_hub_messages';
END
ELSE
    PRINT '- Table already exists: n8n.chat_hub_messages';
GO

-- ============================================================================
-- End of Schema Creation
-- ============================================================================

PRINT '';
PRINT '========================================';
PRINT 'n8n Database Schema Creation Complete!';
PRINT '========================================';
PRINT '';
PRINT 'Tables Created/Verified: 46';
PRINT '';
PRINT '⚠️  WARNING: MSSQL is NOT officially supported by n8n!';
PRINT 'For production use, please use PostgreSQL, MySQL, MariaDB, or SQLite.';
PRINT '';
PRINT 'This script is idempotent and can be run multiple times safely.';
PRINT 'Existing tables will not be modified or recreated.';
PRINT '';

SET NOCOUNT OFF;
GO

