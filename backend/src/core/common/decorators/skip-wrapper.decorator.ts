import { SetMetadata } from '@nestjs/common';

/** Metadatos para que el interceptor de envoltorio no envuelva una respuesta. */
export const SKIP_WRAPPER_KEY = 'urbano:skipWrapper';

/** Marca un handler (o controller) cuya respuesta sale SIN el envoltorio {data, meta}. */
export const SkipWrapper = () => SetMetadata(SKIP_WRAPPER_KEY, true);

export function isSkipWrapper(handler: object): boolean {
  return Reflect.getMetadata(SKIP_WRAPPER_KEY, handler) === true;
}
