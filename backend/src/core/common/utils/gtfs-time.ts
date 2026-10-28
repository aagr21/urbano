/** Utilidades de tiempo GTFS (HH:mm:ss, pueden exceder 24h en feeds reales). */

/** "06:00:00" | "06:00" | "27:10:00" → segundos desde medianoche. */
export function timeToSeconds(time: string): number {
  const parts = time.trim().split(':').map((p) => Number.parseInt(p, 10));
  if (parts.length < 2 || parts.some((p) => Number.isNaN(p))) {
    throw new Error(`Hora inválida: "${time}" (se esperaba HH:mm[:ss])`);
  }
  const [h, m, s = 0] = parts;
  return h * 3600 + m * 60 + s;
}

/** Segundos → "HH:mm:ss" (zero-padded, respeta horas ≥ 24). */
export function secondsToTime(totalSeconds: number): string {
  const normalized = Math.max(0, Math.round(totalSeconds));
  const h = Math.floor(normalized / 3600);
  const m = Math.floor((normalized % 3600) / 60);
  const s = normalized % 60;
  return [h, m, s].map((v) => String(v).padStart(2, '0')).join(':');
}

/** Hora actual en segundos (medianoche) en la zona horaria dada. */
export function nowSecondsInTimeZone(timeZone = 'America/La_Paz'): number {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date());
  const get = (type: string): number =>
    Number.parseInt(parts.find((p) => p.type === type)?.value ?? '0', 10);
  return get('hour') * 3600 + get('minute') * 60 + get('second');
}
