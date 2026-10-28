# Urbano API

Backend de transporte público (micros urbanos) para **Santa Cruz de la Sierra, Bolivia**,
con datos importados desde un feed GTFS. Sirve rutas, paradas, horarios, paradas cercanas
y un planeador de viajes (directo + 1 transbordo) para la app Flutter.

- **Stack:** NestJS 11 + TypeScript, PostgreSQL 17 + PostGIS (Docker), TypeORM
- **Contrato:** [`../docs/api-contract.md`](../docs/api-contract.md) (fuente de verdad)
- **Docs interactivas:** Swagger en `GET /docs`

## Requisitos

- Node.js 20+ (probado con Node 26)
- Docker + Docker Compose

## Puesta en marcha

```bash
# 1. Base de datos (PostGIS, puerto del host 5436 -> 5432 del contenedor)
docker compose up -d

# 2. Dependencias
npm install

# 3. Variables de entorno (ajusta puertos/credenciales si hace falta)
cp .env.example .env

# 4. Importar el feed GTFS (gtfs.zip en la raíz del backend)
npm run import:gtfs

# 5. Arrancar en desarrollo (watch) o producción
npm run start:dev
# o
npm run build && npm run start:prod
```

La API queda en `http://localhost:3000/api/v1` y la documentación en `http://localhost:3000/docs`.

> **Nota de puertos:** el 5432 puede estar ocupado por otro contenedor; por eso el compose
> publica Postgres en el **5436** (`DB_PORT=5436` en `.env` y `docker-compose.yml`).

### Motor de ruteo OpenTripPlanner (opcional pero recomendado)

Sin OTP2 el planeador funciona igual (planner propio sobre PostGIS) pero las
**caminatas se dibujan en línea recta**, atravesando manzanas. Con OTP2
(GTFS + OSM) las caminatas siguen la red viaria real:

```bash
# Copiar los datos de entrada (gtfs.zip + extracto OSM de Bolivia)
cd otp-data && cp ../gtfs.zip gtfs.zip \
  && curl -L https://download.geofabrik.de/south-america/bolivia-latest.osm.pbf -o bolivia-latest.osm.pbf && cd ..

# Compilar el grafo (una vez; ~1-5 min, queda en otp-data/graph.obj)
docker compose run --rm otp --build --save

# Levantar el motor (GraphQL en http://localhost:8081, puerto host 8081)
docker compose up -d otp
```

`OTP_URL` en `.env` (default vacío = planner interno) apunta a
`http://localhost:8081/otp/routers/default`. Si OTP no responde,
`JourneyService` degrada automáticamente al planner interno. Ver
[`otp-data/README.md`](otp-data/README.md).

## Scripts

| Comando | Descripción |
| --- | --- |
| `npm run build` | Compila a `dist/` |
| `npm run start:dev` | Servidor en modo watch |
| `npm run start:prod` | Servidor desde `dist/` |
| `npm run import:gtfs` | Importa `gtfs.zip` (TRUNCATE + bulk insert en una transacción) |
| `npm test` | Tests unitarios (Jest) |
| `npm run test:e2e` | Tests e2e (`/routes`, `/stops/nearby`) contra la BD real |
| `npm run lint` | ESLint |

## Endpoints principales

Todos responden envuelto en `{ "data": ..., "meta": ... }` (errores: `{ "error": { "statusCode", "message", "details" } }`),
excepto `GET /health`.

