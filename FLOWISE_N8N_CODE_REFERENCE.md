# Flowise to N8N Code Reference Guide

Quick reference showing Flowise patterns and how to implement them in N8N.

---

## 1. Request Context Pattern

### Flowise Implementation
**File:** `C:\Git\Flowise-Main\packages\server\src\middleware\requestContext.ts`

```typescript
import { AsyncLocalStorage } from 'async_hooks';
import { Request, Response, NextFunction } from 'express';
import { DataSource } from 'typeorm';

const asyncLocalStorage = new AsyncLocalStorage<Map<string, any>>();

export const requestContextMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const store = new Map<string, any>();
  store.set('request', req);
  
  asyncLocalStorage.run(store, () => {
    next();
  });
};

export const getRequestDataSource = () => {
  const store = asyncLocalStorage.getStore();
  return store?.get('request')?.dataSource as DataSource;
};
```

### N8N Implementation (Proposed)
**File:** `packages/cli/src/middlewares/request-context.middleware.ts`

```typescript
import { AsyncLocalStorage } from 'async_hooks';
import { Request, Response, NextFunction } from 'express';
import { DataSource } from '@n8n/typeorm';
import { Service } from '@n8n/di';

const asyncLocalStorage = new AsyncLocalStorage<Map<string, any>>();

@Service()
export class RequestContextService {
  private static storage = new AsyncLocalStorage<Map<string, any>>();

  middleware() {
    return (req: Request, res: Response, next: NextFunction) => {
      const store = new Map<string, any>();
      store.set('request', req);
      
      RequestContextService.storage.run(store, () => {
        next();
      });
    };
  }

  getRequest(): Request | undefined {
    const store = RequestContextService.storage.getStore();
    return store?.get('request');
  }

  getDataSource(): DataSource | undefined {
    const store = RequestContextService.storage.getStore();
    return store?.get('request')?.dataSource;
  }

  getUser() {
    const store = RequestContextService.storage.getStore();
    return store?.get('request')?.user;
  }

  getCompany() {
    const store = RequestContextService.storage.getStore();
    return store?.get('request')?.company;
  }
}

// Helper functions for easy access
export function getRequestDataSource(): DataSource | undefined {
  const service = Container.get(RequestContextService);
  return service.getDataSource();
}

export function getRequestUser() {
  const service = Container.get(RequestContextService);
  return service.getUser();
}
```

---

## 2. Multi-Tenant Database Manager

### Flowise Implementation
**File:** `C:\Git\Flowise-Main\packages\server\src\DataSource.ts`

```typescript
let elevateDataSource: DataSource;
const dataSources: Map<string, DataSource> = new Map();

export const init = async (): Promise<void> => {
  // Initialize elevate database connection
  elevateDataSource = createDataSource({
    type: 'mssql',
    host: process.env.ELEVATE_DATABASE_HOST,
    database: process.env.ELEVATE_DATABASE_NAME,
    username: process.env.ELEVATE_DATABASE_USER,
    password: process.env.ELEVATE_DATABASE_PASSWORD
  });
  
  await elevateDataSource.initialize();
};

export async function getDataSourceForSubdomain(
  subdomain: string, 
  req?: Request
): Promise<DataSource> {
  const config = await getDatabaseConfig(subdomain, req);
  const connectionKey = getConnectionKey(config);
  
  let dataSource = dataSources.get(connectionKey);
  if (dataSource && dataSource.isInitialized) {
    return dataSource;
  }
  
  dataSource = createDataSource(config);
  await dataSource.initialize();
  dataSources.set(connectionKey, dataSource);
  
  return dataSource;
}

async function getDatabaseConfig(subdomain: string, req?: Request): Promise<DatabaseConfig> {
  const query = `
    SELECT db.instance, db.[database],
           CAST(DecryptByPassphrase(@0 + '-' + c.[guid], cred.[user]) AS VARCHAR) AS [user],
           CAST(DecryptByPassphrase(@0 + '-' + c.[guid], cred.[pass]) AS VARCHAR) AS pass
    FROM voyagerdb db
    JOIN voyagerdbcred cred ON cred.voyagerdbid = db.id
    JOIN company c ON c.id = db.companyid
    WHERE db.[name] = @1
  `;
  
  const result = await elevateDataSource.query(query, [passphrase, databaseName]);
  
  return {
    host: result[0].instance,
    database: result[0].database,
    username: result[0].user,
    password: result[0].pass
  };
}
```

