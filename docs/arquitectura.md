# 🏗️ Arquitectura

> Detalle técnico interno. El [README](../README.md) es la vitrina;
> aquí vive el cómo: decisiones de diseño, motor del mapa y pruebas de arrastre.

## 🗂️ Estructura

```
lib/
  main.dart
  src/
    app.dart                     # MaterialApp.router + tema claro/oscuro
    core/
      config/env.dart            # API_BASE_URL por dart-define
      theme/                     # app_colors, typography, app_theme (tokens)
                                 # y theme_mode_controller (modo seleccionable
                                 # sistema/claro/oscuro, persiste en prefs)
      network/                   # api_client (dio), api_exception, endpoints
      router/app_router.dart     # go_router + shell con 2 tabs
                                 # (Inicio · Viaje);
                                 # /map redirige a /journey
      map/                       # abstracción de motor de mapa:
                                 # map_types (cámara/líneas/marcadores), proyección
                                 # Web Mercator, estilos, MapLibreEngine (real),
                                 # FakeMapEngine (tests), rasterizador de iconos
      location/                  # flujo de ubicación real: LocationService
                                 # (inyectable, geolocator), LocationController
                                 # (estados del sistema) y LocationFab
      animation/                 # kit de motion: Motion (tokens + reduce-motion),
                                 # PressScale, Reveal (entrada en cascada),
                                 # CountUp y UrbanoPageTransitions
      widgets/                   # RouteBadge, SectionHeader, EmptyState,
                                 # ErrorView, LoadingShimmer, GlassCard, StatPill,
                                 # FilterBottomSheet, AsyncValueView, UrbanoMap…
      utils/                     # GTFS HH:mm:ss, debouncer, cache, ext.
                                 # (utils/location.dart re-exporta core/location)
    features/
      home/      # header+buscador (rutas), stats, accesos, populares, mapa
      routes/    # modelos/repos (detalle, shape, direcciones, salidas), detail
                 # (el listado vive en el panel de micros de /journey)
      journey/   # pantalla-mapa única (planeador + exploración): selector de
                 # punto en el mapa (GPS o punto marcado), mapa de resultados
                 # (geometry de /journey), timeline y capas
      info/      # fuente GTFS, versión del API, créditos
test/           # models, formatters, api_client, widget_test (Home mockeado),
                # map_picker_screen_test, journey_result_map_test y
                # location_flow_test (sin red)
```

## 🎨 Decisiones de diseño


### 🎨 Identidad
Azul/turquesa `#0EA5E9`/`#0284C7` + acento ámbar `#F59E0B`,
neutros slate; semillas del `ColorScheme` en `app_theme.dart`.

### ✍️ Tipografía
Plus Jakarta Sans (títulos) + Inter (cuerpo), vía `google_fonts`.
Radios 16–24, sombras suaves, escala de espaciado 4/8, M3.

### 🆓 Sin Google Maps
Motor **`maplibre_gl` 0.27.1** con tiles sin API keys
(tema claro: estilo vectorial OpenFreeMap _Positron_; tema oscuro: estilo
JSON inline con raster de CARTO), GPS con `geolocator`, microinteracciones
con el kit propio de motion (`core/animation/motion.dart`).

### 🖼️ Una sola pantalla-mapa
Viaje y el antiguo Mapa se fusionaron en
`/journey`, un mapa a pantalla completa siempre montado (un único
`JourneyResultMap`, sin destruir la vista de plataforma al planificar).
Dos pestañas (Inicio · Viaje); `/map` redirige a `/journey`. Sobre el mapa, una píldora inferior resume el viaje y abre/cierra
(con animación de despliegue) el **panel de origen→destino**: línea de tiempo
con botón de intercambio, hora y "Planificar". El panel arranca cerrado para
no tapar el mapa y se cierra solo al planificar, dejando la hoja arrastrable
de resultados (0.18/0.45/0.85) con leyenda y opciones. Columna de controles a
la derecha (zoom, ubicación, capas). Sin resultados el mapa queda en
modo exploración (solo pines de origen/destino); las **paradas como feature
se retiraron de la app** (sin marcadores de paradas, hoja de parada, pestaña
"Cerca" ni búsqueda por parada).

