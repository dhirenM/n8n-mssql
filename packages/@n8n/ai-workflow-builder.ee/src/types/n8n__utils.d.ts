declare module '@n8n/utils/search/sublimeSearch' {
	export function sublimeSearch<T extends object>(
		query: string,
		items: T[],
		keys: Array<{ key: string; weight?: number }>,
	): Array<{ item: T; score: number }>;
}