### N8N Implementation (Proposed)
**File:** `packages/cli/src/services/tenant-datasource-manager.service.ts`

```typescript
import { Service } from '@n8n/di';
import { DataSource } from '@n8n/typeorm';
import { Logger } from '@n8n/backend-common';
import { MultiTenantConfig } from '@/config/multi-tenant.config';

interface TenantDatabaseConfig {
  host: string;
  database: string;
  username: string;
  password: string;
  port: number;
}

@Service()
export class TenantDataSourceManager {
  private elevateDataSource?: DataSource;
  private tenantDataSources = new Map<string, DataSource>();
  
  constructor(
    private readonly config: MultiTenantConfig,
    private readonly logger: Logger,
  ) {}

  async initialize(): Promise<void> {
    if (!this.config.isMultiTenantMode) {
      this.logger.info('Multi-tenant mode disabled');
      return;
    }

    // Initialize Elevate (central metadata) database
    this.elevateDataSource = new DataSource({
      type: 'mssql',
      host: this.config.elevate.host,
      port: this.config.elevate.port,
      username: this.config.elevate.username,
      password: this.config.elevate.password,
      database: this.config.elevate.database,
      entities: [], // Only metadata queries, no entities
      options: {
        encrypt: this.config.elevate.ssl,
        trustServerCertificate: true,
      },
    });

    await this.elevateDataSource.initialize();
    this.logger.info('Elevate database initialized');
  }

  async getDataSourceForTenant(
    subdomain: string,
    req?: Request,
  ): Promise<DataSource> {
    // Get database configuration from Elevate DB
    const config = await this.getTenantDatabaseConfig(subdomain, req);
    const connectionKey = this.getConnectionKey(config);

    // Return cached connection if exists
    let dataSource = this.tenantDataSources.get(connectionKey);
    if (dataSource?.isInitialized) {
      return dataSource;
    }

    // Create new connection
    dataSource = new DataSource({
      type: 'mssql',
      host: config.host,
      port: config.port,
      username: config.username,
      password: config.password,
      database: config.database,
      entities: [...], // N8N entities
      migrations: [...], // N8N migrations
      options: {
        encrypt: true,
        trustServerCertificate: true,
      },
    });

    await dataSource.initialize();
    this.tenantDataSources.set(connectionKey, dataSource);
    
    this.logger.info(`Tenant database connection created for ${subdomain}`);
    return dataSource;
  }

  private async getTenantDatabaseConfig(
    subdomain: string,
    req?: Request,
  ): Promise<TenantDatabaseConfig> {
    if (!this.elevateDataSource) {
      throw new Error('Elevate database not initialized');
    }

    const databaseName = req?.headers?.['database'] || req?.query?.DatabaseGUID;
    const passphrase = this.config.elevate.passphrase;

    const query = `
      SELECT TOP 1
        db.instance,
        db.[database],
        CAST(DecryptByPassphrase(@0 + '-' + c.[guid], cred.[user]) AS VARCHAR(100)) AS [user],
        CAST(DecryptByPassphrase(@0 + '-' + c.[guid], cred.[pass]) AS VARCHAR(100)) AS [pass]
      FROM voyagerdb db
      JOIN voyagerdbcred cred ON cred.voyagerdbid = db.id
      JOIN company c ON c.id = db.companyid
      WHERE ${databaseName ? 'db.[guid] = @1' : 'db.[name] = @1'}
    `;

    const result = await this.elevateDataSource.query(query, [passphrase, databaseName]);

    if (!result || result.length === 0) {
      throw new Error(`No database configuration found for: ${subdomain}`);
    }

    return {
      host: result[0].instance,
      database: result[0].database,
      username: result[0].user,
      password: result[0].pass,
      port: 1433,
    };
  }

  private getConnectionKey(config: TenantDatabaseConfig): string {
    return `${config.host}_${config.username}_${config.database}`;
  }

  getElevateDataSource(): DataSource {
    if (!this.elevateDataSource) {
      throw new Error('Elevate database not initialized');
    }
    return this.elevateDataSource;
  }
}
```

---

## 3. Subdomain Validation Middleware

### Flowise Implementation
**File:** `C:\Git\Flowise-Main\packages\server\src\middleware\SubdomainValidation.ts`

