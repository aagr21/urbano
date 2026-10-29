# Urbano API — Contrato v1

Base: `http://localhost:3000/api/v1`
Formato: JSON. Codificación UTF-8. Todas las respuestas exitosas usan envoltorio:

```json
{ "data": <payload>, "meta": { "page": 1, "limit": 20, "total": 154 } }
```

Errores:

```json
{ "error": { "statusCode": 404, "message": "Route 999 not found", "details": null } }
```

Colores hex **sin** `#` (ej: `D35400`), tal como vienen en GTFS.

---

## Endpoints

### Health
- `GET /health` → `{ status: "ok", db: "up", uptime: 123.4, version: "1.0.0" }` (sin envoltorio)

### Meta (contrato de dataset + invariantes)
- `GET /meta` → identidad del feed importado (vía `feed_info.txt`) y LOS
  INVARIANTES que la app debe respetar como cliente (cuando cambie un
  `limits`, es cambio de contrato, no tuning):
```json
{ "data": {
    "feed": { "version": "1.0", "publisher": "Micros Santa Cruz",
               "lang": "es", "startDate": "20261006", "endDate": "20271006" },
    "limits": { "maxResults": 10, "walkRadiusM": 500, "maxCandidateStops": 15,
                "minTransitDistanceM": 150, "minBoardingPairDistanceM": 150,
                "walkSpeedMPerMin": 80, "transferPenaltyMinutes": 10 } } }
```
- Fuente única de verdad: `src/modules/journey/domain/journey-limits.ts`
  (`@Max(10)` del DTO y las constantes del planner/service NO se duplican
  — todas derivan de ahí).

### Stats (para home/dashboard)
- `GET /stats` →
```json
{ "routes": 154, "stops": 31461, "trips": 308, "shapes": 130105,
  "service": { "start": "2026-10-06", "end": "2027-10-06", "days": "diario" },
  "firstDeparture": "06:00:00", "lastDeparture": "22:00:00", "headwaySeconds": 300 }
```

### Routes
- `GET /routes?q=&page=1&limit=20&sort=name`
  - `q`: búsqueda insensible a mayúsculas sobre `short_name`, `long_name`.
  - Item (`RouteSummary`):
```json
{ "id": "101 ANGOSTURA", "shortName": "101 ANGOSTURA", "longName": "Micro 101 ANGOSTURA",
  "color": "7F8C8D", "textColor": "FFFFFF", "description": "Transporte publico urbano de micros",
  "type": 3, "directions": 2, "stopCount": 84, "tripCount": 2,
  "imageUrl": "https://lh3.googleusercontent.com/d/…=w1000|null" }
```
  - `imageUrl`: imagen del itinerario (opcional, desde `backend/micros.csv`; la columna `name` casa con `route_short_name`). Puede ser `null`.
- `GET /routes/:id` → `RouteDetail` = RouteSummary + :
```json
{ "bbox": [-63.35, -17.85, -63.05, -17.70],
  "directions": [ { "directionId": 0, "headsign": "Ida", "tripId": "T97",
                    "firstDeparture": "06:00:00", "lastDeparture": "22:00:00",
                    "headwaySeconds": 300, "stopCount": 42 } ],
  "shape": { "type": "Feature", "properties": { "id": "SH97" },
             "geometry": { "type": "LineString", "coordinates": [[lon, lat], ...] } } }
```
  - `shape` = primera dirección (directionId 0 si existe). Usar `?directionId=1` para la otra.
- `GET /routes/:id/stops?directionId=0` → lista ordenada de `StopSummary`:
```json
{ "id": "S16309", "code": null, "name": "12 DE OCTUBRE esquina Calle 3",
  "lat": -17.78, "lon": -63.16, "sequence": 1, "arrivalTime": "06:00:00",
  "departureTime": "06:00:00", "distanceMeters": 0 }
```
- `GET /routes/:id/departures?stopId=&directionId=&time=HH:mm&date=YYYY-MM-DD`
  → próximas salidas dentro de la ventana de servicio (06:00–22:00, headway 300 s):
```json
[ { "tripId": "T97", "directionId": 0, "headsign": "Ida", "time": "06:07:18",
    "realTime": false, "headwaySeconds": 300 } ]
```
  - `stopId` **opcional**: con él calcula la salida en esa parada; **sin él**
    devuelve las salidas desde el inicio del recorrido de cada viaje de la ruta
    (es lo que usa la pantalla de detalle de ruta).
  - Máximo 20 resultados; si `time` no se pasa, usa la hora actual (America/La_Paz).

### Stops

> **Nota (app móvil):** la app Flutter no consume `/stops/:id`; SÍ consume
> `/routes/:id/stops` («Pasa por», detalle) y ahora `/stops/search` y
> `/stops/nearby`: el modo **Lugares** del panel de micros
> («¿qué línea pasa por aquí?» + cercanía por GPS).

