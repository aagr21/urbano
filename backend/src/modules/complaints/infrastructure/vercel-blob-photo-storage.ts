import { Injectable } from '@nestjs/common';
import { put } from '@vercel/blob';
import { PhotoStoragePort } from '../domain/photo-storage.port';

/** Fotos en Vercel Blob (acceso público), con `BLOB_READ_WRITE_TOKEN`. */
@Injectable()
export class VercelBlobPhotoStorage implements PhotoStoragePort {
  /** Se lee en cada uso (como antes): no depende de cuándo se cargó `.env`. */
  private get token(): string | undefined {
    return process.env.BLOB_READ_WRITE_TOKEN;
  }

  get configured(): boolean {
    return !!this.token;
  }

  async upload(name: string, data: Buffer, contentType: string): Promise<string> {
    const blob = await put(name, data, {
      access: 'public',
      contentType,
      token: this.token,
    });
    return blob.url;
  }
}
