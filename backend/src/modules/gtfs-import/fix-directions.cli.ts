#!/usr/bin/env node
import { readFile } from 'fs/promises';
import { resolve } from 'path';
import {
  OsmFeature,
  diagnoseDirections,
  indexFeed,
  oneWaySegmentsFromOsm,
  planShapeNormalization,
  planShapeSwaps,
  reassignShapes,
  replaceRowBlocks,
  restrictToRoutes,
  reverseVueltas,
  stillReversedAfter,
  stillSwappedAfter,
} from './gtfs-feed-repair';
import { OneWayIndex, buildOneWayIndex } from './gtfs-shape-side';
import {
  backupFile,
  parseCsv,
  readZipEntries,
  toCsv,
  writeZipEntries,
} from './gtfs-zip.writer';

/**
 * CLI de reparación de direcciones: npm run fix:gtfs-directions
 *
 * Hace DOS reparaciones sobre el zip, en este orden:
 *
 * 1. **Vuelta duplicada**: detecta rutas cuya vuelta (`direction_id=1`) está
 *    copiada en el mismo orden que la ida y le invierte los `stop_times`.
 * 2. **Lado de calzada (contraflecha)**: comprueba que cada viaje tenga el
 *    `shape` de SU calzada. Varias rutas traen los shapes intercambiados entre
 *    ida y vuelta, así que el micro se dibuja circulando por el carril del
 *    sentido opuesto. Cuando la otra calzada queda a la DERECHA en los dos
 *    sentidos (circulación por la derecha) se intercambian los `shape_id` entre
 *    los dos viajes y se orienta cada shape al orden de paradas de su viaje.
 *
 * Invertir el orden de puntos de un shape (lo que hacía antes este CLI para la
 * vuelta) NO cambia de calzada: el trazado sigue sobre el carril equivocado.
 * Por eso el paso 2 asigna shapes en vez de limitarse a invertirlos.
 *
 * Sin `--apply` solo informa (dry-run). No toca la base de datos: después hay
 * que re-importar (`npm run import:gtfs`) y, si se usa OTP, reconstruir su
 * grafo.
 */

interface Args {
  in: string;
  out: string;
  apply: boolean;
  /** Si se indica, solo se reparan estas rutas (el diagnóstico sigue siendo global). */
  only: string[] | null;
  /** GeoJSON de `osmium export` con las calles del área urbana (para el paso 2). */
  osm: string | null;
}

function parseArgs(argv: string[]): Args {
  const args: Args = {
    in: 'gtfs.zip',
    out: '',
    apply: false,
    only: null,
    osm: null,
  };
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (token === '--apply') args.apply = true;
    else if (token === '--dry-run') args.apply = false;
    else if (token === '--in' && argv[i + 1]) args.in = argv[++i];
    else if (token === '--out' && argv[i + 1]) args.out = argv[++i];
    else if (token === '--osm' && argv[i + 1]) args.osm = resolve(argv[++i]);
    else if (token === '--routes' && argv[i + 1])
      args.only = argv[++i]
        .split(',')
        .map((s) => s.trim())
        .filter((s) => s !== '');
    else throw new Error(`Argumento no reconocido: ${token}`);
  }
  args.in = resolve(args.in);
  args.out = args.out ? resolve(args.out) : args.in;
  return args;
}

/**
 * Lee el GeoJSON de OSM con las calles del área urbana. Se genera una vez con:
 *   osmium extract -b <oeste>,<sur>,<este>,<norte> bolivia-latest.osm.pbf -o city.pbf
 *   osmium export -f geojson city.pbf -o city.geojson
 */
async function loadOneWayIndex(path: string): Promise<OneWayIndex> {
  const parsed = JSON.parse(await readFile(path, 'utf8')) as {
    features?: OsmFeature[];
  };
  return buildOneWayIndex(oneWaySegmentsFromOsm(parsed.features ?? []));
}

const STATUS_LABEL: Record<string, string> = {
  ok: 'correcta',
  reversed: 'INVERTIDA',
  ambiguous: 'ambigua (se omite)',
  incomplete: 'sin datos',
};

const SHAPE_STATUS_LABEL: Record<string, string> = {
  keep: 'calzada correcta',
  swapped: 'SHAPES INTERCAMBIADOS',
  inconclusive: 'no concluyente',
};

