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
  const response = await fetch(`${baseUrl}${path}`);
  const body = await response.json();
  if (!response.ok || !valid(body)) {
    throw new Error(`Smoke falló en ${path}: HTTP ${response.status}`);
  }
  console.log(`OK ${path}`);
}
