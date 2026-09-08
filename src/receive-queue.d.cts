export function createOperationQueue(): <T>(operation: () => Promise<T>) => Promise<T>;
export function isTradeURL(value: string): boolean;
