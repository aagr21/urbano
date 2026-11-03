import type { IncomingMessage, ServerResponse } from 'node:http';
import type { INestApplication } from '@nestjs/common';
import { createApp } from '../src/bootstrap';

let appPromise: Promise<INestApplication> | undefined;

export default async function handler(
  request: IncomingMessage,
  response: ServerResponse,
): Promise<void> {
  appPromise ??= createApp();
  const app = await appPromise;
  app.getHttpAdapter().getInstance()(request, response);
}
