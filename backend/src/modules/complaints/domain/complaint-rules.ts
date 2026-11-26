/**
 * Reglas de las denuncias, PURAS (sin Nest, TypeORM ni red): qué se acepta
 * al crear una queja o un comentario y cómo se limpia lo que manda el
 * cliente. El servicio las aplica y traduce el error a un 400.
 */

export const COMPLAINT_CATEGORIES: ReadonlySet<string> = new Set([
  'vehicle',
  'driver_treatment',
  'route_deviation',
  'schedule',
  'safety',
  'other',
]);

export const COMPLAINT_LIMITS = {
  descriptionChars: 2000,
  photos: 5,
  photoBytes: 5 * 1024 * 1024,
  commentChars: 500,
  authorNameChars: 40,
} as const;

export const ALLOWED_PHOTO_TYPES: ReadonlySet<string> = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
]);

/** Lo que el dominio necesita saber de una foto subida. */
export interface PhotoCandidate {
  mimetype: string;
  size: number;
}

/** Resultado de una validación: el valor limpio o el motivo del rechazo. */
export type Checked<T> = { ok: true; value: T } | { ok: false; error: string };

const fail = <T>(error: string): Checked<T> => ({ ok: false, error });

/**
 * Valida una queja nueva y devuelve su descripción recortada. TODAS las fotos
 * se validan antes de subir ninguna: así un archivo inválido no deja otras
 * fotos ya subidas sin queja.
 */
export function checkNewComplaint(input: {
  routeId: string;
  category: string;
  description?: string;
  photos: PhotoCandidate[];
}): Checked<{ description: string }> {
  if (!input.routeId || !COMPLAINT_CATEGORIES.has(input.category)) {
    return fail('Ruta o categoría inválida');
  }
  const description = (input.description ?? '').trim();
  if (description.length > COMPLAINT_LIMITS.descriptionChars) {
    return fail(
      `La descripción puede tener como máximo ${COMPLAINT_LIMITS.descriptionChars} caracteres`
    );
  }
  if (input.photos.length > COMPLAINT_LIMITS.photos) {
    return fail(`Puedes adjuntar hasta ${COMPLAINT_LIMITS.photos} fotos`);
  }
  for (const photo of input.photos) {
    if (!ALLOWED_PHOTO_TYPES.has(photo.mimetype)) {
      return fail('Solo se permiten JPG, PNG o WebP');
    }
    if (photo.size > COMPLAINT_LIMITS.photoBytes) {
      return fail('Cada foto puede pesar como máximo 5 MB');
    }
  }
  return { ok: true, value: { description } };
}

/** Valida un comentario y devuelve su texto recortado. */
export function checkComment(body: string | undefined): Checked<string> {
  const text = (body ?? '').trim();
  if (text.length === 0) return fail('El comentario no puede estar vacío');
  if (text.length > COMPLAINT_LIMITS.commentChars) {
    return fail(
      `El comentario puede tener como máximo ${COMPLAINT_LIMITS.commentChars} caracteres`
    );
  }
  return { ok: true, value: text };
}

/**
 * Apodo del autor tal como llega del cliente: espacios colapsados y como
 * mucho [COMPLAINT_LIMITS.authorNameChars] caracteres. `null` si no queda
 * nada (el servicio usa entonces el apodo derivado del dispositivo).
 */
export function cleanAuthorName(name: string | undefined): string | null {
  const clean = (name ?? '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, COMPLAINT_LIMITS.authorNameChars);
  return clean.length > 0 ? clean : null;
}

/** Ruta del archivo en el almacenamiento: única por instante y nombre. */
export function photoObjectName(nowMs: number, originalName: string): string {
  return `complaints/${nowMs}-${originalName}`;
}