| Endpoint | Descripción |
| --- | --- |
| `GET /health` | Estado de la API y la BD (sin envoltorio) |
| `GET /stats` | Conteo de rutas, paradas, viajes, shape points, ventana de servicio |
| `GET /routes?q=&page=&limit=` | Lista/búsqueda de rutas |
| `GET /routes/:id?directionId=` | Detalle con `bbox`, direcciones y shape GeoJSON (`Feature`/`LineString`) |
| `GET /routes/:id/stops?directionId=` | Paradas ordenadas de la ruta en una dirección |
| `GET /routes/:id/departures?stopId=&time=HH:mm` | Próximas salidas (máx. 20, headway). `stopId` opcional: sin él, salidas desde el inicio del recorrido |
| `GET /stops/nearby?lat=&lon=&radius=&limit=` | Paradas cercanas (PostGIS, orden por distancia) |
| `GET /stops/search?q=&limit=` | Búsqueda de paradas por nombre |
| `GET /stops/:id` | Detalle de parada con rutas que la sirven + `location` GeoJSON |
| `GET /trips/:id` | Viaje con sus `stopTimes` (`HH:mm:ss`) |
| `GET /journey?originLat=&originLon=&destLat=&destLon=&time=HH:mm` | Opciones directas o con 1 transbordo, **con geometría de mapa**: cada tramo de bus incluye `geometry` (LineString `[lon,lat]` del shape recortado entre sus paradas, `null` si no hay shape), `fromStop`/`toStop` y `walkToStop`/`walkFromStop` con `lat`/`lon` |

### Ejemplos

```bash
curl 'http://localhost:3000/api/v1/health'
curl 'http://localhost:3000/api/v1/routes?q=101'
curl 'http://localhost:3000/api/v1/routes/101%20ANGOSTURA?directionId=0'
curl 'http://localhost:3000/api/v1/stops/nearby?lat=-17.78&lon=-63.15&radius=500'
curl 'http://localhost:3000/api/v1/journey?originLat=-17.78&originLon=-63.15&destLat=-17.80&destLon=-63.18&time=06:00'
```

## Configuración (`.env`)

| Variable | Descripción | Default |
| --- | --- | --- |
| `PORT` | Puerto HTTP | `3000` |
| `DB_HOST` / `DB_PORT` / `DB_NAME` / `DB_USER` / `DB_PASSWORD` | Conexión Postgres | ver `.env.example` |
| `DB_SYNCHRONIZE` | Sincroniza esquema al arrancar (solo dev) | `true` |
| `CORS_ORIGINS` | Origenes permitidos (coma-separado) | `*` |
| `CACHE_TTL_MS` | TTL de caché en memoria | `60000` |
| `LOG_LEVEL` | Nivel de logging | `info` |
| `GTFS_PATH` | Ruta del zip GTFS para el importador | `gtfs.zip` |

## Arquitectura

Arquitectura hexagonal liviana por feature:

```
src/
├── main.ts              # bootstrap (Swagger, listen)
├── app.setup.ts         # configuración global compartida (prefijo, CORS, filtros, interceptores)
├── app.module.ts
├── core/                # config, common (filtros/interceptores/utilidades), infrastructure (entidades, TypeORM, índices)
└── modules/
    ├── gtfs-import/     # lector zip + importador (CLI)
    ├── routes/ stops/ trips/ journey/ stats/ health/
    └── ...              # domain (lógica pura) / application (puertos) / infrastructure (repos) / presentation (controllers)
```

- Los **controllers** solo validan y delegan a servicios.
- Los **servicios** dependen de **puertos** (interfaces con tokens de inyección);
  las implementaciones TypeORM/PostGIS viven en `infrastructure/`.
- La lógica con reglas de negocio (planeador de viaje, próximas salidas) es **pura** y
  está unitariamente testeada.
- Índices GIST (geografía), B-tree y GIN `pg_trgm` se crean idempotentemente al arrancar
  (`DatabaseSetupService`).

## Datos GTFS

- Feed en `backend/gtfs.zip` (copia de `/tmp/opencode/gtfs/`).
- El importador hace `TRUNCATE` + inserción por lotes (~5000 filas) **en una sola
  transacción** e imprime un resumen de conteos.
- Horarios en `HH:mm:ss` (GTFS), zona `America/La_Paz`; servicio `DIARIO`.
- Colores hex **sin** `#`; GeoJSON en orden `[lon, lat]`.
