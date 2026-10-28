/** Metadatos del envoltorio estándar { data, meta }. */
export interface PageMeta {
  page: number;
  limit: number;
  total: number;
}

/**
 * Resultado paginado. El interceptor ResponseWrapperInterceptor lo convierte en
 * `{ data: items, meta: { page, limit, total } }`.
 */
export class PaginatedResult<T> {
  readonly __paginated = true as const;

  constructor(
    readonly items: T[],
    readonly meta: PageMeta,
  ) {}
}

export function isPaginatedResult(value: unknown): value is PaginatedResult<unknown> {
  return (
    typeof value === 'object' &&
    value !== null &&
    (value as PaginatedResult<unknown>).__paginated === true
  );
}

export function paginated<T>(items: T[], meta: PageMeta): PaginatedResult<T> {
  return new PaginatedResult(items, meta);
}

/** Lista sin paginación real (total = cantidad de items). */
export function fullList<T>(items: T[]): PaginatedResult<T> {
  return new PaginatedResult(items, { page: 1, limit: items.length, total: items.length });
}