const rounded = (v: number | null): number => (v === null ? -1 : Math.round(v));

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const entries = await readZipEntries(args.in);
  const need = (name: string): Buffer => {
    const data = entries.get(name);
    if (!data) throw new Error(`${name} no está en ${args.in}`);
    return data;
  };
  const feed = indexFeed({
    trips: parseCsv(need('trips.txt')),
    stops: parseCsv(need('stops.txt')),
    stopTimes: parseCsv(need('stop_times.txt')),
    shapes: parseCsv(need('shapes.txt')),
  });

  // --- Paso 1: vuelta duplicada ---
  const directions = diagnoseDirections(feed);
  const { selected: candidates, missing } = restrictToRoutes(
    directions.reversed,
    args.only
  );
  if (missing.length > 0) {
    console.warn(
      `AVISO: el detector no marcó estas rutas pedidas: ${missing.join(', ')}`
    );
  }
  console.log(
    `\n=== Diagnóstico de direcciones (${directions.diagnoses.length} rutas con ida+vuelta) ===`
  );
  console.table(
    directions.diagnoses
      .filter((d) => d.status !== 'ok')
      .map((d) => ({
        routeId: d.routeId,
        idaTrip: d.idaTrip,
        vueltaTrip: d.vueltaTrip,
        estado: STATUS_LABEL[d.status] ?? d.status,
        mismoOrdenM: d.sameOrderM,
        espejoM: d.mirrorOrderM,
      }))
  );
  const correctCount = directions.diagnoses.filter(
    (d) => d.status === 'ok'
  ).length;
  console.log(
    `correctas: ${correctCount} · detectadas como invertidas: ${directions.reversed.length}` +
      ` · a reparar: ${candidates.length} · ambiguas: ${directions.ambiguous.length}` +
      `${directions.ambiguous.length ? ` (${directions.ambiguous.join(', ')})` : ''}`
  );

  // Los shapes NO se invierten aquí: su asignación y orientación se resuelven
  // con el detector de lado de calzada, para no invertir el carril equivocado.
  const fixedStopTimeRows = reverseVueltas(feed, candidates);
  for (const vuelta of candidates) {
    const count = fixedStopTimeRows.get(vuelta.tripId)?.length ?? 0;
    console.log(
      `ruta ${vuelta.routeId}: invertido ${vuelta.tripId} (${count} paradas)`
    );
  }
  const stillBad = stillReversedAfter(feed, candidates, fixedStopTimeRows);
  if (stillBad.length > 0) {
    throw new Error(
      `La verificación falló: siguen invertidas ${stillBad.join(', ')}. No se escribe el zip.`
    );
  }

  // --- Paso 2: lado de calzada (contraflecha) ---
  const stopRows = (tripId: string) =>
    fixedStopTimeRows.get(tripId) ?? feed.rowsByTrip.get(tripId) ?? [];
  let shapeIdByTrip = new Map<string, string>();
  let swappedRoutes: string[] = [];

  if (!args.osm) {
    console.warn(
      '\nAVISO: sin --osm no se puede decidir el lado de calzada (los oneway de OSM son la ' +
        'única referencia). Paso 2 omitido; usa --osm city.geojson para repararlo.\n'
    );
  } else {
    const index = await loadOneWayIndex(args.osm);
    console.log(
      `\nOSM: ${index.segments.length} tramos de un solo sentido indexados`
    );
    const plan = planShapeSwaps(feed, stopRows, index, args.only);
    ({ shapeIdByTrip, swappedRoutes } = plan);
    const stillSwapped = stillSwappedAfter(feed, plan, stopRows, index);

    const reports = plan.diagnoses.map(({ routeId, decision }) => ({
      routeId,
      estado: SHAPE_STATUS_LABEL[decision.status] ?? decision.status,
      idaActualPct: rounded(decision.current.ida),
      vueltaActualPct: rounded(decision.current.vuelta),
      idaSwapPct: rounded(decision.swapped.ida),
      vueltaSwapPct: rounded(decision.swapped.vuelta),
    }));
    const count = (status: string) =>
      plan.diagnoses.filter((d) => d.decision.status === status).length;
    console.log('\n=== Lado de calzada (contraflecha) ===');
    console.table(reports.filter((r) => r.estado !== SHAPE_STATUS_LABEL.keep));
    console.log(
      `rutas revisadas: ${plan.diagnoses.length}` +
        ` · calzada correcta: ${count('keep')}` +
        ` · shapes intercambiados: ${swappedRoutes.length}` +
        `${swappedRoutes.length ? ` (${swappedRoutes.join(', ')})` : ''}` +
        ` · no concluyentes: ${count('inconclusive')}`
    );
    if (stillSwapped.length > 0) {
      throw new Error(
        `La verificación de calzada falló: siguen intercambiadas ${stillSwapped.join(', ')}. No se escribe el zip.`
      );
    }
  }

  const fixedShapeRows = planShapeNormalization(feed, shapeIdByTrip, stopRows);

  if (
    swappedRoutes.length === 0 &&
    fixedShapeRows.size === 0 &&
    fixedStopTimeRows.size === 0
  ) {
    console.log('Nada que reparar.\n');
    return;
  }
  if (!args.apply) {
    console.log(
      '\nDry-run: no se escribió nada. Repite con --apply para generar el zip reparado.\n'
    );
    return;
  }

  // --- Reconstruir los CSV y escribir ---
  const rebuilt = new Map<string, Buffer>([
    [
      'stop_times.txt',
      toCsv(
        feed.stopTimes.header,
        replaceRowBlocks(feed.stopTimes.rows, 'trip_id', fixedStopTimeRows)
      ),
    ],
    [
      'shapes.txt',
      toCsv(
        feed.shapes.header,
        replaceRowBlocks(feed.shapes.rows, 'shape_id', fixedShapeRows)
      ),
    ],
    [
      'trips.txt',
      toCsv(feed.trips.header, reassignShapes(feed.trips.rows, shapeIdByTrip)),
    ],
  ]);
  const outEntries = [...entries].map(([name, data]) => ({
    name,
    data: rebuilt.get(name) ?? data,
  }));

  if (args.out === args.in) {
    const backup = resolve('.', 'gtfs.orig.zip');
    const created = await backupFile(args.in, backup);
    console.log(
      created
        ? `Respaldo original en ${backup}`
        : `Respaldo ya existía: ${backup}`
    );
  }
  await writeZipEntries(args.out, outEntries);
  console.log(
    `Zip reparado escrito en ${args.out} (${candidates.length} rutas con la vuelta invertida, ` +
      `${swappedRoutes.length} con los shapes intercambiados de calzada)\n`
  );
}

main().catch((error) => {
  console.error('Error reparando direcciones GTFS:', error);
  process.exit(1);
});
