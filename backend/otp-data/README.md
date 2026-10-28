# OpenTripPlanner 2 (OTP2) — motor de ruteo con red viaria

OTP2 combina el feed GTFS de Urbano con **datos OSM** para producir
itinerarios puerta a puerta donde las caminatas siguen la red de calles
(veredas, pasos peatonales, plazas), en vez de líneas rectas.

## Datos (no versionados)

- `gtfs.zip`: copia del zip que usa `npm run import:gtfs` (siempre debe
  llamarse con "gtfs" y terminar en `.zip`; así lo exige OTP).
- `bolivia-latest.osm.pbf`: extracto OSM de Bolivia ([Geofabrik](https://download.geofabrik.de/south-america/bolivia.html), ~170 MB).
- `graph.obj`: grafo compilado de OTP.

```bash
cd otp-data
cp ../gtfs.zip gtfs.zip
curl -L https://download.geofabrik.de/south-america/bolivia-latest.osm.pbf -o bolivia-latest.osm.pbf
```

`gtfs.zip` es copia del feed **ya reparado** (`npm run fix:gtfs-directions` corrige las vueltas
duplicadas en el mismo orden de la ida; ver `docs/gtfs-dataset.md`). Si se repara o se actualiza el
feed, hay que volver a copiarlo aquí y re-compiler el grafo: OTP congela las direcciones en
`graph.obj`, así que sin rebuild seguirá sin ofrecer esas rutas.

## Compilar el grafo (una vez, o al actualizar datos)

```bash
cd backend
docker compose run --rm otp --build --save
```

Con 6 GB de heap el build de Bolivia toma ~1,5 min en un equipo reciente. Guarda `graph.obj`
en esta carpeta y luego `docker compose up -d otp` lo carga directamente. Conviene parar el
servicio (`docker compose stop otp`) antes de compilar para no sumar dos JVM de 6 GB.

## Correr

```bash
docker compose up -d otp   # API GraphQL en http://localhost:8081/otp
```

Abrir http://localhost:8081/graphiql para probar queries.

## Consumo

El backend lo consulta vía `OTP_URL` (ver `.env.example`). Si OTP2 no está
disponible, `JourneyService` degrada automáticamente al planner interno
sobre PostGIS (caminatas en línea recta) — el endpoint nunca se rompe.
