const baseUrl = (
  process.env.SMOKE_BASE_URL ??
  'https://backend-weld-seven-97.vercel.app/api/v1'
).replace(/\/$/, '');

const checks = [
  ['/health', (body) => body.status === 'ok' && body.db === 'up'],
  ['/stats', (body) => body.data?.routes === 154 && body.data?.stops === 31461],
  ['/routes?limit=1', (body) => body.data?.length === 1],
];

for (const [path, valid] of checks) {
  const url = `${baseUrl}${path}`;
  const response = await fetch(url);

  if (!response.ok) {
    // Si el backend está caído, mostrar un mensaje claro en vez de
    // intentar parsear HTML como JSON.
    const text = await response.text().catch(() => '(no se pudo leer)');
    const preview = text.length > 200 ? text.slice(0, 200) + '…' : text;
    throw new Error(
      `Smoke falló en ${path}: HTTP ${response.status} — ${preview}`,
    );
  }

  let body;
  try {
    body = await response.json();
  } catch (e) {
    throw new Error(
      `Smoke falló en ${path}: la respuesta no es JSON — ${e.message}`,
    );
  }

  if (!valid(body)) {
    throw new Error(`Smoke falló en ${path}: validación de datos`);
  }
  console.log(`OK ${path}`);
}
