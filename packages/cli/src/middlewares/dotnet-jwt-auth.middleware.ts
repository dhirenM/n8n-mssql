/**
 * .NET Core JWT Authentication Middleware
 *
 * Validates JWT tokens issued by your .NET Core API.
 * Supports tokens from:
 * - Cookie: 'n8n-auth' or 'token'
 * - Header: 'Authorization: Bearer <token>'
 *
 * Token configuration matches your .NET Core API settings.
 */

import type { Request, Response, NextFunction } from 'express';
import type { DataSource } from '@n8n/typeorm';
import jwt from 'jsonwebtoken';
import { Container } from '@n8n/di';
import {
	UserRepository,
	ProjectRepository,
	ProjectRelationRepository,
	RoleRepository,
} from '@n8n/db';
import type { User } from '@n8n/db';
import { Logger } from '@n8n/backend-common';
import { v4 as uuid } from 'uuid';

// .NET Core JWT Configuration
const AUDIENCE_ID = process.env.DOTNET_AUDIENCE_ID || 'b7d348cb8f204f09b17b1b2d0c951afd';
const AUDIENCE_SECRET =
	process.env.DOTNET_AUDIENCE_SECRET || 'fdbc6c9efcc14b2f-7299dae388174d8fb9c6ef8844';
const ISSUER = process.env.DOTNET_ISSUER || 'qMCdFDQuF23RV1Y-1Gq9L3cF3VmuFwVbam4fMTdAfpo';
const SYMMETRIC_KEY = process.env.DOTNET_SYMMETRIC_KEY || '414e1927a3884f68abc79f7283837fd1';

// Decode base64 secrets (like Flowise)
const base64url = require('base64url');

function getDecodedSecret(base64Secret: string): Buffer {
	try {
		return Buffer.from(base64url.toBuffer(base64Secret), 'base64');
	} catch {
		// If decoding fails, use as-is
		return Buffer.from(base64Secret, 'utf8');
	}
}

const DECODED_AUDIENCE_SECRET = getDecodedSecret(AUDIENCE_SECRET);
const DECODED_SYMMETRIC_KEY = getDecodedSecret(SYMMETRIC_KEY);

