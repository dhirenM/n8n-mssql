/**
 * Axios Interceptor for Multi-Tenant Support
 * 
 * Adds custom headers to all HTTP requests:
 * - Authorization: Bearer token from localStorage/cookie
 * - Role: User role from localStorage/cookie  
 * - Database: Database name from localStorage/cookie
 * 
 * Supports three deployment modes:
 * 1. Elevate: Multi-tenant with multiple Voyager databases
 * 2. Virtuoso.ai: Single instance with hardcoded connection
 * 3. n8n: Native functionality (no custom headers)
 * 
 * Backward compatible - only adds headers if they exist in localStorage/cookies
 */

import axios from 'axios';

// Helper function to get cookie value
function getCookie(name: string): string | null {
	const nameEQ = name + '=';
	const ca = document.cookie.split(';');
	for (let i = 0; i < ca.length; i++) {
		let c = ca[i];
		while (c.charAt(0) === ' ') c = c.substring(1, c.length);
		if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length);
	}
	return null;
}

// Helper function to set cookie
function setCookie(name: string, value: string, days?: number): void {
	let expires = '';
	if (days) {
		const date = new Date();
		date.setTime(date.getTime() + days * 24 * 60 * 60 * 1000);
		expires = '; expires=' + date.toUTCString();
	}
	document.cookie = name + '=' + (value || '') + expires + '; path=/';
}

// Helper function to get data from localStorage
function getFromLocalStorage<T>(key: string): T | null {
	try {
		const item = localStorage.getItem(key);
		return item ? JSON.parse(item) : null;
	} catch {
		return null;
	}
}

/**
 * Initialize localStorage to cookie sync
 * This ensures cookies are always in sync with localStorage
 */
export function initializeAuthSync(): void {
	// Check if we're in a multi-tenant environment
	const isMultiTenant = import.meta.env.VITE_MULTI_TENANT_ENABLED === 'true';
	
	if (!isMultiTenant) {
		// Native n8n mode - no custom headers needed
		return;
	}

	// Sync authorization data from localStorage to cookies
	const authDataStr = localStorage.getItem('ls.authorizationData');
	if (authDataStr) {
		try {
			const authData = JSON.parse(authDataStr);
			if (authData.token) {
				setCookie('token', authData.token, 7); // 7 days expiry
			}
		} catch (e) {
			console.warn('Failed to parse authorization data:', e);
		}
	}

	// Sync role from localStorage to cookies
	const roleStr = localStorage.getItem('ls.role');
	if (roleStr) {
		try {
			const role = JSON.parse(roleStr);
			setCookie('role', role, 7);
		} catch (e) {
			console.warn('Failed to parse role:', e);
		}
	}

	// Sync database from localStorage to cookies
	const databaseStr = localStorage.getItem('ls.database');
	if (databaseStr) {
		try {
			const database = JSON.parse(databaseStr);
			setCookie('database', database, 7);
		} catch (e) {
			console.warn('Failed to parse database:', e);
		}
	}
}

/**
 * Setup axios request interceptor
 * Adds custom headers to all outgoing requests
 * 
 * In Elevate mode, this BYPASSES n8n's built-in authentication
 * and uses .NET JWT tokens + role/database headers instead
 */
export function setupAxiosInterceptor(): void {
	// Check if we're in a multi-tenant environment
	const isMultiTenant = import.meta.env.VITE_MULTI_TENANT_ENABLED === 'true';
	
	if (!isMultiTenant) {
		// Native n8n mode - use n8n's built-in authentication
		console.log('Running in native n8n mode - multi-tenant headers disabled');
		return;
	}

	console.log('🔒 Multi-tenant mode enabled - using custom JWT authentication');
	console.log('   Bypassing n8n built-in auth, using .NET JWT + Role + Database headers');

	// Add request interceptor
	axios.interceptors.request.use(
		(config) => {
			// Only add custom headers for API requests to our backend
			// Skip external APIs (n8n.io, n8n.cloud, etc.)
			const isInternalApi =
				config.baseURL?.startsWith('/') ||
				config.url?.startsWith('/') ||
				(!config.baseURL?.includes('api.n8n.io') && !config.baseURL?.includes('n8n.cloud'));

			if (!isInternalApi) {
				return config;
			}

			// Get token from cookie or localStorage
			let token = getCookie('token');
			if (!token) {
				const authData = getFromLocalStorage<{ token?: string }>('ls.authorizationData');
				token = authData?.token || null;
			}

			// Get role from cookie or localStorage
			let role = getCookie('role');
			if (!role) {
				role = getFromLocalStorage<string>('ls.role');
			}

			// Get database from cookie or localStorage
			let database = getCookie('database');
			if (!database) {
				database = getFromLocalStorage<string>('ls.database');
			}

			// ALWAYS add headers in multi-tenant mode (even if empty)
			// This signals to backend to use custom authentication
			if (!config.headers['Authorization']) {
				config.headers['Authorization'] = token ? `Bearer ${token}` : '';
			}

			if (!config.headers['Role']) {
				config.headers['Role'] = role || '';
			}

			if (!config.headers['Database']) {
				config.headers['Database'] = database || '';
			}

			// Log headers for debugging (only in development)
			if (import.meta.env.DEV) {
				console.log('[Axios Interceptor] Custom auth headers:', {
					Authorization: config.headers['Authorization'] ? '***' : 'empty',
					Role: config.headers['Role'] || 'empty',
					Database: config.headers['Database'] || 'empty',
				});
			}

			return config;
		},
		(error) => {
			return Promise.reject(error);
		},
	);

	// Add response interceptor (for error handling)
	axios.interceptors.response.use(
		(response) => response,
		(error) => {
			// Handle 401 Unauthorized - clear auth data
			if (error.response?.status === 401) {
				console.warn('Unauthorized - clearing auth data');
				
				// TODO: Re-enable clearing auth data on 401 after fixing auth flow issues
				// Currently commented out to prevent premature logout during development
				// REVERT THIS LATER when auth flow is stable
				/*
				localStorage.removeItem('ls.authorizationData');
				localStorage.removeItem('ls.role');
				localStorage.removeItem('ls.database');
				setCookie('token', '', -1);
				setCookie('role', '', -1);
				setCookie('database', '', -1);
				*/
			}

			return Promise.reject(error);
		},
	);
}

/**
 * Update auth data in localStorage and cookies
 * Call this when user logs in or auth data changes
 */
export function updateAuthData(data: {
	token?: string;
	role?: string;
	database?: string;
}): void {
	if (data.token) {
		localStorage.setItem('ls.authorizationData', JSON.stringify({ token: data.token }));
		setCookie('token', data.token, 7);
	}

	if (data.role) {
		localStorage.setItem('ls.role', JSON.stringify(data.role));
		setCookie('role', data.role, 7);
	}

	if (data.database) {
		localStorage.setItem('ls.database', JSON.stringify(data.database));
		setCookie('database', data.database, 7);
	}
}

/**
 * Clear all auth data
 * Call this on logout
 */
export function clearAuthData(): void {
	localStorage.removeItem('ls.authorizationData');
	localStorage.removeItem('ls.role');
	localStorage.removeItem('ls.database');
	setCookie('token', '', -1);
	setCookie('role', '', -1);
	setCookie('database', '', -1);
}

