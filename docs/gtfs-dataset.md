# Dataset GTFS — Micros Santa Cruz

Fuente: `gtfs.zip` (feed v1.0, publicado por "Micros Santa Cruz", idioma `es`, zona horaria `America/La_Paz`).

## Contenido por archivo

| Archivo         | Filas   | Notas                                                                          |
| --------------- | ------- | ------------------------------------------------------------------------------ |
| agency.txt      | 1       | `MICROS` — Micros Santa Cruz                                                   |
| calendar.txt    | 1       | Servicio `DIARIO`, 1 todos los días, `20261006` → `20271006`                   |
| feed_info.txt   | 1       | Versión `1.0`, ventana `20261006` → `20271006`                                 |
| routes.txt      | 154     | Todas `route_type=3` (bus), con `route_color`/`route_text_color`               |
| trips.txt       | 308     | 154 rutas × 2 direcciones (`direction_id` 0 = Ida, 1 = Vuelta)                 |
| stops.txt       | 31.461  | Sin `parent_station` ni `stop_code`; nombre estilo `"CALLE esquina CALLE"`     |
| stop_times.txt  | 78.277  | Entre 66 y 603 paradas por viaje                                               |
| shapes.txt      | 130.105 | Puntos de polilínea por `shape_id` (uno por trip)                              |
| frequencies.txt | 308     | Todas: `06:00:00`–`22:00:00`, `headway_secs=300` (cada 5 min), `exact_times=1` |

## Geografía

- Latitud: `-18.161764` → `-17.339782`
- Longitud: `-63.505770` → `-62.993998`
- Cobertura: ciudad de Santa Cruz de la Sierra y corredores hacia localidades satélite.

## Observaciones para el producto

- **47 rutas llevan sufijo de destino** (variantes): `101 ANGOSTURA`, `104 C`, `104 ROJO`, `105 VERDE`,
  `119 AZUL`, `131 COTOCA`, `132 MONTERO`, `133 EL TORNO`, `133 LA GUARDIA`, etc. Conviene mostrarlas
  como "variante" y agruparlas visualmente con la ruta base (ej. `104`).
- **Solo 18 colores distintos** para 154 rutas → el color NO identifica una ruta por sí solo; en la UI
  el color es acento, y la identidad principal es `route_short_name`.
- Todas las rutas tienen exactamente 2 viajes (ida/vuelta) y horario por frecuencia: no hay calendarios
  por día distinto, así que "próximas salidas" se calcula desde `frequencies` (06:00–22:00, cada 5 min).
- Sin `stop_code` → la búsqueda de paradas debe hacerse por nombre, no por código.

## Defectos de dirección del feed original (reparados)

El feed crudo traía **dos defectos distintos** que se veían igual en la app ("el micro va en
sentido contrario"). Se reparan en ese orden con `npm run fix:gtfs-directions`
(`backend/src/modules/gtfs-import/fix-directions.cli.ts`).

### 1. Vuelta copiada en el orden de la ida

**13 rutas** tenían la vuelta (`direction_id=1`) como copia en el mismo orden de la ida, no su
espejo: tanto `stop_times.txt` como `shapes.txt` recorrían la línea en el mismo sentido en las dos
direcciones. Efecto práctico: esas rutas no podían usarse en el sentido origen→destino, así que
OTP y el planner interno (que exige `seq(destino) > seq(origen)`) nunca las ofrecían.

El CLI detecta la duplicación comparando la ida con la vuelta (mismo orden vs. espejo) y **solo
invierte `stop_times.txt`** del viaje de vuelta. Ya no invierte el `shape`: invertir el orden de
puntos no cambia de calzada (ver defecto 2).

Rutas reparadas: `2`, `13`, `20`, `75`, `111`, `115`, `119 AZUL`, `123`, `129`, `140 AZUL`,
`140 ROJO`, `85 FORTALEZA`, `96 AMARILLO`.

Quedaron **sin tocar** por evidencia insuficiente (el detector los marca como ambiguos, no como
defecto claro): `3`, `19`, `79`, `80`. Si algún día se confirma su sentido en la calle, basta
reejecutar la CLI y sumarlos con `--routes`.

### 2. `shape` de la calzada contraria (contraflecha)

**18 rutas** traían el `shape` de la ida asignado a la vuelta y viceversa. El trazado no estaba
"al revés" (una polilínea sin flechas se ve igual en ambos sentidos): estaba dibujado sobre la
**calzada del sentido opuesto**. En una avenida de doble calzada eso se lee como que el micro
circula en contravía, aunque sus paradas y horarios sean correctos.

Comparar los dos `shape` entre sí no sirve para detectarlo: si están intercambiados, el par de
geometrías es el mismo y cualquier métrica relativa da idéntico resultado antes y después del
intercambio. La única verdad de campo es el sentido de circulación de la calle, así que el CLI
puntúa las dos asignaciones contra los `oneway` de OSM y acepta el intercambio solo si el sentido
peor de la ruta mejora ≥20 puntos y queda en ≥60 %. Es idempotente: sobre un feed ya reparado la
asignación actual gana y no se toca nada.

Rutas con los shapes intercambiados: `2`, `13`, `20`, `27 AZUL`, `29`, `37`, `75`, `85 FORTALEZA`,
`87`, `88 AMARILLO`, `103`, `115`, `119 AZUL`, `121`, `123`, `129`, `133 EL TORNO`, `140 AZUL`.

El extracto de OSM se genera una sola vez y no se versiona:

```bash
cd backend/otp-data
osmium extract -b -63.35,-17.95,-63.05,-17.60 bolivia-latest.osm.pbf -o city.pbf
osmium export -f geojson city.pbf -o /tmp/city.geojson
cd ..
npm run fix:gtfs-directions -- --osm /tmp/city.geojson           # dry-run
npm run fix:gtfs-directions -- --apply --osm /tmp/city.geojson   # reescribe gtfs.zip
```

Sin `--osm` el paso 2 se omite con un aviso (no se puede decidir el lado de calzada) y solo se
aplica el paso 1. El detector vive en `backend/src/modules/gtfs-import/gtfs-shape-side.ts`
(lógica pura, con tests sintéticos en `gtfs-shape-side.spec.ts`).

### Después de reparar

- El zip original está respaldado en `backend/gtfs.orig.zip`; `gtfs.zip` (raíz), `backend/gtfs.zip`
  y `backend/otp-data/gtfs.zip` deben quedar siempre con el mismo md5 (el reparado).
- Reimportar (`npm run import:gtfs`) **y**, si se usa OTP, reconstruir su grafo
  (`docker compose run --rm otp --build --save`), porque OTP compila los shapes en `graph.obj`.
- En producción (Vercel) no hay OTP: el trazado sale de la base PostGIS, así que basta la
  reimportación contra la base de Alwaysdata (`DB_HOST` de `backend/.env`).
- Los conteos de la tabla anterior no cambian con la reparación: solo se reordenan filas y se
  reasigna `trips.txt → shape_id`.
