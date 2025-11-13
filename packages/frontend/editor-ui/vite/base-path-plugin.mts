import type { Plugin } from 'vite';

export function basePathPlugin(basePath: string): Plugin {
	return {
		name: 'base-path-replacer',
		transformIndexHtml(html) {
			// Replace BASE_PATH placeholders in index.html
			return html
				.replace(/\/\{\{BASE_PATH\}\}\//g, basePath)
				.replace(/%7B%7BBASE_PATH%7D%7D/g, basePath.replace(/\//g, ''))
				.replace(/%257B%257BBASE_PATH%257D%257D/g, basePath.replace(/\//g, ''));
		},
	};
}