```typescript
export const validateSubdomain = async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Skip for assets
    if (req.url.includes('assets') || req.url.includes('node-icon')) {
      return next();
    }

    const host = req.get('host') || '';
    
    // Skip for localhost
    if (host.includes('localhost') || host.includes('127.0.0.1')) {
      const dataSource = await getDataSourceForSubdomain('default', req);
      req.dataSource = dataSource;
      return next();
    }
    
    // Extract subdomain
    const parts = host.split('.');
    const subdomain = parts[0];
    
    // Get elevate database
    const elevateDataSource = getElevateDataSource();
    
    // Query company
    const result = await elevateDataSource.query(
      `SELECT * FROM company WHERE domain = @0`,
      [subdomain]
    );

    if (!result || result.length === 0) {
      return res.status(403).json({
        error: 'Invalid subdomain',
        message: 'Access denied. Invalid company domain.'
      });
    }

    const company = result[0];
    
    if (company.inactive) {
      return res.status(403).json({
        error: 'Company Inactive'
      });
    }

    // Get tenant database
    const dataSource = await getDataSourceForSubdomain(subdomain, req);
    
    req.subdomain = subdomain;
    req.company = company;
    req.dataSource = dataSource;
    next();
  } catch (error) {
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Error validating company domain.'
    });
  }
};
```

### N8N Implementation (Proposed)
**File:** `packages/cli/src/middlewares/subdomain-validation.middleware.ts`

```typescript
import { Request, Response, NextFunction } from 'express';
import { Service } from '@n8n/di';
import { TenantDataSourceManager } from '@/services/tenant-datasource-manager.service';
import { Logger } from '@n8n/backend-common';
import { AppConfig } from '@/config/app.config';

declare global {
  namespace Express {
    interface Request {
      subdomain?: string;
      company?: any;
      dataSource?: DataSource;
      queryStore?: Record<string, any>;
    }
  }
}

@Service()
export class SubdomainValidationMiddleware {
  constructor(
    private readonly tenantManager: TenantDataSourceManager,
    private readonly appConfig: AppConfig,
    private readonly logger: Logger,
  ) {}

  middleware() {
    return async (req: Request, res: Response, next: NextFunction) => {
      try {
        // Skip validation for specific paths
        if (this.shouldSkipValidation(req)) {
          return next();
        }

        // Skip if not in multi-tenant mode
        if (!this.appConfig.isMultiTenantMode) {
          return next();
        }

        const host = req.get('host') || '';
        
        // Handle localhost
        if (this.isLocalhost(host)) {
          req.dataSource = await this.tenantManager.getDataSourceForTenant('default', req);
          return next();
        }

        // Extract subdomain
        const subdomain = this.extractSubdomain(host);
        this.logger.debug(`Extracted subdomain: ${subdomain}`);

        // Validate company
        const company = await this.validateCompany(subdomain);
        
        // Get tenant database connection
        const dataSource = await this.tenantManager.getDataSourceForTenant(subdomain, req);

        // Attach to request
        req.subdomain = subdomain;
        req.company = company;
        req.dataSource = dataSource;

        next();
      } catch (error) {
        this.logger.error('Subdomain validation error:', error);
        return res.status(500).json({
          error: 'Internal Server Error',
          message: 'Error validating tenant.'
        });
      }
    };
  }

  private shouldSkipValidation(req: Request): boolean {
    const skipPaths = ['/assets/', '/node-icon/', '/healthz'];
    return skipPaths.some(path => req.url.includes(path));
  }

  private isLocalhost(host: string): boolean {
    return host.includes('localhost') || host.includes('127.0.0.1');
  }

  private extractSubdomain(host: string): string {
    const parts = host.split('.');
    return parts[0];
  }

  private async validateCompany(subdomain: string) {
    const elevateDb = this.tenantManager.getElevateDataSource();
    
    const result = await elevateDb.query(
      `SELECT id, name, domain, inactive, guid 
       FROM company 
       WHERE domain = @0`,
      [subdomain]
    );

    if (!result || result.length === 0) {
      throw new Error(`Invalid subdomain: ${subdomain}`);
    }

    const company = result[0];
    
    if (company.inactive) {
      throw new Error(`Company is inactive: ${subdomain}`);
    }

    return company;
  }
}
```

---

## 4. JWT Authentication

### Flowise Implementation
**File:** `C:\Git\Flowise-Main\packages\server\src\middleware\authenticateJWT.ts`

