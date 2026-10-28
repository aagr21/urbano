<div align="center">

<img src="docs/img/logo.svg" width="96" alt="Logo de Urbano"/>

# Urbano

**Muévete por Santa Cruz.** 🚌

Planificador de micros urbanos de Santa Cruz de la Sierra, Bolivia —
tipo Cruzero, pero moderno y bello.
Flutter (Android · iOS · Web) + backend NestJS con datos GTFS.

[![CI](https://github.com/aagr21/urbano/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/aagr21/urbano/actions/workflows/ci.yml)&nbsp;
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)](https://docs.flutter.dev)&nbsp;
[![NestJS](https://img.shields.io/badge/NestJS-11-E0234E?logo=nestjs&logoColor=white)](https://nestjs.com)&nbsp;
[![PostGIS](https://img.shields.io/badge/PostgreSQL%20%2B%20PostGIS-geoespacial-336791?logo=postgresql&logoColor=white)](https://postgis.net)&nbsp;
[![MapLibre](https://img.shields.io/badge/MapLibre-sin%20API%20keys-0EA5E9)](https://maplibre.org)&nbsp;
[![GTFS](https://img.shields.io/badge/GTFS-Micros%20Santa%20Cruz-F59E0B)](docs/gtfs-dataset.md)

</div>

---

## ✨ Características

- **🗺️ Planner real de transporte** — origen y destino arrastrables sobre el
  mapa, itinerarios con OTP2 (caminatas por la red viaria real) y degradado
  elegante al planner interno PostGIS si OTP no está disponible.
- **🚌 Panel de micros con vida** — el listado completo de líneas se desliza
  desde la izquierda: busca por numeral, y cada línea enciende su recorrido
  en el mapa con botones **Ida** / **Vuelta** independientes.
- **📍 Modo Lugares** — «¿qué línea pasa por aquí?»: busca la esquina por texto,
  usa tu GPS o **marca el punto directamente en el mapa**, y cada resultado
  dibuja su ruta entera con un toque.
- **🧭 Selector de punto al estilo Uber** — el mapa se mueve, el pin fijo se
  queda; la coordenada devuelta es siempre la que se ve.
- **⚡ GPS con estados reales** — GPS apagado / permiso pendiente / bloqueado /
  listo, con flujo guiado a los ajustes del sistema.
- **🎨 Identidad propia** — tokens estrictos de color/radios/espaciado, tema
  claro y oscuro de primera clase, y un kit de motion sobrio (`Reveal`,
  `PressScale`, `CountUp`, movimiento ambiente) sin amor por el circo.

---

## 🚀 Arranque rápido


### 🔧 Backend (NestJS + Postgres/PostGIS)

```sh
cd backend
docker compose up -d      # Postgres+PostGIS en el puerto 5436
npm install
npm run import:gtfs       # importa gtfs.zip: 154 rutas, 31.461 paradas, 5 s
npm run start:dev         # API en http://localhost:3000/api/v1 (docs: /docs)

# verificar
npm run test:all          # 16 unit + 11 e2e
```

Arquitectura hexagonal por feature (`src/modules/<feature>/{domain,application,
infrastructure,presentation}`), contrato en `docs/api-contract.md`, dataset en
`docs/gtfs-dataset.md`.

### 📱 App Flutter

```sh
flutter pub get

# Navegador / escritorio (default: http://localhost:3000/api/v1)
flutter run -d chrome

# Emulador de Android → el host se ve como 10.0.2.2
flutter run -d emulator \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1

# Dispositivo físico en la misma red WiFi
flutter run -d <device> \
  --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1
```

La base URL se inyecta con `--dart-define=API_BASE_URL=...`
(ver `lib/src/core/config/env.dart`); el default es `http://localhost:3000/api/v1`.
El contrato exacto del API vive en `docs/api-contract.md`.

> **Android**: `INTERNET`, `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` y
> `usesCleartextTraffic="true"` (para `http://10.0.2.2`) ya están en el
> `AndroidManifest.xml`. **iOS**: permiso de ubicación y `NSAllowsLocalNetworking`
> en `Info.plist`.

## 🧪 Verificación

```sh
dart format lib test
flutter analyze     # sin issues (el analysis_options.yaml es estricto a propósito:
                    # strict-casts + strict-raw-types y ~23 lints de estilo; ver AGENTS.md)
flutter test        # la suite completa offline (parsers, formatters, widgets, (7 packages: dio, flutter, flutter_riverpod,
                    # flutter_test, geolocator, latlong2, maplibre_gl): parsers,
                    # formatters, API client, widgets, arrastre de marcadores (motor
                    # simulado), drag/replan, aislamiento del rebuild por GPS,
                    # pantalla-mapa fusionada, flujo de ubicación con fakes
                    # + integración contra backend real (se omiten si está caído)
flutter build web --debug
flutter build apk --debug
```

### 🔌 Integración extremo a extremo

Con el backend levantado (ver arriba), `flutter test test/api_integration_test.dart`
ejecuta los repositorios reales de la app contra la API y PostGIS: stats del
feed, detalle con shape GeoJSON, próximas salidas y el planeador de viaje.
Si el API está caído, esos tests se omiten con un mensaje.

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
 azul/turquesa `#0EA5E9`/`#0284C7` + acento ámbar `#F59E0B`,
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
