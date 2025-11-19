/**
 * Common utility for checking if requests should skip authentication/validation
 *
 * Used by:
 * - subdomain-validation.middleware.ts
 * - dotnet-jwt-auth.middleware.ts
 */

import type { Request } from 'express';

/**
 * Check if a request is for a static file or public resource that should skip validation
 */
export function shouldSkipValidation(req: Request): boolean {
	// Check both req.url and req.path to handle base paths like /n8nnet/
	const urlToCheck = req.url.toLowerCase();
	const pathToCheck = req.path.toLowerCase();

	// Static file paths
	const staticPaths = ['/assets/', '/static/', '/node-icon/', '/icons/', '/types/', '/favicon.ico'];

	for (const path of staticPaths) {
		if (urlToCheck.includes(path) || pathToCheck.includes(path)) {
			return true;
		}
	}

	// Static file extensions
	const staticExtensions = [
		'.svg',
		'.png',
		'.jpg',
		'.jpeg',
		'.gif',
		'.webp',
		'.ico',
		'.css',
		'.js',
		'.map',
		'.ttf',
		'.woff',
		'.woff2',
		'.eot',
		'.otf',
	];

	for (const ext of staticExtensions) {
		if (urlToCheck.endsWith(ext)) {
			return true;
		}
	}

	// Public endpoints (that don't require authentication)
	const publicEndpoints = [
		'/rest/settings',
		'/rest/login',
		'/rest/oauth',
		'/rest/forgot-password',
		'/rest/resolve-signup-token',
		'/healthz',
		'/metrics',
	];

	for (const endpoint of publicEndpoints) {
		if (urlToCheck.includes(endpoint)) {
			// For login, only skip for POST requests
			if (endpoint === '/rest/login' && req.method !== 'POST') {
				continue;
			}
			return true;
		}
	}

	// WebSocket upgrade requests
	if (req.headers.upgrade === 'websocket') {
		return true;
	}

	// Already has dataSource (already validated)
	if (req.dataSource) {
		return true;
	}

	return false;
}