export const dotnetJwtAuthMiddleware = async (req: Request, res: Response, next: NextFunction) => {
	const logger = Container.get(Logger);

	try {
		// Skip if .NET JWT validation is disabled
		if (process.env.USE_DOTNET_JWT !== 'true') {
			logger.debug('.NET JWT validation disabled');
			return next();
		}

		// Skip for WebSocket upgrade requests (push connection)
		// WebSocket connections are handled by n8n's auth middleware on the push endpoint
		if (req.headers.upgrade === 'websocket') {
			logger.debug('.NET JWT: Skipping validation for WebSocket/push request');
			return next();
		}

		// 1. Extract token from multiple sources
		let token: string | undefined;

		// Priority 1: n8n cookie
		token = req.cookies?.['n8n-auth'];

		// Priority 2: Flowise cookie (for shared sessions)0
		if (!token) {
			token = req.cookies?.['token'];
		}

		// Priority 3: Authorization header
		if (!token) {
			const authHeader = req.headers['authorization'];
			if (authHeader?.startsWith('Bearer ')) {
				token = authHeader.substring(7); // Remove 'Bearer '
			}
		}

		// If no token, skip (let n8n's default auth handle it or allow public endpoints)
		if (!token) {
			logger.debug('.NET JWT: No token found, skipping validation');
			return next();
		}

		// Debug: Decode token without verification to see its contents
		try {
			const unverifiedToken = jwt.decode(token, { complete: true }) as any;
			if (unverifiedToken) {
				logger.debug('.NET JWT: Token contents (unverified):', {
					header: unverifiedToken.header,
					payload: {
						iss: unverifiedToken.payload?.iss,
						aud: unverifiedToken.payload?.aud,
						sub: unverifiedToken.payload?.sub,
						email: unverifiedToken.payload?.email,
						exp: unverifiedToken.payload?.exp,
						iat: unverifiedToken.payload?.iat,
					},
				});
			}
		} catch (decodeError) {
			logger.warn('.NET JWT: Could not decode token for debugging', {
				error: (decodeError as Error).message,
			});
		}

		// 2. Determine secret and validation parameters (match .NET Core and Flowise)
		const isVirtuosoAI = process.env.IS_VIRTUOSO_AI === 'true';

		const requestHost = req.hostname;
		const issuer = isVirtuosoAI ? (ISSUER ?? requestHost) : requestHost;

		// Get subdomain for audience validation (base64 encoded like Flowise)
		const subdomain = (req as any).subdomain || extractSubdomain(requestHost);
		const audience = isVirtuosoAI
			? (AUDIENCE_ID ?? requestHost)
			: Buffer.from(subdomain).toString('base64');

		logger.debug('.NET JWT validation config:', {
			subdomain,
			issuer,
			audience: audience.substring(0, 20) + '...',
			audienceLength: audience.length,
			isVirtuosoAI,
			secretSource: isVirtuosoAI
				? 'AUDIENCE_SECRET (raw)'
				: 'DECODED_AUDIENCE_SECRET (base64url decoded)',
		});

		// 3. Verify JWT token - try multiple secret formats
		// .NET tokens might use different secret encodings, so we try multiple approaches
		let decodedToken: any;

		// For debugging: set SKIP_JWT_ISSUER_AUDIENCE_CHECK=true to only verify signature
		const skipIssuerAudienceCheck = process.env.SKIP_JWT_ISSUER_AUDIENCE_CHECK === 'true';

		// Match Flowise's secret selection exactly
		const secretsToTry = [
			{
				name: 'Primary (Flowise-style)',
				secret: isVirtuosoAI ? AUDIENCE_SECRET : DECODED_AUDIENCE_SECRET,
			},
			{
				name: 'Raw AUDIENCE_SECRET (string)',
				secret: AUDIENCE_SECRET,
			},
			{
				name: 'Base64url decoded (Buffer)',
				secret: DECODED_AUDIENCE_SECRET,
			},
			{
				name: 'UTF-8 Buffer',
				secret: Buffer.from(AUDIENCE_SECRET, 'utf8'),
			},
			{
				name: 'Direct base64url decode',
				secret: base64url.toBuffer(AUDIENCE_SECRET),
			},
		];

		let lastError: Error | null = null;

		for (const { name, secret } of secretsToTry) {
			try {
				logger.debug(`.NET JWT: Trying secret format: ${name}`);

				const verifyOptions: any = {
					algorithms: ['HS256'],
					complete: true,
				};

				// Add issuer/audience checks unless skipped for debugging
				if (!skipIssuerAudienceCheck) {
					verifyOptions.issuer = issuer;
					verifyOptions.audience = audience;
				} else {
					logger.warn('.NET JWT: SKIPPING issuer/audience validation (debug mode)');
				}

				decodedToken = jwt.verify(token, secret, verifyOptions) as any;

				logger.info(`.NET JWT: ✅ Successfully verified with secret format: ${name}`, {
					skipIssuerAudienceCheck,
				});
				break; // Success! Exit the loop
			} catch (error: any) {
				lastError = error;
				logger.debug(`.NET JWT: ❌ Failed with ${name}: ${error.message}`);
				// Continue to next secret format
			}
		}

		// If all secret formats failed, throw the last error
		if (!decodedToken) {
			logger.error('.NET JWT: All secret formats failed', {
				lastError: lastError?.message,
				secretsTriedCount: secretsToTry.length,
				hints: [
					'Check DOTNET_AUDIENCE_SECRET matches .NET API configuration',
					'Verify the JWT token is valid and not expired',
					'Set SKIP_JWT_ISSUER_AUDIENCE_CHECK=true to debug signature issues only',
					'Check token header algorithm matches HS256',
				],
			});
			throw lastError || new Error('JWT verification failed with all secret formats');
		}

		const payload = decodedToken.payload;

		logger.info('.NET JWT verified successfully', {
			userId: payload.sub || payload.id,
			email: payload.email,
			subdomain,
		});

		// 4. Find or create n8n user from JWT payload
		// OPTION C: Minimal user creation with FK relationships
		// We create just enough database records for n8n's permission system to work:
		// - User record (with JWT sub as user.id)
		// - Personal project
		// - Project relation (linking user to project)
		const userEmail = payload.email || payload.sub || payload.unique_name;

		if (!userEmail) {
			logger.warn('.NET JWT: No email found in token payload');
			return next(); // Skip, let n8n handle
		}

		// Get the Voyager DataSource for this subdomain (from req.dataSource)
		// WHY MIGHT DATASOURCE BE EMPTY?
		// The dataSource is set by subdomain validation middleware that should run
		// BEFORE this JWT middleware. If it's empty, it means:
		// 1. Subdomain middleware hasn't run yet (middleware order issue)
		// 2. Subdomain middleware failed to set dataSource
		// 3. Request is hitting a route that doesn't use subdomain middleware
		const dataSource = (req as any).dataSource;
		if (!dataSource) {
			logger.error(
				'.NET JWT: No dataSource in request - subdomain validation middleware may not have run',
				{
					path: req.path,
					method: req.method,
					hasSubdomain: !!(req as any).subdomain,
				},
			);
			// Don't block the request - let it continue but user won't be attached
			// This prevents breaking the entire app if middleware order is wrong
			return next();
		}

		const userRepo = dataSource.getRepository(Container.get(UserRepository).target);

		// Look up user by EMAIL (not JWT sub/id, as JWT sub may not be a valid GUID)
		// SQL Server requires GUID/UUID for user.id, so we let it auto-generate
		let user = await userRepo.findOne({
			where: { email: userEmail },
			relations: ['role', 'projectRelations'],
		});

		// Auto-create user with minimal required records if doesn't exist (SSO)
		if (!user) {
			const jwtUserId = payload.sub || payload.id;
			logger.info('.NET JWT: User not found, creating minimal records (Option C)', {
				jwtSub: jwtUserId,
				email: userEmail,
				note: 'Will create user and join default "n8nnet" project',
			});
			user = await createN8nUserFromDotNetJWT(payload, dataSource);
		} else {
			logger.debug('.NET JWT: Found existing user', {
				userId: user.id,
				email: user.email,
				jwtSub: payload.sub || payload.id,
				hasProjectRelations: !!user.projectRelations?.length,
			});
		}

		// 5. Attach user and JWT payload to request
		(req as any).user = user;
		(req as any).dotnetJwtPayload = payload;

		logger.debug('.NET JWT: User authenticated', {
			userId: user.id,
			email: user.email,
			subdomain,
		});

		next();
	} catch (error: any) {
		// JWT validation failed
		logger.error('.NET JWT validation failed', {
			error: error.message,
			errorName: error.name,
			errorStack: error.stack,
			name: error.name,
		});

		// Don't block the request - let n8n's auth middleware try
		// This allows fallback to:
		// - n8n's own JWT tokens
		// - API keys
		// - Public endpoints
		next();
	}
};