### 🧭 Ubicación con estado real
 `core/location/` aísla `geolocator` tras un
`LocationService` inyectable (testable sin plugin) y expone un
`LocationController` (Riverpod) que distingue `serviceOff`,
`permissionPending`, `permissionBlocked` y `ready`. El controlador escucha
el stream de servicio del sistema (el botón cambia solo si el usuario
apaga/enciende el GPS), re-consulta el permiso al reanudar la app
(`WidgetsBindingObserver`) y `activate(context)` orquesta el flujo:
diálogo de GPS apagado → ajustes del sistema; denegado → solicitud;
bloqueado → ajustes de la app. `LocationFab` traduce cada estado a
icono/color/tooltip y se reutiliza en la pantalla fusionada y en el
selector de punto.

### 🧮 La vista de resultados del planeador (`journey_results_view.dart`)

El "modo resultados" de `/journey` — qué consulta está vigente, qué opciones
mostrar sin parpadear durante un recálculo y qué pinta el mapa — vive en un
módulo con UN punto de entrada: `journeyResultsProvider`, que emite una
proyección inmutable `JourneyResultsView` (query, options, hasResults, bare,
replanning, refreshFailed, selectedIndex, mapOption, mapOrigin/destination).

- La pantalla ya no reconstruye `JourneyQuery` a mano ni muta caché dentro de
  `build`: el `Notifier` de la vista watchea al controller del planeador y a
  la consulta (`journeyProvider` family, que no se mueve) y deriva todo.
- La regla de frescura del caché es la parte más sutil y por eso es text:
  el caché se refresca SOLO con respuesta de la consulta ACTUAL; cambiar
  extremo/hora/swap/limpiar pone `submitted: false` en el controller → la
  consulta muere → el caché muere con ella (antes era un
  `_discardCachedOptions()` explícito en 5 call sites de la pantalla).
- El mapa prefiere los CAMPOS sobre los planificados: durante un arrastre
  de pin el pin sigue al dedo mientras la hoja sigue mostrando el viaje
  anterior.
- La pantalla mantiene exclusivamente lo UI: `_panelOpen`, `_sheetExtent`,
  `GlobalKey` del mapa y callbacks.

Queda con especificación unitaria en `test/journey_results_view_test.dart`
(12 casos: exploración, adopción, drag con caché conservado, replan
comprometido, descarte por extremo/hora/swap/clear, clamp de selección,
fallo con y sin caché, reintento) — sin widgets ni red.