```typescript
const jwt = require('jsonwebtoken');

export const authenticateJWT = async (req: Request, res: Response, next: NextFunction) => {
  let authHeader = req.headers['authorization'];

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    authHeader = getCookie(req, 'token') ?? undefined;
    if(!authHeader) {
      return res.status(401).json({ message: "Unauthorized: No token provided" });
    }
  }

  const token = authHeader.startsWith("Bearer ") ? authHeader.split(" ")[1] : authHeader;
  
  try {
    const requestHost = req.hostname;
    const secret = appConfig.isVirtuosoAI ? appConfig.authSettings.AudienceSecret : BASE64_SECRET;
    const issuer = appConfig.isVirtuosoAI ? appConfig.authSettings.Issuer : requestHost;
    const audience = appConfig.isVirtuosoAI ? appConfig.authSettings.AudienceId : encodeToBase64(getSubDomain(requestHost));

    const decodedToken = jwt.verify(token, secret, {
      algorithms: ["HS256"],
      complete: true,
      issuer: issuer,
      audience: audience
    });

    // Token is valid
  } catch (error: any) {
    // Fallback to API key validation
    const isKeyValidated = await validateAPIKey(req);
    if (!isKeyValidated) {
      return res.status(403).json({ message: `Forbidden: ${error.message}` });
    }
  }

  next();
};
```

### N8N Implementation (Proposed)
**File:** `packages/cli/src/auth/jwt-multi-tenant.strategy.ts`

```typescript
import { Request } from 'express';
import { JwtPayload, verify } from 'jsonwebtoken';
import { Service } from '@n8n/di';
import { AppConfig } from '@/config/app.config';
import { Logger } from '@n8n/backend-common';

@Service()
export class JwtMultiTenantStrategy {
  constructor(
    private readonly appConfig: AppConfig,
    private readonly logger: Logger,
  ) {}

  extractToken(req: Request): string | null {
    // 1. Check Authorization header
    const authHeader = req.headers['authorization'];
    if (authHeader?.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }

    // 2. Check cookie
    const cookieToken = req.cookies?.['token'];
    if (cookieToken) {
      return cookieToken;
    }

    return null;
  }

  async validate(req: Request): Promise<JwtPayload | null> {
    const token = this.extractToken(req);
    if (!token) {
      return null;
    }

    try {
      const secret = this.getSecret();
      const issuer = this.getIssuer(req);
      const audience = this.getAudience(req);

      const decoded = verify(token, secret, {
        algorithms: ['HS256'],
        issuer,
        audience,
      }) as JwtPayload;

      return decoded;
    } catch (error) {
      this.logger.debug('JWT validation failed', { error });
      return null;
    }
  }

  private getSecret(): string {
    if (this.appConfig.isVirtuosoAI) {
      return this.appConfig.authSettings.audienceSecret;
    }
    return Buffer.from(this.appConfig.authSettings.symmetricKey, 'base64');
  }

  private getIssuer(req: Request): string {
    if (this.appConfig.isVirtuosoAI) {
      return this.appConfig.authSettings.issuer;
    }
    return req.hostname;
  }

  private getAudience(req: Request): string {
    if (this.appConfig.isVirtuosoAI) {
      return this.appConfig.authSettings.audienceId;
    }
    const subdomain = this.extractSubdomain(req.hostname);
    return Buffer.from(subdomain).toString('base64');
  }

  private extractSubdomain(hostname: string): string {
    return hostname.split('.')[0];
  }
}
```

---

## 5. App Configuration

### Flowise Implementation
**File:** `C:\Git\Flowise-Main\packages\server\src\AppConfig.ts`

```typescript
export interface IAppConfig {
  authSettings: {
    SymmetricKey: string | undefined;
    Issuer: string | undefined;
    AudienceId: string | undefined;
    AudienceSecret: string | undefined;
  };
  UseAuth: boolean;
  isVirtuosoAI: boolean;
  isElevate: boolean;
}

export const appConfig: IAppConfig = {
  authSettings: {
    SymmetricKey: process.env.SYMMETRIC_KEY,
    Issuer: process.env.ISSUER,
    AudienceId: process.env.AUDIENCE_ID,
    AudienceSecret: process.env.AUDIENCE_SECRET,
  },
  UseAuth: process.env.USEAUTH?.toLowerCase() === 'true',
  isVirtuosoAI: process.env.IS_VIRTUOSO_AI?.toLowerCase() === 'true',
  isElevate: process.env.IS_ELEVATE?.toLowerCase() === 'true',
};
```

### N8N Implementation (Proposed)
**File:** `packages/cli/src/config/app.config.ts`