/**
 * Extract subdomain from hostname
 */
function extractSubdomain(host: string): string {
	// Handle localhost/127.0.0.1
	if (host.includes('localhost') || host.includes('127.0.0.1')) {
		return process.env.DEFAULT_SUBDOMAIN || 'default';
	}

	// Remove port if present
	const hostWithoutPort = host.split(':')[0];

	// Extract first part as subdomain
	const parts = hostWithoutPort.split('.');
	return parts[0];
}

/**
 * OPTION C: Create minimal n8n user records from .NET JWT payload
 *
 * Creates the minimum required database records for n8n's permission system:
 * 1. Get global:member role from database
 * 2. Create user record (with generated UUID and role assignment)
 * 3. Find existing "n8nnet" default project (must exist - see ELEVATE_MODE_PREREQUISITES.sql)
 * 4. Get project:editor role from database
 * 5. Create ProjectRelation linking user to the default "n8nnet" project
 *
 * Note: We lookup users by EMAIL (not JWT sub) because JWT sub may not be a valid GUID.
 * We explicitly generate UUIDs using uuid v4 for SQL Server compatibility.
 * All required fields (id, roleSlug) are populated to satisfy NOT NULL constraints.
 * The "n8nnet" project must be created beforehand using ELEVATE_MODE_PREREQUISITES.sql
 * This ensures all FK relationships work while keeping JWT as source of truth for auth.
 */