### 📍 Viaje en el mapa
El selector de origen/destino usa un pin **fijo en el
centro** (patrón Uber: se mueve el mapa, no el pin; la coordenada elegida es
siempre el centro) y devolución vía `context.push<JourneyPoint>`; los
resultados se dibujan con la `geometry` de `/journey` (línea recta si la
ruta no tiene shape), caminatas punteadas, insignias de ruta y pines de
origen/destino arrastrables.
Para que el punto sea inequívoco, el selector muestra bajo el pin un chip
**`Punto: <lat>, <lon>` (5 decimales ≈ 1 m)** que refleja exactamente el
valor que se devuelve: se actualiza en vivo mientras la cámara se mueve
(ValueNotifier) y `Usar este punto` lee la cámara **viva**
al confirmar, de modo que lo guardado nunca puede diferir de lo que se ve.
Un `Listener` marca cualquier toque del mapa para que el auto-centrado por
GPS inicial nunca le gane a un gesto ya hecho del usuario.
### 🤝 Errores amigables
En todas las pantallas (`AsyncValueView` centraliza carga/vacío/error +
reintento); el backend caído degrada con estados bonitos.
### 🎬 Lenguaje de movimiento
(`core/animation/motion.dart`): la app no es estática, pero tampoco de circo —
primitivas sobrias y reutilizables.
`PressScale` hunde ligeramente lo que se pulsa (tarjetas de opciones, accesos del
home, controles circulares del mapa) con 110 ms de bajada y 240 ms de retorno;
`Reveal` hace entrar listas y secciones en cascada (opacidad + desplazamiento,
80 ms de retardo por `index`, tope en 10 filas para que una lista larga no espere
segundos); `CountUp` sube los números de las estadísticas del home; y el trío
`Ambient` / `Bob` / `LiveDot` es el **movimiento ambiente**: lo que se mueve solo,
sin que el usuario toque nada. Las páginas
entran con `UrbanoPageTransitions` (fundido + 5 % de desplazamiento + micro-escala),
y **Android conserva el «atrás predictivo» de la plataforma**: su gesto _es_ la
animación, pisarlo habría sido un retroceso.
Todo es `Ticker`-driven (sin `Timer`, para no romper tests con `pump()`), respeta
`MediaQuery.disableAnimations` del sistema, y ninguna animación es infinita: si el
contenido ya está en pantalla, el movimiento desaparece. Los tokens (`Motion.quick`
/ `base` / `slow`, curvas `easeOutCubic` de salida y `easeOutQuint` de entrada) viven
en un solo lugar para que la app se mueva igual en todas partes.
Cuatro detalles con firma propia: el **header tiene ciudad** — `HomeRouteLattice`
pinta los anillos concéntricos de Santa Cruz con sus paradas y una unidad que
recorre su corredor y sale del lienzo (no es un GIF: un solo `CustomPainter`), el
**esqueleto se convierte en contenido** (`AsyncValueView` revela los datos al irse el
shimmer, en todas las pantallas) mientras la **barra de búsqueda barre** el corredor
del planeador, los **rieles del tramo se dibujan solos** al expandir una opción (con
el color de la línea del GTFS, y cambian de color en el transbordo) y la **insignia
de la ruta vuela** de la lista a la AppBar del detalle (Hero, con el prefijo
viajando en la URL para que las ramas del shell no choquen). Además el **logo llega
andando** y la insignia del panel de micros **flota** mientras haya recorridos
dibujados. Está bajo prueba en `test/app_motion_test.dart`.
## 🗺️ Motor del mapa (`lib/src/core/map/`)

El mapa se abstrae detrás de la fachada `UrbanoMap`
(`core/widgets/urbano_map.dart`), que arma un `MapScene` y se lo pasa al
motor activo:

| Archivo                                            | Rol                                                                                                                                                                                              |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `map_types.dart`                                   | Tipos compartidos (`MapCamera`, `MapBounds`, `MapCameraFit`, `MapPolyline`, `MapMarker`, fases de drag). **`latlong2.LatLng` sigue siendo el tipo de coordenadas** (modelos y tests no cambian). |
| `map_scene.dart`                                   | Qué dibujar + callbacks que el motor reenvía (taps, cámara, drags).                                                                                                                              |
| `map_projection.dart`                              | Web Mercator en Dart: proyección, inversa y `fitBounds` (encuadre idéntico en ambos motores).                                                                                                    |
| `map_controller.dart`                              | `UrbanoMapController` + `MapEngineHost`: zoom, `move`, `fitBounds`, `moveMarker` sin hablar con el plugin.                                                                                       |
| `maplibre_engine.dart`                             | **Motor real** (`maplibre_gl`): estilos por tema, `Line`/`Symbol` nativos, drag nativo de anotaciones, puck de ubicación.                                                                        |
| `fake_map_engine.dart`                             | **Motor simulado** (puro Flutter): fondos de tema + polilíneas proyectadas + widgets de marcador.                                                                                                |
| `marker_rasterizer.dart`                           | Convierte el `child` de un `MapMarker` a PNG (`RepaintBoundary` → `addImage`), cacheado por `iconKey`.                                                                                           |
| `map_styles.dart` / `map_engine_environment*.dart` | URLs/JSON de estilos y detección de `flutter test`.                                                                                                                                              |