```typescript
import { Service } from '@n8n/di';
import { Config } from '@n8n/config';

interface AuthSettings {
  symmetricKey: string;
  issuer: string;
  audienceId: string;
  audienceSecret: string;
  jwtAuthTokenSecret: string;
  jwtRefreshTokenSecret: string;
  tokenExpiryMinutes: number;
  refreshTokenExpiryMinutes: number;
}

@Service()
export class AppConfig {
  constructor(private readonly config: Config) {}

  get isMultiTenantMode(): boolean {
    return process.env.N8N_MODE === 'multi_tenant';
  }

  get useAuth(): boolean {
    return process.env.USE_AUTH === 'true';
  }

  get isVirtuosoAI(): boolean {
    return process.env.IS_VIRTUOSO_AI === 'true';
  }

  get isElevate(): boolean {
    return process.env.IS_ELEVATE === 'true';
  }

  get authSettings(): AuthSettings {
    return {
      symmetricKey: process.env.SYMMETRIC_KEY || '',
      issuer: process.env.ISSUER || process.env.JWT_ISSUER || 'n8n',
      audienceId: process.env.AUDIENCE_ID || process.env.JWT_AUDIENCE || 'n8n-api',
      audienceSecret: process.env.AUDIENCE_SECRET || '',
      jwtAuthTokenSecret: process.env.JWT_AUTH_TOKEN_SECRET || 'change-me',
      jwtRefreshTokenSecret: process.env.JWT_REFRESH_TOKEN_SECRET || process.env.JWT_AUTH_TOKEN_SECRET || 'change-me',
      tokenExpiryMinutes: parseInt(process.env.JWT_TOKEN_EXPIRY_IN_MINUTES || '60'),
      refreshTokenExpiryMinutes: parseInt(process.env.JWT_REFRESH_TOKEN_EXPIRY_IN_MINUTES || '129600'),
    };
  }
}
```

**File:** `packages/cli/src/config/multi-tenant.config.ts`

```typescript
import { Service } from '@n8n/di';

interface ElevateConfig {
  host: string;
  port: number;
  database: string;
  username: string;
  password: string;
  ssl: boolean;
  passphrase: string;
}

@Service()
export class MultiTenantConfig {
  get isMultiTenantMode(): boolean {
    return process.env.N8N_MODE === 'multi_tenant';
  }

  get elevate(): ElevateConfig {
    return {
      host: process.env.ELEVATE_DATABASE_HOST || '',
      port: parseInt(process.env.ELEVATE_DATABASE_PORT || '1433'),
      database: process.env.ELEVATE_DATABASE_NAME || '',
      username: process.env.ELEVATE_DATABASE_USER || '',
      password: process.env.ELEVATE_DATABASE_PASSWORD || '',
      ssl: process.env.ELEVATE_DATABASE_SSL === 'true',
      passphrase: process.env.ELEVATE_PASSPHRASE || '',
    };
  }

  validate(): void {
    if (!this.isMultiTenantMode) return;

    const required = [
      'ELEVATE_DATABASE_HOST',
      'ELEVATE_DATABASE_NAME',
      'ELEVATE_DATABASE_USER',
      'ELEVATE_DATABASE_PASSWORD',
      'ELEVATE_PASSPHRASE',
    ];

    const missing = required.filter(key => !process.env[key]);
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }
  }
}
```

---

## 6. Server Integration

### Flowise Implementation
**File:** `C:\Git\Flowise-Main\packages\server\src\index.ts`

```typescript
async config() {
  this.app.use(express.json({ limit: '50mb' }));
  this.app.set('trust proxy', true);
  this.app.use(cors(getCorsOptions()));
  this.app.use(cookieParser());
  this.app.use(expressRequestLogger);
  this.app.use(queryParamsStore);
  this.app.use(requestContextMiddleware);
  this.app.use(sanitizeMiddleware);
  this.app.use(validateSubdomain);
  
  await initializeJwtCookieMiddleware(this.app, this.identityManager);
  
  // Authentication middleware
  this.app.use(async (req, res, next) => {
    // Complex auth logic here
  });
  
  this.app.use('/api/v1', flowiseApiV1Router);
}
```

### N8N Implementation (Proposed)
**File:** `packages/cli/src/server.ts`

