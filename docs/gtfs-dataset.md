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

## Defecto de dirección en el feed original (reparado)

El feed crudo venía con **13 rutas cuya vuelta (`direction_id=1`) era una copia en el mismo
orden de la ida**, no su espejo: tanto `stop_times.txt` como `shapes.txt` recorrían la línea
en el mismo sentido en las dos direcciones. Efecto práctico: esas rutas no podían usarse en
el sentido origen→destino, así que OTP y el planner interno (que exige `seq(destino) > seq(origen)`)
nunca las ofrecían. Es el caso de la 75 entre Av. Roque Aguilera y Av. República del Japón.

Se corrigió con `npm run fix:gtfs-directions` (ver `backend/src/modules/gtfs-import/gtfs-direction-fixer.ts`),
que invierte `stop_times` y `shapes` del viaje de vuelta reflejando horarios y distancias. Rutas reparadas:

`2`, `13`, `20`, `75`, `111`, `115`, `119 AZUL`, `123`, `129`, `140 AZUL`, `140 ROJO`, `85 FORTALEZA`, `96 AMARILLO`

Quedaron **sin tocar** por evidencia insuficiente (el detector los marca como ambiguos, no como defecto claro):
`3`, `19`, `79`, `80`. Si algún día se confirma su sentido en la calle, basta reejecutar la CLI y sumarlos con `--routes`.

- El zip original está respaldado en `backend/gtfs.orig.zip`; `gtfs.zip` (raíz), `backend/gtfs.zip` y
  `backend/otp-data/gtfs.zip` deben quedar siempre con el mismo md5 (el reparado).
- Tras reparar hay que re-importar (`npm run import:gtfs`) **y** reconstruir el grafo de OTP
  (`docker compose run --rm otp --build --save`), porque OTP compila las direcciones en `graph.obj`.
- Los conteos de la tabla anterior no cambian con la reparación: solo se reordenan filas.
