/**
 * Almacenamiento público de las fotos de una denuncia (hoy Vercel Blob). El
 * servicio no conoce el proveedor ni sus credenciales.
 */
export interface PhotoStoragePort {
  /** `false` si no hay credenciales: subir fotos está deshabilitado. */
  readonly configured: boolean;

  /** Sube el archivo y devuelve su URL pública. */
  upload(name: string, data: Buffer, contentType: string): Promise<string>;
}