```typescript
import { RequestContextService } from '@/middlewares/request-context.middleware';
import { SubdomainValidationMiddleware } from '@/middlewares/subdomain-validation.middleware';
import { QueryParamsStoreMiddleware } from '@/middlewares/query-params-store.middleware';
import { AppConfig } from '@/config/app.config';
import { TenantDataSourceManager } from '@/services/tenant-datasource-manager.service';

@Service()
export class Server extends AbstractServer {
  constructor(
    private readonly appConfig: AppConfig,
    private readonly tenantManager: TenantDataSourceManager,
    private readonly requestContext: RequestContextService,
    private readonly subdomainValidation: SubdomainValidationMiddleware,
    // ... other dependencies
  ) {
    super();
  }

  async start() {
    // Initialize multi-tenant system if enabled
    if (this.appConfig.isMultiTenantMode) {
      await this.tenantManager.initialize();
    }

    await super.start();
  }

  protected setupMiddlewares() {
    // Existing middlewares
    this.app.use(bodyParser.json());
    this.app.use(cookieParser());
    this.app.use(helmet());
    this.app.use(cors());
    
    // NEW: Multi-tenant middlewares
    if (this.appConfig.isMultiTenantMode) {
      this.app.use(this.requestContext.middleware());
      this.app.use(queryParamsStoreMiddleware);
      this.app.use(this.subdomainValidation.middleware());
    }

    // Existing auth middleware (will be enhanced)
    // ...
  }
}
```

---

## 7. Usage in Controllers/Services

### Flowise Pattern
```typescript
// Before - accessing via App instance
const repository = this.AppDataSource.getRepository(ChatFlow);

// After - accessing via request context
import { getRequestDataSource } from './middleware/requestContext';

const repository = getRequestDataSource().getRepository(ChatFlow);
```

### N8N Pattern (Proposed)
```typescript
// Before
import { Container } from '@n8n/di';
import { Db } from '@n8n/db';

const repository = Container.get(Db).getRepository(WorkflowEntity);

// After - in multi-tenant mode
import { getRequestDataSource } from '@/middlewares/request-context.middleware';
import { AppConfig } from '@/config/app.config';

const appConfig = Container.get(AppConfig);
let repository;

if (appConfig.isMultiTenantMode) {
  repository = getRequestDataSource()!.getRepository(WorkflowEntity);
} else {
  repository = Container.get(Db).getRepository(WorkflowEntity);
}

// Or create a helper
function getRepository<T>(entity: EntityTarget<T>) {
  const appConfig = Container.get(AppConfig);
  if (appConfig.isMultiTenantMode) {
    return getRequestDataSource()!.getRepository(entity);
  }
  return Container.get(Db).getRepository(entity);
}

// Usage
const repository = getRepository(WorkflowEntity);
```

---

## 8. Company Scoping

### Adding Company Scope to Entities

```typescript
// Before
@Entity()
export class WorkflowEntity {
  @PrimaryColumn()
  id: string;

  @Column()
  name: string;
}

// After
@Entity()
export class WorkflowEntity {
  @PrimaryColumn()
  id: string;

  @Column()
  name: string;

  @Column({ nullable: true })
  @Index()
  companyId?: string;
}
```

### Global Query Filter (TypeORM Subscriber)

```typescript
import { EntitySubscriberInterface, EventSubscriber, LoadEvent } from '@n8n/typeorm';
import { getRequestUser, getRequestCompany } from '@/middlewares/request-context.middleware';

@EventSubscriber()
export class CompanyScopingSubscriber implements EntitySubscriberInterface {
  beforeQuery(event: LoadEvent<any>) {
    const company = getRequestCompany();
    if (!company) return;

    // Add company filter to all queries
    if (!event.query.where) {
      event.query.where = {};
    }
    
    if (typeof event.query.where === 'object') {
      event.query.where['companyId'] = company.id;
    }
  }
}
```

---

## Summary

This reference guide shows the key patterns from Flowise that need to be implemented in N8N:

1. **Request Context** - AsyncLocalStorage for request-scoped data
2. **Multi-Tenant DB Manager** - Runtime database connections per tenant
3. **Subdomain Validation** - Extract subdomain, validate company, attach DB connection
4. **JWT Authentication** - Cookie-based with subdomain-aware validation
5. **App Configuration** - Centralized config for multi-tenant mode
6. **Server Integration** - Middleware chain setup
7. **Repository Access** - Using request context instead of global DB
8. **Company Scoping** - Automatic filtering by company ID

Each pattern can be implemented incrementally while maintaining backward compatibility with the existing single-tenant mode.

