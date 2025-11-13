import { useUsersStore } from '@/features/settings/users/users.store';
import { useSettingsStore } from '@/app/stores/settings.store';
import type { RBACPermissionCheck, AuthenticatedPermissionOptions } from '@/app/types/rbac';

export const isAuthenticated: RBACPermissionCheck<AuthenticatedPermissionOptions> = (options) => {
	if (options?.bypass?.()) {
		return true;
	}

	// In multi-tenant mode (Elevate/Virtuoso.ai), ONLY check JWT - bypass n8n auth entirely
	if (import.meta.env.VITE_MULTI_TENANT_ENABLED === 'true') {
		try {
			// Helper to get cookie value
			const getCookie = (name: string): string | null => {
				const nameEQ = name + '=';
				const ca = document.cookie.split(';');
				for (let i = 0; i < ca.length; i++) {
					let c = ca[i];
					while (c.charAt(0) === ' ') c = c.substring(1, c.length);
					if (c.indexOf(nameEQ) === 0) return c.substring(nameEQ.length, c.length);
				}
				return null;
			};

			// Try to get JWT from localStorage first
			let token = null;
			let database = null;
			let role = null;

			const authData = localStorage.getItem('ls.authorizationData');
			if (authData) {
				const parsed = JSON.parse(authData);
				token = parsed.token;
			}

			database = localStorage.getItem('ls.database');
			if (database) {
				database = JSON.parse(database);
			}

			// If not in localStorage, try cookies (for Elevate cross-app login)
			if (!token) {
				token = getCookie('token');
			}
			if (!database) {
				database = getCookie('database');
			}
			if (!role) {
				role = getCookie('role');
			}

			// If JWT token exists (from localStorage OR cookie), consider authenticated
			if (token) {
				console.log('[Auth Check] JWT token found - user authenticated');
				return true; // Authenticated via JWT (Elevate mode)
			}

			console.log('[Auth Check] No JWT token found - user NOT authenticated');
			// In multi-tenant mode, if no JWT, user is NOT authenticated
			// Don't fall back to n8n auth
			return false;
		} catch (e) {
			console.error('Error checking JWT authentication:', e);
			return false;
		}
	}

	// In native n8n mode, use n8n's built-in authentication
	const usersStore = useUsersStore();
	return !!usersStore.currentUser;
};

export const shouldEnableMfa: RBACPermissionCheck<AuthenticatedPermissionOptions> = () => {
	// Had user got MFA enabled?
	const usersStore = useUsersStore();
	const hasUserEnabledMfa = usersStore.currentUser?.mfaAuthenticated ?? false;

	// Are we enforcing MFA?
	const settingsStore = useSettingsStore();
	const isMfaEnforced = settingsStore.isMFAEnforced;

	return !hasUserEnabledMfa && isMfaEnforced;
};
