/**
 * Identidad «social» derivada del device_key. Se usa como respaldo cuando un
 * cliente manda el like/comentario sin apodo: el resultado es determinista
 * (mismo device_key → mismo apodo y color), así dos dispositivos nunca ven
 * autores distintos para el mismo comentario. La app calcula su propio apodo
 * con el mismo algoritmo (ver core/identity/passenger_identity.dart).
 */

const ADJETIVOS = [
  'Rápido',
  'Tranquilo',
  'Amable',
  'Piloto',
  'Atento',
  'Genuino',
  'Leal',
  'Serio',
  'Listo',
  'Fiel',
  'Vivo',
  'Claro',
];

const SUSTANTIVOS = [
  'Micro',
  'Minibús',
  'Paradero',
  'Asiento',
  'Pasajero',
  'Chofer',
  'Recorrido',
  'Tramo',
  'Ave',
  'Tucán',
  'Ñandú',
  'Gato',
];

// Paleta de colores de avatar (hex sin '#'), compartida con la app.
export const AVATAR_PALETTE = [
  'E74C3C',
  '8E44AD',
  '3498DB',
  '16A085',
  'F39C12',
  'D35400',
  '2C3E50',
  '27AE60',
];

/** Hash estable (FNV-1a 32 bits) sobre la cadena de device_key. */
function hashKey(value: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

export function nicknameFor(deviceKey: string): string {
  const seed = hashKey(deviceKey || 'anonimo');
  const adj = ADJETIVOS[seed % ADJETIVOS.length];
  const sust = SUSTANTIVOS[(seed >> 5) % SUSTANTIVOS.length];
  const num = 10 + ((seed >> 10) % 90);
  return `${adj} ${sust} ${num}`;
}

export function avatarColorFor(deviceKey: string): string {
  const seed = hashKey(`${deviceKey}:color`);
  return AVATAR_PALETTE[seed % AVATAR_PALETTE.length];
}