- `GET /stops/nearby?lat=&lon=&radius=400&limit=10`
  - `radius` en metros, máx 2000. Orden por distancia. Incluye rutas que sirven la parada:
```json
{ "id": "S1", "name": "RN7: La Guardia-Samaipata", "code": null, "lat": -18.161764,
  "lon": -63.50577, "distanceMeters": 123.4,
  "routes": [ { "id": "133 LA GUARDIA", "shortName": "133 LA GUARDIA", "color": "3498DB" } ] }
```
- `GET /stops/search?q=&limit=10` → `StopSummary[]` + rutas (mismo shape que nearby sin `distanceMeters`).
- `GET /stops/:id` → `{ ...StopSummary, "routes": [...], "location": { "type": "Point", "coordinates": [lon, lat] } }`

### Trips / horarios
- `GET /trips/:id` →
```json
{ "id": "T97", "routeId": "133 LA GUARDIA", "routeShortName": "133 LA GUARDIA",
  "routeColor": "3498DB", "directionId": 0, "headsign": "Ida", "serviceId": "DIARIO",
  "stopTimes": [ { "stopId": "S1", "name": "RN7: La Guardia-Samaipata", "sequence": 1,
                   "arrivalTime": "06:00:00", "departureTime": "06:00:00",
                   "distanceMeters": 0, "pickupAllowed": true, "dropOffAllowed": true } ] }
```

### Journey (planeador de viaje)
- `GET /journey?originLat=&originLon=&destLat=&destLon=&time=HH:mm&maxResults=3`
  - Busca paradas a ≤500 m de origen y destino, encuentra rutas directas (misma ruta sirve ambas
    en el mismo sentido) y opciones con 1 transbordo en parada intermedia común.
  - Respuesta:
```json
{ "options": [
  { "type": "direct", "departAt": "06:03:00", "arriveAt": "06:41:00", "durationMinutes": 38,
    "walkToStop": { "id": "S10", "name": "...", "distanceMeters": 80, "lat": -17.78, "lon": -63.15 },
    "walkFromStop": { "id": "S200", "name": "...", "distanceMeters": 120, "lat": -17.79, "lon": -63.16 },
    "legs": [ { "kind": "walk", "durationMinutes": 2, "distanceMeters": 80 },
              { "kind": "bus", "routeId": "1", "routeShortName": "1", "routeColor": "D35400",
                "tripId": "T1", "fromStopId": "S10", "toStopId": "S200",
                "departAt": "06:03:00", "arriveAt": "06:39:00", "stops": 12,
                "fromStop": { "id": "S10", "name": "...", "lat": -17.78, "lon": -63.15 },
                "toStop":   { "id": "S200", "name": "...", "lat": -17.79, "lon": -63.16 },
                "geometry": { "type": "LineString",
                              "coordinates": [[-63.15, -17.78], [-63.152, -17.781], ...] } },
              { "kind": "walk", "durationMinutes": 3, "distanceMeters": 120 } ] },
  { "type": "transfer", "...": "misma forma + legs con 2 tramos de bus y 1 transbordo" } ] }
```
  - `type`: `"direct" | "transfer"`. Ordenado por `durationMinutes` asc.
  - **Mapa**: `geometry` es el tramo EXACTO del shape recortado entre
    `fromStop` y `toStop` (PostGIS `ST_LineSubstring`), en `[lon, lat]` — el
    cliente solo dibuja. `fromStop`/`toStop` llevan `lat`/`lon` para marcadores
    (el paradero de transbordo es el `toStop` de un leg = `fromStop` del
    siguiente). Los tramos de caminata se dibujan como línea recta entre el
    punto del usuario (query) y `walkToStop`/`walkFromStop` (ahora con
    `lat`/`lon`). `geometry` puede ser `null` si la ruta no tiene shape.
  - **Motor OTP2 (caminatas por la red viaria)**: si `OTP_URL` está seteado y
    el motor OpenTripPlanner (GTFS + OSM) responde, las `options` salen de él
    y los tramos de caminata (`kind: "walk"`) vienen con:
    - `geometry`: `LineString` real de la red de calles/aceras (`[lon, lat]`).
    - `fromStop`/`toStop` (opcional): `StopRef` de los extremos cuando la
      caminata acaba en una parada (degradación a recta en el cliente).
    - `distanceMeters`/`durationMinutes` medidos sobre la red (no cuerda
      aérea). El planner interno queda como fallback automático si OTP2 no
    responde; en ese caso los walks no llevan `geometry` y el cliente dibuja
    la recta entre `origin → walkToStop` y `walkFromStop → destination`.

### Notas
- Todos los horarios en formato `HH:mm:ss` (GTFS), zona `America/La_Paz`.
- Servicio: `DIARIO` de `2026-10-06` a `2027-10-06`.
- Paginación: `meta.total` siempre presente en listados.
- CORS habilitado, Swagger en `GET /docs`.