**Cuándo se usa cada motor**: el real con `showTiles: true` fuera de tests;
el simulado con `showTiles: false` **o** siempre dentro de `flutter test`
(detecta `FLUTTER_TEST`, así ningún test necesita plugin nativo ni red).

**Atribución**: el motor real muestra el control nativo de MapLibre (lee la
atribución del estilo: © OpenStreetMap · OpenFreeMap en claro, © OpenStreetMap
· © CARTO en oscuro); esa API no permite desactivarlo, así que la píldora de
atribución dibujada por la fachada aparece solo con el motor simulado.

### 🕹️ Controles y arrastre

- **Controles**: zoom +/− en la columna derecha de la pantalla fusionada, el
  botón de **pantalla completa** (`fullscreen_rounded`, oculta paneles flotantes
  y barra del shell dejando solo el mapa), el botón de
  **micros** (abre un **panel lateral que se desliza desde la izquierda** con
  el listado completo de líneas: buscador por numeral/nombre, insignias de
  color y botones **Ida** / **Vuelta** por línea para dibujar cada sentido como
  capa independiente). El panel **recuerda lo hecho mientras la app esté
  abierta** —búsqueda, posición del scroll, líneas ya descargadas y headsign
  consultados viven en `journeyMicrosSessionProvider`—, así que cerrarlo y
  reabrirlo devuelve el mismo estado al instante (sin volver a pagar `/routes`;
  "jalar para actualizar" fuerza la recarga) y tirar de él hacia la izquierda lo
  cierra) y `LocationFab`
  (seguimiento de ubicación con `myLocationEnabled` + `followMyLocation` y
  `onTrackingDismissed` si el usuario hace pan sobre el puck); el selector de
  punto reutiliza el mismo `LocationFab`; el mapa del viaje muestra leyenda
  (micro / caminata / transbordo) en la cabecera de la hoja de resultados.
- **Selector de punto**: el pin **no** es un marcador arrastrable sino una capa
  fija (`IgnorePointer` + `Stack`) centrada en la pantalla, cuya punta queda
  clavada en el centro exacto del mapa. La coordenada se toma del centro de la
  cámara en cada `onPositionChanged` (sin rebuild por frame; el chip de
  coordenada se refresca en vivo). `Usar este punto` lee
  `_mapController.camera.center` en ese instante, así que el punto devuelto es
  siempre el que se ve bajo el pin.
- **Mapa del viaje**: origen (`journey-map-origin`) y destino
  (`journey-map-destination`) son arrastrables. Al soltar, `JourneyResultMap`
  guarda el punto en un override local (el marcador no "regresa") y avisa a
  `onOriginMoved`/`onDestinationMoved`; el planeador aplica el punto tras un
  debounce de 600 ms, muestra el chip **"Recalculando…"** mientras vuelve la
  respuesta y, si no hay rutas, deja el mapa (con origen/destino) + estado
  vacío. Si la actualización falla se muestra "No se pudo recalcular" con
  reintento.

### 🤖 Cómo se prueba el arrastre

Los tests no pueden arrastrar anotaciones nativas, así que `FakeMapEngine`
expone la misma frontera que usaría el motor real:

```dart
final engine = tester.state<FakeMapEngineState>(find.byType(FakeMapEngine));
engine.debugFireMarkerDrag('journey-map-origin', LatLng(-17.77, -63.14));
// → dispara onMarkerDragEnd igual que onFeatureDrag de maplibre_gl
```

`test/journey_result_map_test.dart` cubre: el marcador se queda donde se
soltó + la caminata de origen parte del nuevo punto + se notifica el callback
(origen y destino), y un caso de punta a punta en el planeador (drop → chip
"Recalculando…" → debounce → nuevo punto en el campo de origen).
