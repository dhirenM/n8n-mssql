import type { FrontendSettings } from '@n8n/api-types';

import type { IRestApiContext } from '../types';
import { get } from '../utils';

export async function getSettings(context: IRestApiContext): Promise<FrontendSettings> {
	// Settings endpoint returns data directly (not wrapped in { data: {...} })
	// So we use get() instead of makeRestApiRequest()
	return await get(context.baseUrl, '/settings', undefined, { 'push-ref': context.pushRef });
}