async function createN8nUserFromDotNetJWT(payload: any, dataSource: DataSource): Promise<User> {
	const logger = Container.get(Logger);

	// Get repositories
	const userRepo = dataSource.getRepository(Container.get(UserRepository).target);
	const projectRepo = dataSource.getRepository(Container.get(ProjectRepository).target);
	const projectRelationRepo = dataSource.getRepository(
		Container.get(ProjectRelationRepository).target,
	);
	const roleRepo = dataSource.getRepository(Container.get(RoleRepository).target);

	// Extract user info from JWT claims
	const jwtUserId = payload.sub || payload.id; // Keep for logging/reference
	const email = payload.email || payload.unique_name || jwtUserId;
	const firstName = payload.given_name || payload.name?.split(' ')[0] || 'User';
	const lastName = payload.family_name || payload.name?.split(' ').slice(1).join(' ') || '';

	logger.info('Creating minimal n8n user records from JWT (Option C):', {
		jwtSub: jwtUserId,
		email,
		firstName,
		lastName,
		note: 'Will join default "n8nnet" project',
	});

	try {
		// Step 1: Get the admin role for JWT users
		// NOTE: Using global:admin gives full access to everything
		// This simplifies permissions for Elevate mode where .NET API handles authorization
		// TODO: Change to 'global:member' later if you want to restrict permissions
		const roleSlug = process.env.JWT_USER_DEFAULT_ROLE || 'global:admin';
		const memberRole = await roleRepo.findOne({
			where: { slug: roleSlug },
		});

		if (!memberRole) {
			throw new Error(`Default role (${roleSlug}) not found in database`);
		}

		// Step 2: Create user (explicitly generate UUID for SQL Server)
		const userId = uuid(); // Generate a valid GUID/UUID
		const newUser = userRepo.create({
			id: userId, // Explicitly set the UUID we generated
			email: email,
			firstName: firstName,
			lastName: lastName,
			role: memberRole, // Assign global:member role
			// No password - user authenticates via .NET JWT only
			password: null,
			// Set personalization as completed
			personalizationAnswers: {},
			// Default settings
			settings: {},
			// User is active
			disabled: false,
		});

		const savedUser = await userRepo.save(newUser);
		logger.info('✅ Step 2: Created user record', {
			userId: savedUser.id,
			email: savedUser.email,
			role: memberRole.slug,
		});

		// Step 3: Create personal project for user (required by frontend)
		const personalProjectId = uuid();
		const personalProject = projectRepo.create({
			id: personalProjectId,
			name: `${email}'s Project`,
			type: 'personal',
			icon: null,
			description: 'Personal project for JWT-authenticated user',
		});

		const savedPersonalProject = await projectRepo.save(personalProject);
		logger.info('✅ Step 3: Created personal project', {
			projectId: savedPersonalProject.id,
			projectName: savedPersonalProject.name,
		});

		// Step 4: Get the project owner role for personal project
		// Personal projects require 'project:personalOwner' not 'project:admin'!
		const personalOwnerRoleSlug = 'project:personalOwner';
		const personalOwnerRole = await roleRepo.findOne({
			where: { slug: personalOwnerRoleSlug },
		});

		if (!personalOwnerRole) {
			throw new Error('Personal project owner role (project:personalOwner) not found in database');
		}

		// Step 5: Link user to their personal project as personalOwner
		const personalProjectRelation = projectRelationRepo.create({
			userId: savedUser.id,
			projectId: savedPersonalProject.id,
			role: personalOwnerRole, // Use personalOwner for personal projects
		});

		await projectRelationRepo.save(personalProjectRelation);
		logger.info('✅ Step 4: Linked user to personal project', {
			userId: savedUser.id,
			projectId: savedPersonalProject.id,
			role: personalOwnerRole.slug,
		});

		// Step 6: ALSO link to shared "n8nnet" team project (optional but useful)
		const defaultProjectName = process.env.N8N_DEFAULT_PROJECT_NAME || 'n8nnet';
		const sharedProject = await projectRepo.findOne({
			where: {
				name: defaultProjectName,
				type: 'team',
			},
		});

		if (sharedProject) {
			// For team projects, use project:admin role
			const teamAdminRole = await roleRepo.findOne({
				where: { slug: 'project:admin' },
			});

			if (teamAdminRole) {
				const teamProjectRelation = projectRelationRepo.create({
					userId: savedUser.id,
					projectId: sharedProject.id,
					role: teamAdminRole, // Use admin for team projects
				});

				await projectRelationRepo.save(teamProjectRelation);
				logger.info('✅ Step 5: Also linked user to shared team project', {
					projectId: sharedProject.id,
					projectName: sharedProject.name,
					role: teamAdminRole.slug,
				});
			}
		} else {
			logger.warn('Shared team project not found, user only has personal project');
		}

		// Reload user with relations
		const userWithRelations = (await userRepo.findOne({
			where: { id: savedUser.id },
			relations: ['role', 'projectRelations'],
		})) as User;

		logger.info('✅ Successfully created minimal n8n user from JWT', {
			userId: userWithRelations.id,
			email: userWithRelations.email,
			hasProjectRelations: !!userWithRelations.projectRelations?.length,
		});

		return userWithRelations;
	} catch (error: any) {
		logger.error('❌ Failed to create n8n user from JWT', {
			error: error.message,
			stack: error.stack,
			jwtUserId,
			email,
		});
		throw error;
	}
}
