# AGENTS.md — Urbano

Transit planner for Santa Cruz de la Sierra (GTFS-powered). **Two sub-projects**: the
Flutter app lives at the repo root; the NestJS 11 + Postgres/PostGIS backend lives in
`backend/`. Deep docs already exist — read `README.md`, `backend/README.md`, and
`docs/api-contract.md` before non-trivial work. Docs and code comments are in Spanish;
keep new ones in Spanish.

## Commands

Flutter app (repo root):

- `flutter analyze` — must pass with zero issues; run it alongside `flutter test` before finishing work.
- `dart format lib test` — the whole app is formatter-clean; run it with analyze +
  test as the final trio (`dart format lib test && flutter analyze lib test && flutter test`).
- `dart fix --apply` — safe bulk fix for the lint set below; always followed by the trio.
- `flutter test` — unit/widget tests; never needs network, plugins, or a running backend.
- Single file: `flutter test test/journey_result_map_test.dart`
- Splash de arranque: `tools/make-ios-splash-frame0.sh` regenera el PNG estático del launch screen
  de iOS desde `assets/brand/splash-frame0.svg` (necesita `resvg` o `rsvg-convert`; solo cuando
  cambie la pose del frame 0). La splash de Android es Kotlin con Canvas
  (`SplashCanvasView`): no hay JSON ni Lottie que sincronizar.
- Logo y escudo blanco: `tools/make-brand-logo.sh` regenera `assets/images/urbano-logo.png`,
  `urbano-logo-blanco.png` (desde `tools/brand_logo.py`, Montserrat ExtraBold vía resvg) y
  `gobierno-santa-cruz-blanco.png` (`tools/brand_seal.py`: solo el texto del escudo pasa a
  blanco, el blasón no se toca). La app (`UrbanoLogo`) y la splash nativa de Android usan esos
  MISMOS PNG; nunca los edites a mano.
- APK para repartir a mano: `tools/build-apk.sh` → UN APK universal (arm64 + armv7, ~26 MB en
  vez de ~90): `--target-platform android-arm,android-arm64`, `--obfuscate` (símbolos en
  `build/symbols/<versión>/`, guárdalos por versión), librerías nativas comprimidas
  (`packaging.jniLibs.useLegacyPackaging`) y x86/x86_64 excluidos SOLO en release por
  `androidComponents` en `android/app/build.gradle.kts` (un `ndk.abiFilters` no sirve: el
  plugin de Flutter suma sus ABI y choca con `--split-per-abi`). Debug conserva x86 para
  emuladores. Para Google Play se sube `flutter build appbundle`, no el APK.
- Ícono de la app: `tools/make-app-icon.sh` lo regenera en todas las plataformas. El diseño vive
  en `tools/app_icon.py` (SVG en `assets/brand/app-icon/`, PNG intermedios ignorados) y la
  config en `icons_launcher.yaml`; nunca edites los PNG de `android/`/`ios/` a mano.

Backend (always `cd backend` first — the boot order matters):

- `docker compose up -d` → PostGIS on **host port 5436** (not 5432; see `.env` `DB_PORT`)
  and — once `otp-data/graph.obj` exists — **OpenTripPlanner 2 on host port 8081**.
- `npm install && cp .env.example .env && npm run import:gtfs` → imports `gtfs.zip`.
- `npm run fix:gtfs-directions` — dry-run diagnostic of the feed's ida/vuelta orientation; add `--apply`
  (optionally `--routes 75,123`) to rewrite `stop_times.txt` in place. `--osm <city.geojson>` adds the
  second repair: routes whose ida/vuelta `shape_id` are on the opposite carriageway (contraflecha) get
  their shapes swapped, decided against OSM `oneway` data (without `--osm` that step is skipped with a
  warning). The shipped `gtfs.zip` is already repaired (13 routes had `direction_id=1` duplicated in the
  ida order and 18 had the shapes swapped — see `docs/gtfs-dataset.md`); `backend/gtfs.orig.zip` keeps
  the untouched original. Re-run after pulling a new feed, then re-import **and** rebuild the OTP graph.
- OTP2 graph build (one-time): `cd otp-data && cp ../gtfs.zip gtfs.zip && curl -L
https://download.geofabrik.de/south-america/bolivia-latest.osm.pbf -o bolivia-latest.osm.pbf
&& cd .. && docker compose run --rm otp --build --save`. With `OTP_URL` set (see
  `.env.example`), `/journey` itineraries come from OTP (walk legs follow the street
  network with `geometry` on `kind:"walk"`); OTP downtime falls back to the internal
  PostGIS planner (straight-line walks). See `backend/otp-data/README.md`.
- `npm run start:dev` → API at `http://localhost:3000/api/v1`, Swagger at `/docs`.
- `npm run test:all` = unit tests + `test:e2e`. The e2e suite hits the **real Postgres
  with the imported feed** (`--runInBand`, 30s timeout), so Docker DB + import are
  prerequisites. Unit tests alone (`npm test`) run without a DB.
- `import:gtfs` runs `TRUNCATE` + bulk insert in one transaction — safe to re-run, but it wipes tables.
- `npm run lint` (eslint 10 + typescript-eslint, `eslint.config.mjs`) and
  `npm run format:check` (Prettier, `.prettierrc`) must pass — CI runs both. Format with
  `npm run format`; `no-console` is an error outside the CLIs/scripts (use Nest's `Logger`).
  Verify backend changes with the backend trio: `npm run lint && npm run format:check &&
  npm test && npm run build`. Format-only commits go in `.git-blame-ignore-revs`.
- Backend unit tests map `@/` → `src/` (tsconfig paths + jest moduleNameMapper); specs live next to source as `*.spec.ts`.

## API base URL gotcha

`lib/src/core/config/env.dart` defaults `API_BASE_URL` to the **production
Vercel URL**. Always pass it explicitly for targeted local runs
(`.vscode/launch.json` already does, and adds
`--dart-define-from-file=config/env.json` for the Google layer key):

- Desktop/chrome: `--dart-define=API_BASE_URL=http://localhost:3000/api/v1`
- Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1`
- `test/api_integration_test.dart` takes the same define (its own default is localhost)
  and **skips** — not fails — when the backend isn't up. Start the backend first; run the
  rest of `flutter test` for offline verification.

## Testing quirks

- Under `flutter test`, the map engine is always forced to `FakeMapEngine`
  (`FLUTTER_TEST` detection in `lib/src/core/utils/runtime_flags_io.dart`, exposed as
  `isRunningUnderTest`), so no
  test needs the maplibre plugin or network. Keep it that way for new tests.
- Native annotation drags can't be simulated by widget gestures. Use
  `engine.debugFireMarkerDrag('journey-map-origin', LatLng(...))` on `FakeMapEngine`
  (pattern in `test/journey_result_map_test.dart`).
- `latlong2.LatLng` is the coordinate type used by models, engines, and tests — don't
  swap it for another type when touching `lib/src/core/map/`.
- `passengerControllerProvider` **hangs** under `flutter test`: its real store awaits
  `SharedPreferences.getInstance()`, and an unhandled platform channel never completes (the
  store's `try/catch` cannot rescue an `await` that returns nothing), so the complaints feed
  stays on its skeleton forever. Any test that opens the feed, the detail or the like flow
  must override it with an in-memory `PassengerIdentityStore` —
  `passengerControllerProvider.overrideWith(() => PassengerController(_InMemoryStore()))`
  (pattern in `test/complaints_feed_test.dart`).
- Complaint cards/chips are painted from `AppColors.categoryAccent(category)` **through**
  `AppColors.tint(accent, surface)` (fill) and `AppColors.legible(accent, fill)` (text/icon),
  never from the raw accent; the shared pieces (`MicroBadge`, `CategoryChip`, `StatusChip`,
  `ComplaintPill`) live in
  `complaints/presentation/widgets/complaint_chips.dart` so feed, detail and form agree. The
  tinted fill and its ink are measured in both themes by `test/complaints_feed_test.dart`.
- Complaint attachments are a **gallery, never `photoUrls.first`**: the detail mounts
  `ComplaintPhotoGallery` (`complaints/presentation/widgets/complaint_photo_gallery.dart` — main
  photo + one tappable thumb per adjunto) and any tap on those photos pushes
  `ComplaintPhotoViewerScreen` (`openComplaintPhotoViewer`, same folder), a `PageView` over the
  whole list with a `"i de N"` counter. The feed card keeps a single photo (inset, rounded, double tap = apoyo) — it opens the
  detail, which now shows everything. Locked by `test/complaint_photo_gallery_test.dart`; note a
  `PageView` drag in a test must cross half the page width (viewport is 800 px logical by default,
  so `Offset(-500, 0)`), otherwise it settles back on the same photo.
- **The `/complaints` curtain must not eat the first post.** The header card, the category filter
  row and the "La comunidad reporta" row are chrome, not content: the feed's first
  `ComplaintPostCard` (~400 px: author-style header with `MicroBadge` + `Micro N` + status, inset photo
  with the category on it, quoted body, three-way action bar) has to fit between the list top and the bottom chrome at
  1080×2340@2.75. `_CommunityHeader` is therefore one tight row (badge + title + compact
  `Crear` CTA with tooltip `Crear queja`) above the three `ComplaintsStatTile`s (`complaints_cover_header.dart`) — no tagline paragraph, no
  full-width button row — and `test/complaints_feed_test.dart` asserts `card.bottom < bar.top` at a
  real phone height (that harness mounts the real `UrbanoBottomBar` as the bottom boundary;
  `_openFeed` does not). Anything
  new up there goes into the header row or gets scrolled, never stacked below it. Because the CTA
  shares the row with the title, the title is `Expanded > FittedBox(scaleDown)`, **never**
  `TextOverflow.ellipsis` (a long label there truncated "La voz del pasaj…" on real phones); the
  label stays short and its `textStyle` starts from a theme style so it keeps Montserrat.
- **Text widths measured under `flutter test` are Ahem, not Montserrat** (one square per glyph, so
  ~1.8× the real string): anything sized by measured text must be re-measured with the real face
  — load it in `setUpAll` with `FontLoader('Montserrat')` over `assets/fonts/Montserrat-*.ttf` bytes
  (`dart:io` + cwd = package root), and remember `TextStyle(...)` without `fontFamily` silently
  drops the app's face unless it inherits the theme (`ThemeData.fontFamily` is Montserrat; the
  `TextTheme` carries it via `AppTypography.apply`). Patterns: `test/nearby_quick_action_test.dart`
  and `test/home_action_tiles_test.dart` (the four Inicio tiles must not cut text at 360 dp).
- **Feed de quejas: el doble toque sobre la foto APOYA, nunca quita** (`complaint-hero-<id>`, solo
  el héroe; el resto de la tarjeta abre el detalle al primer toque, sin la espera del doble toque).
  Apoyar da `HapticFeedback.lightImpact` y el corazón que late. El feed cierra con
  `ComplaintsFeedInvite` (`AsyncListView.footer`: solo con datos, nunca con vacío/error), que invita
  a reportar y enseña el gesto; va al final, así que no toca la regla de la cortina. «La comunidad
  reporta» es `FittedBox(scaleDown)` de una línea, igual que el título de la cabecera. En un test, un
  toque simple sobre el héroe necesita `tester.pump(kDoubleTapTimeout)` antes de `pumpAndSettle`.
  Locked by `test/complaints_feed_test.dart`.
- **The word is `apoyo`, never "me gusta"** in any user-facing copy, comment or doc of the social
  layer (the heart's zero-state label is `Apoyo`, the header counts `apoyos`). Code and HTTP keep
  `like`/`liked`/`likeCount`/`setLiked`/`complaint_like`. Locked by
  `test/complaints_feed_test.dart`.
- A bare `SizedBox` (or any `RenderConstrainedBox`-only subtree) **is not hit-testable**,
  so `tester.tap()` on a `GestureDetector` wrapping one reports `taps == 0` no matter how
  much you pump — the bug is the fixture, not the widget. Put a `ColoredBox`, a `Text`
  or `HitTestBehavior.opaque` inside the target (pattern in `test/app_motion_test.dart`).
- `find.ancestor(of: X, matching: Y)` returns outermost-first: apply `.first` to the
  _result_ (`find.ancestor(...).first`), never inside `matching:` — otherwise the lookup
  throws `Bad state: No element`.

## Style rules the analyzer actually enforces

`analysis_options.yaml` is a **deliberate strict set**, not the Flutter template: `strict-casts`

- `strict-raw-types`, and ~23 lints (`prefer_const_constructors`, `prefer_final_locals`,
  `require_trailing_commas`, `directives_ordering`, `avoid_redundant_argument_values`,
  `unnecessary_lambdas`, `use_super_parameters`, …). New code must pass it — do not "solve" a
  violation by commenting a rule out or adding `// ignore:` without a reason in Spanish.

Visual values come from tokens in `lib/src/core/theme/`, never from literals:

- Brand: **exactly** the six official colors, no invented shades (the user asked for it):
  greens `#35F04F` `#1BD64C` `#06BD4A` `#029E46`, orange `#FD7502`, white `#FEFEFE`
  (`AppColors.lime/brightGreen/brand/primary/accent/brandWhite`; `primaryDark`, `greenDeep`,
  `accentDeep`, the dark-mode variants and the green/orange `HtmlDesignTokens` all alias one of
  them). Lighter fills are those colors through `AppColors.tint` (transparency), never a new hex;
  only neutrals (ink, grey text, the dark-mode graphite) live outside the palette.
  `test/theme_palette_test.dart` («todo color de marca es EXACTAMENTE uno de la paleta») locks
  it. On the green gradient the ink is **always** `AppColors.onBrand` (`#FEFEFE`, bold,
  title/label sizes) — never `AppColors.onColor`, which picks black against the bright brand
  green. Denuncias uses the orange as its section accent. Type is Montserrat everywhere
  (`ThemeData.fontFamily`).

- Corners: `AppRadius` (`sm 10 · tile 12 · input 14 · md 16 · lg 24 · xl 32 · pill 999`).
  No `BorderRadius.circular(<número>)` anywhere in `lib/`. `pill` is also correct for thin 4 px
  bars (radius = half the height), so "small number" is not a reason to bypass the scale.
- Spacing `AppSpace`, colors/type `context.colors` / `context.text`
  (`core/utils/extensions.dart`) instead of `Theme.of(context)…`.
  `GlassCard(radius: 20)` is the one known off-scale default (tokenizing it would move pixels);
  don't add more.

## Architecture rules of thumb

**Responsabilidad única y testeable por defecto.** Cada archivo/clase tiene UN
motivo de cambio, y toda decisión que no sea pintar se escribe donde se puede
probar sin montar widgets:

- **Reglas puras** (qué elegir, cómo filtrar/ordenar/paginar, qué texto toca,
  cuándo levantar una cortina) → funciones o clases inmutables en
  `domain/`/`application/` (o `core/utils/`), con su `*_test.dart` unitario.
  Ejemplos: `DestinationDraft` (hoja «¿A dónde vas?»), `resolveEndpointSubmit`,
  `pageOf` (`core/utils/paging.dart`), `JourneyMapGeometry`, `LegStrokeColors`,
  `routeMainPlaces`, `shouldLiftCurtain`/`bootStageFor`, `meaningfulHeadsign`.
- **Casos de uso con efectos** (planificar + guardar + historial, paginar un
  catálogo) → un controller/servicio de `application/` probado con
  `ProviderContainer` (`TripLauncher`, `MicrosCatalogController`).
- **Plugins** detrás de una interfaz inyectable por provider
  (`ComplaintPhotoSource` sobre `image_picker`), nunca instanciados en un `State`.
- **Widgets**: el `State` solo cablea gestos → transiciones y monta piezas; cada
  bloque visual grande es su propio widget (`*_sections.dart`, `*_parts.dart`).
  Un archivo con dos widgets públicos se parte.
- **Backend**: igual. `journey-planner.ts` es solo la búsqueda; geodesia
  (`geo.ts`), geometría (`journey-geometry.ts`) y ranking
  (`journey-ranking.ts`) son módulos propios, y el mapeo de OTP
  (`otp-itinerary.mapper.ts`) está separado del adaptador HTTP. Los CLIs solo
  orquestan I/O: el plan de reparación del feed vive puro en
  `gtfs-feed-repair.ts`. Denuncias: validaciones y límites en
  `complaints/domain/complaint-rules.ts`, fotos detrás de `PhotoStoragePort`
  (token `COMPLAINT_PHOTO_STORAGE`, adaptador `VercelBlobPhotoStorage`); un
  servicio Nest no recibe nada que no sea un provider (el reloj de
  `ComplaintsService` es una propiedad, no un parámetro del constructor), y
  `complaints.service.spec.ts` lo comprueba armándolo con `Test.createTestingModule`.


Backend (`backend/src/modules/<feature>/{domain,application,infrastructure,presentation}`
— hexagonal, don't put business logic in controllers):

- Controllers only validate + delegate; services depend on port interfaces injected by
  token; TypeORM/PostGIS repos live in `infrastructure/`.
- `DB_SYNCHRONIZE=true` in dev: TypeORM auto-syncs schema on boot; PostGIS/B-tree/`pg_trgm`
  indexes are created idempotently at startup (`DatabaseSetupService`).

Flutter app: Riverpod for state, `go_router`. **Barra inferior del diseño** (`UrbanoBottomBar`,
`core/router/urbano_bottom_bar.dart`, claves `nav-<id>`): Inicio · Micros · Viajes · Lugares ·
Denuncias · Perfil. Cinco pestañas son ramas de `StatefulShellRoute.indexedStack` (`/`,
`/micros`, `/journey`, `/complaints`, `/profile`; `UrbanoShell.tabBranches` mapea pestaña →
rama); **Lugares no es rama**: es la acción `openPlacesSearch` (abre la hoja «¿Qué micro pasa
cerca?» y empuja `/nearby`), la misma del acceso de Inicio. Tocar la pestaña activa vuelve a su
raíz; «atrás» fuera de Inicio lleva a Inicio (`PopScope` del shell) y la flecha
`journey-back-button` sigue en la columna de controles del mapa. Las ramas se construyen al
visitarse por primera vez, y el shell solo funde el cuerpo al cambiar de sección. El botón de la
cabecera de Inicio es el de **tema claro/oscuro** (`home-theme-button`: luna en claro, sol en
oscuro, `setMode` persiste la elección); la misma preferencia (sistema/claro/oscuro) se elige en
**Perfil** (`features/profile/`): identidad anónima del pasajero (avatar + apodo editable con
`showPassengerNameSheet`), apariencia, historial de viajes (contador + «Borrar» con
confirmación) y «Acerca de». Perfil lee `passengerControllerProvider`, así que todo test que
abra esa pestaña lo sobrescribe con un store en memoria (pattern en `test/urbano_shell_test.dart`).
El catálogo completo de líneas es la rama **`/micros`** (`routes/presentation/micros_screen.dart`,
tarjetas `MicroCard`), que también abre el acceso **Micros** de Inicio con
`UrbanoRoutes.openMicrosCatalog` (`go`, no `push`); cada tarjeta lleva al detalle
`/routes/:id?from=micros`.
`/map` redirects to `/journey`. El antiguo panel lateral de micros de `/journey` (cajón con
toggles ida/vuelta y modo «Lugares») se **retiró** —había quedado sin entrada—; no lo
repongas sin decidir antes cómo convive con `/micros`. Si vuelve a hacer falta una bandera
«abrir X al llegar a Viaje», se consume en `initState` con
`listenManual(fireImmediately: true)` (a `ref.listen` inside `build` misses it when
the Viaje branch has never been visited, because that first build runs in the same
frame as the `go()`). dio in `core/network/`, map
behind the `UrbanoMap`
facade, GPS isolated in `core/location/` (injectable `LocationService` so tests run
without geolocator). `/journey` is a single always-mounted screen — don't recreate the
platform view; the merged map/result-sheet design is deliberate (see README).

- **La portada sigue el diseño «Pantalla de inicio» (carpeta de marca `actualizacion/`).**
  De arriba abajo: la cabecera (`home_header.dart`, key `home-official-band`) con el escudo del
  Gobierno Autónomo Municipal (`assets/images/gobierno-santa-cruz.png`, se escala pero no se
  redibuja; en oscuro va sobre una placa blanca, `home_official_seal.dart`), el **logotipo
  oficial** (`UrbanoLogo`, `core/widgets/urbano_logo.dart`: PNG generado + el lema como `Text`
  en Montserrat, que cambia de tinta con el tema) y el botón de tema; la tarjeta **«Planifica tu
  viaje»** (`destination_bar.dart`, key `home-destination`: degradado de verdes, tinta blanca en
  negrita, píldora blanca «¿A dónde vas?» con la flecha naranja) que abre
  `openJourneyDestinationSheet` — es el CTA primario; los cuatro accesos en retícula 2 × 2
  (`home_action_tiles.dart`: tarjeta blanca, ícono de marca `UrbanoGlyph` sobre placa tonal,
  título, bajada y chevrón verde; Micros · Viajes · Lugares · Denuncias) y **Tus viajes
  recientes** (`recent_trips.dart`: rótulo con reloj y «Ver todos», una tarjeta por viaje con la
  píldora de recencia —«Hoy»/«Ayer»/«Hace N d», `recencyLabel`, días de calendario— y la **X**
  `recent-trip-remove-<key>` que lo borra del historial). Ya no hay píldora «Transporte
  Oficial», ni «Tu ubicación», ni wordmark de texto: la marca es el logo. Los íconos de marca
  (`core/widgets/urbano_glyph.dart`) se dibujan en código en dos modos: a color (accesos) y
  monocromo (barra inferior); los «blancos» del dibujo se recortan, así funcionan en ambos temas.
  Los accesos están medidos para 360 dp (`test/home_action_tiles_test.dart`): no agrandes
  placa, título ni márgenes sin volver a correrlo.
  El historial se alimenta de `tripHistoryControllerProvider`
  (`journey/application/trip_history_controller.dart` + `journey/data/trip_history.dart`):
  `SharedPreferences` bajo `urbano.trips.recent`, dedupe por `label|lat|lon`, máximo
  `maxEntries = 30`, orden por `lastUsed`; el planeador lo anota desde su listener de
  `journeyResultsProvider` cuando llega una respuesta fresca. La portada lista solo
  `RecentTrips.visibleOnHome = 3` filas; cuando hay más, el rótulo lleva la píldora
  «Ver todos» (sin número) en la esquina superior derecha y abre
  la hoja con el historial completo (`recent-trip-all-*`, tarjeta agrupada, sin X),
  que lleva un buscador con lupa y pagina de 8 en 8 cuando hay más de 8 viajes. Sin
  historial la sección no ocupa
  espacio; tocar una fila repone el destino, usa `lastKnownLocationProvider` (o
  `myLocationProvider`, que la tarjeta mantiene vivo) como origen si falta, abre
  el panel y cambia a `/journey`. En tests el provider **siempre** se sobrescribe con
  `test/helpers/memory_trip_history_store.dart` — `shared_preferences` no existe bajo
  `flutter test`. Locked by `test/trip_history_test.dart`, `test/recent_trips_test.dart`
  y el test del historial de
  `test/widget_test.dart`. En el viewport de test (600 lógicos) los accesos y «¿A dónde vas?»
  entran sin scroll; el historial con filas se sigue leyendo con
  `scrollUntilVisible`/`ensureVisible`.

- **Ubicaciones que llegan de otras apps (deep link) abren la hoja «¿A dónde vas?» con el destino
  puesto.** Solo Android: `IncomingLinkActivity.kt` es un trampolín invisible con tres filtros
  (`geo:` = tocar una ubicación en WhatsApp; `urbano://destino?lat=&lon=&nombre=`; `SEND text/plain` =
  «Compartir» desde Google Maps). Guarda el texto en el buzón `IncomingLinks` y trae la tarea con el
  intent del **launcher** (en frío pasa por `SplashActivity`; con la app viva se reanuda) — nunca abre
  `MainActivity` directo, que crearía una segunda FlutterActivity en la tarea de WhatsApp pegada al
  engine cacheado. El canal `urbano/incoming_link` (`takePending`, consume) se registra en el engine
  pre-calentado **y** en `MainActivity.configureFlutterEngine`. En Dart, `IncomingDestinationGate`
  (en el `builder` de `MaterialApp`, junto a `StartupLocationGate`) pregunta al montarse y en cada
  `onResume`; la decisión es pura: `parseSharedLocation` (`core/deep_link/shared_location.dart`:
  geo, Google con prioridad `!3d!4d` > `q/query/destination` > `@`, Apple, OSM, Waze, texto con
  enlace o par suelto), enlaces cortos `maps.app.goo.gl` por `MapLinkResolver` (HEAD sin seguir
  redirecciones, solo hosts de Google; offline bajo test) y `resolveIncomingDestination`
  (`journey/application/incoming_destination.dart`: fuera de `sharedLocationServiceArea` o ilegible
  → snack, sin hoja). iOS no puede: WhatsApp solo ofrece Apple/Google Maps/Waze. Locked by
  `test/shared_location_test.dart` y `test/incoming_destination_gate_test.dart`.

- **Sugerencias de calles al escribir = Photon (OSM), nunca Nominatim.** `core/location/place_search.dart`:
  `placeSearchProvider(query)` (≥ `placeSearchMinChars` = 3 letras, pausa de 350 ms tras la última tecla,
  `CancelToken` al seguir escribiendo, caché de 2 min) sobre `PlaceSearchService`; la implementación es
  `PhotonPlaceSearchService` (photon.komoot.io, caja de Santa Cruz, sesgo al centro) y `parsePhotonResults`
  quita el ruido (landuse/natural/boundary/waterway, otras ciudades) y deja una sugerencia por nombre. La
  política del Nominatim público PROHÍBE autocompletar (sigue usándose solo para la dirección inversa).
  Lo usan los campos origen/destino del planificador (`DestinationSuggestionPanel.online`, debajo de los
  lugares populares, sin repetirlos; Enter toma la primera) y la hoja de Lugares (sección «Calles y
  lugares»). Con sugerencias a la vista se muestra `osmAttribution` (licencia de OSM). Bajo `flutter test`
  el servicio por defecto no sale a la red y la pausa es cero; los tests lo reemplazan con
  `test/helpers/fake_place_search_service.dart`.

- **«Lugares» = «Micros cerca» (`lib/src/features/nearby/`).** El acceso abre
  `showNearbySearchSheet` (escribir lugar/parada, «Mi ubicación» o «Marcar en el mapa» vía
  `/journey/pick`, radio 300/500/1000 m) y su «Buscar cerca» empuja `/nearby?lat=&lon=&label=&r=`
  (`NearbyQuery` viaja en la URL; la hoja solo devuelve la consulta, navega quien llama). La vista
  agrupa `/stops/nearby` por línea con `groupNearbyMicros` (dominio puro): **por sentido** se queda
  con la parada más cercana que lo sirve, porque ida y vuelta suelen ir por aceras distintas; sin
  `directionIds` ofrece ambos sin confirmar y una confirmada siempre gana. La selección
  (`nearbySelectionProvider`) dibuja el `shape` del sentido con las MISMAS flechas del planificador
  (`routeArrowMarkers` en `journey/presentation/journey_markers.dart`, espaciado
  `arrowSpacingFor` ≤ ~45 por línea), la parada de subida, el tramo a pie punteado y la zona como
  aro punteado. Al llegar se elige sola la línea más cercana; con zona vacía la hoja sube a
  `_sheetEmpty` para que «Ampliar» quede a la vista. A la altura inicial de la hoja solo se
  construye la primera tarjeta: los tests la suben antes de buscar la segunda. Locked by
  `test/nearby_micros_test.dart` y `test/nearby_micros_screen_test.dart` (incluye contraste
  Ida/Vuelta en oscuro).

- Render async lists/queries with `core/widgets/async_value_view.dart`
  (`AsyncValueView`/`AsyncListView`) instead of hand-rolling per screen.
- **Map layer ≠ app theme.** The map's base layer is `MapTile` (`core/map/map_tile.dart`, chosen
  through `MapTileButton` and persisted under `urbano.map_tile`); the UI theme is
  `themeModeControllerProvider`. A layer changes **only the base map** — buttons, chips, panels,
  sheets and markers always follow the app theme, so there is no nested `Theme`/scope around map
  overlays. UI copy says **capa**, never "tile". `MapTile.resolve(appDark:, choice:)` (choice
  `null` = follow the app's brightness) is the single place that decision is made — read it from
  `mapThemeControllerProvider`, never re-derive it per widget. All four layers (including the two
  Google ones) are always listed; without `GOOGLE_MAPS_API_KEY` the Google cards are marked
  "Requiere clave" and explain the flag instead of being hidden — and `flutter test` always has an
  empty key, so never make a test depend on Google tiles rendering.
- Animations are frame-driven (`AnimationController` + implicit widgets), never
  `flutter_animate`: its `Animate` mounts a zero-duration `Timer`, which breaks widget
  tests that use plain `pump()` ("A Timer is still pending…"). A `Positioned` child
  hanging off a panel's edge is not hit-testable unless its `Stack`/`SizedBox` is wide
  enough to contain it.
- **Motion kit** (`core/animation/motion.dart`) is what the rest of the app uses for
  movement: `PressScale` (press sink on tappable surfaces), `Reveal` (staggered
  entrance for lists/sections), `CountUp` (number roll-up) and `UrbanoPageTransitions`
  (wired through `AppTheme.pageTransitionsTheme`; **Android deliberately keeps
  `PredictiveBackPageTransitionsBuilder`**). All of them are ticker-driven and honor
  `MediaQuery.disableAnimations`, so they are safe under plain `pump()` tests and on the
  `pumpAndSettle()`-heavy planner. New UI goes through them, never through
  `flutter_animate` — it is gone from `pubspec.yaml` too, so re-adding it would be a
  deliberate change, not an oversight — and never through ad-hoc
  `AnimationController`s either (`LoadingShimmer`'s loop and `Ambient`'s are the sanctioned
  exceptions, both plain controllers). `Reveal` staggers with `index:` (capped by
  `Motion.maxStaggerIndex`), never with a delay duration — and rows that can rebuild
  need a stable `key:`, otherwise the entrance replays on every rebuild.
- **`Ambient` loops forever in the running app** (`cycles: null`, the default): the header
  lattice, `LiveDot` halo, `EmptyState` `Bob` and the planning progress bar must keep moving
  while the screen is up — a bounded loop is what made the app look frozen after ~5 s. The
  `Motion.ambientCycles` cap is applied **only under `flutter test`** (an endless `repeat()`
  never lets `pumpAndSettle` settle, and hidden shell branches would eat the visible tab's
  timeout), so tests stay green unchanged; `Motion.debugAmbientLoopsForever = true` is the
  `@visibleForTesting` way to exercise the production branch. One-shot effects (the rail that
  draws itself) must pass an explicit `cycles:`. Builders receive
  `(t, phase)`: `phase` for anything that repeats, global `t` (i.e. `1 - t`) for anything that
  fades out at rest — never re-derive the phase by hand with `Motion.phase(t, 2)`, that
  duplicated the cycle count.
- Don't scale a `BackdropFilter`: `GlassCard` is left out of `PressScale` on purpose —
  re-rasterizing the blur each frame is exactly the jank that shows up on low-end
  Android; its `InkWell` splash is the feedback.
- **Live GPS never reaches a big `build`.** `locationControllerProvider` emits one event
  per GPS tick; watching it in the planner screen's `build` used to rebuild the whole
  tree (map, panel, chips, results sheet, controls) just to move the camera. Only the two
  small `ConsumerWidget`s at the bottom of `journey_planner_screen.dart` — `_LiveMapLayer`
  and `_LiveMapControls` — may watch the location providers; the screen's `build` resolves
  endpoints **without** the GPS fallback and lets the layer apply it. Locked by the
  "un evento de ubicación mueve SOLO el mapa" test in `test/journey_result_map_test.dart`
  (it asserts `same()` widget identity for the results sheet and _not_ `same()` for the map,
  so the guard can't silently become a no-op). Apply the same split to any new live stream.
- **GPS is opened by demand, never by a listener.** `locationDemandProvider`
  (foreground via `appForegroundProvider` **&&** `followLocationProvider` **&&** status
  `ready`) is the single key: without it `myLocationRealtimeProvider` returns an _empty_
  stream, so `Geolocator.getPositionStream` is never called even though the planner is
  always mounted (an unconditional `ref.listen` used to mean permanent GNSS and a hot
  phone). Cost policy lives in `core/location/gps_budget.dart` — **two thresholds, one
  pass**: `gpsMinDrawMeters` (1 m) is the floor of the dot (it must advance with every
  fix or the map looks frozen while walking) and `gpsMinMovementMeters` (5 m) is the floor
  of the **camera**, measured from the last point that actually moved it, so drifting
  fixes never re-animate the native view. The tracking settings ask the platform for
  **no** `distanceFilter` (`0`): that knob is all-or-nothing and froze the dot too (some
  OEMs delay delivery aggressively). `gpsQuietHeartbeat` (30 s) re-anchors the camera when
  a still device never crosses the movement floor, one-shot reads use `gpsOneShotSettings`
  (medium + `timeLimit`) and only tracking pays for `high`.
  `trackedFixes` must stay a `StreamController(onListen:, onCancel:)`: an `async*`
  `await for` does **not** propagate cancellation upstream, which leaks the plugin's
  location listener forever. Locked by `test/gps_budget_test.dart` and "sin seguimiento
  NO se abre el sensor" in `test/journey_live_location_test.dart`, which drives the real
  `resumed → inactive → hidden → paused` cycle (`AppLifecycleListener` asserts on skipped
  states). The GPS halo's `Timer.periodic` is paused the same way in
  `maplibre_engine_sync.dart`.
- Never read `MediaQuery` inside `initState` (the framework asserts as soon as the
  widget mounts under the shell's `MediaQuery`); decide in `didChangeDependencies`
  behind a "started once" guard, the way `_RevealState` does.
- Entrances are already wired where they belong: `AsyncValueView` reveals its data
  when the skeleton retires, `EmptyState`/`ErrorView` reveal themselves, list tiles
  stagger by `index`. Don't wrap those calls in another `Reveal`/`flutter_animate`
  chain — it double-animates and looks cheap.
- **The boot splash is ONE phase: `SplashGate`, and it follows the design «Pantalla de carga».**
  `core/widgets/splash_gate.dart` (cover in `splash_cover.dart`) paints, over the brand gradient
  and the Santa Cruz rings: the municipal seal with white text (`_SplashBrand`,
  `assets/images/gobierno-santa-cruz-blanco.png`), the white Urbano logo with its tagline
  (`UrbanoLogo(onBrand: true)`), then the loading block — orange dial on a translucent white track,
  `Cargando`, the real boot stage and a white bar filling with orange — and the
  `Santa Cruz de la Sierra` footer. (An earlier iteration hid the logo on request; the new brand
  design puts it back, so don't remove it again without asking.) Before `SplashGate` there are
  TWO native phases on Android: the OS field (`windowSplashScreenBackground` /
  `windowBackground`, which cannot animate) and
  `android/app/src/main/kotlin/.../SplashActivity.kt`, a Kotlin launcher whose `SplashCanvasView`
  paints the same screen for 1,5 s — it decodes the SAME two PNGs from `flutter_assets` and draws
  the rest with Canvas and Montserrat — and then hands off to `MainActivity` + `finish()` (so it
  never enters the back stack). It is Canvas-only: no Lottie, no JSON — the art exists twice
  (this Canvas and the Dart painters) and has to be kept in sync by hand (same layout numbers:
  `Alignment(0, -0.3)`, logo 70 % of the width clamped 48–96 dp, dial `min side * 0.17`
  clamped 58–80 dp, bar 220 × 10 dp). iOS has no animated launch (Apple rejects it), so
  `LaunchScreen.storyboard` shows a static reproduction of that frame 0 (`LaunchImage`
  imageset, generated by `tools/make-ios-splash-frame0.sh` from `assets/brand/splash-frame0.svg`,
  which embeds both PNGs and draws its text with Montserrat via resvg's `--use-font-file`) and
  then the SAME painted `SplashGate` cover takes over on every platform. `launch_background.xml`
  still has no logo, and Android 12+ needs
  `windowSplashScreenAnimatedIcon` = the transparent `urbano_splash_icon_blank` — omit it and the
  launcher icon shows as a second splash.
  `test/splash_gate_test.dart` covers the cover and native resources are
  checked with `:app:processDebugResources`.
  `windowSplashScreenBackground` is **`urbano_primary` (`#06BD4A`, the palette's verde principal,
  the gradient's middle tone), not `primary_dark`**: with the dark end the handoff read as a
  separate green screen (measured with `screenrecord` on the Honor).
- **The cover enters already painted.** (the cover and its painters live in `splash_cover.dart`, a `part` of `splash_gate.dart`) `_SplashCover._startT` is `0.14` and the loading windows
  (`_blockEnd 0.26`, `_barBegin .02`, `_footEnd .14`) are already open by then, so frame 1 shows the
  dial + `Cargando` + the stage line + footer + a bar that has already started. With `begin: 0` the
  first ~9 frames (300 ms) were the brand gradient with **nothing** on it, which is indistinguishable
  from the native field: same color, no motion → "primero se ve solo verde". Those frames are why a
  test must assert the painted `Opacity` of the label (`.last` ancestor, innermost), not
  `find.text(...)` — a `Text` under `Opacity(0)` is still "found".
- **The curtain lifts on readiness, not on a timer.** The cover's timeline is ONE
  `TweenAnimationBuilder` with **two legs** (`_startT → restT 0.62` intro, `restT → 1.0` exit) and
  everything that keeps moving while the app is slow (dial, bar sweep, the micro crossing the rings)
  comes from ONE `Ambient` — no per-effect controller, and no `CircularProgressIndicator` (its
  eternal internal ticker makes `pumpAndSettle` never converge). `SplashGate.ready` is the second
  condition: the curtain only lifts when `onEnd` fired the intro **and** the future resolved, so a
  fast backend can't make it blink (the intro is the minimum-visible floor) and a slow one is covered
  honestly. `bootReadinessProvider` (`core/boot/boot_readiness.dart`, watched from `_BootGate` in
  `main.dart` — NOT from the home) awaits `routesListProvider(homeCatalogQuery)` (una página corta de
  `/routes`; desde que se retiró el panel de micros nadie más la lee, así que hoy funciona como prueba
  de que el backend responde) and never throws: it returns `bool` so an unreachable
  backend still lifts, with the `Sin respuesta del servicio` stage instead of a lying `Todo listo`.
  `bootCeiling` (6 s) is that safety — a loading screen that can trap the user is worse than the
  data it is waiting for. `homeCatalogQuery` is a shared const (`routes/presentation/route_providers.dart`)
  because `SimpleCache` does not dedupe in-flight calls: quien quiera aprovechar esa precarga
  debe pegarle al mismo elemento del provider o `/routes` se paga dos veces. New
  boot data goes into that future, and a `ready` future must never be re-listened in `build` —
  `provider.future` fabricates a new future per rebuild, so the subscription lives in `initState`.
  `TweenAnimationBuilder` also has a trap: if `begin == end` the tween never starts and `onEnd`
  never fires, so reduce-motion pins only the **painted** `t` (still `begin: _startT`) — the old
  `begin: reduced ? restT : _startT` left the splash mounted forever.
- **Flutter's FIRST frame must be cheap — it is what dismisses the native splash.** Android keeps
  painting the green brand field until Flutter renders, so any work in that frame reads as "solo
  verde, sin carga". `SplashGate` therefore mounts its `child` on the _second_ frame (post-frame
  callback + `_appStarted`), never in the same build as the cover: the map platform view and the
  shell branches used to be paid inside the frame that dismisses the splash. Same reasoning for
  `main.dart`: both SharedPreferences reads are started together and awaited already-running. The
  child is deferred in BOTH motion modes — the static cover still has to hide the mount. Anything else
  that could delay the first frame — pre-warming network, decoding assets, `runApp` awaits — goes
  after boot, not into `main()`.
- **`SplashActivity` (la splash animada de Android) tiene cuatro trampas que ya costaron sangre:**
  (1) `SplashTheme` DEBE heredar de `@android:style/Theme.DeviceDefault.NoActionBar`, NUNCA de
  `Theme.AppCompat.*`. Los atributos `android:windowSplashScreen*` de API 12+ solo los lee el
  sistema si el theme del arranque desciende de DeviceDefault (que en 31+ hereda de
  `Theme.DeviceDefault.SplashScreen`); con AppCompat el bloque se ignora y Android **vuelve a
  pintar su propia pantalla con el ícono del launcher** — literalmente «se ve el logo al
  arrancar», la queja que abrió este trabajo. Por eso la splash no usa ningún `View` de AppCompat:
  es un `SurfaceView` pelado (`SplashCanvasView`) sobre Canvas, que no mira el theme.
  (2) `windowBackground` sigue pintando el campo plano ANTES de la animación — no se puede animar
  ahí, por eso existe la Activity. (3) La Activity pre-calienta el `FlutterEngine`
  (`FlutterEngineCache` + `MainActivity.getCachedEngineId()`): sin eso la splash animada _retarda_
  el arranque en vez de cubrirlo. El coste es `W FlutterEngineCxnRegstry: Attempted to register
  plugin ... already registered` ×7 — redundancia inofensiva y necesaria, porque `main()` lee
  SharedPreferences durante `executeDartEntrypoint`, antes del attach. El handoff es idempotente y
  se diagnostica solo con `adb logcat -s UrbanoSplash` (`anim`/`techo`/`atrás`).
  (4) Ese pre-calentado **bloquea el hilo principal** (~0,65–0,8 s en profile/release, más de 1,5 s
  en debug), así que la animación NO puede vivir en él: `SplashCanvasView` es un `SurfaceView` que
  pinta desde su propio `HandlerThread` con su `Choreographer`, el reloj arranca en el primer frame
  de ese hilo (no en `onCreate`) y el engine se levanta recién en `setOnFirstFrameListener`. Con
  una `View` común y el warm en `onCreate`, el primer frame llegaba con la animación ya vencida y
  solo se veía el campo verde. El arte copia las medidas de `SplashGate` (bloque en
  `Alignment(0, -0.3)` del área segura, escudo y logo de los mismos PNG, Montserrat leída de `flutter_assets`) y termina en su estado
  de entrada (`Preparando la app`, barra al 10 %, anillos a medio trazar) para que el relevo no
  retroceda; la Activity es edge-to-edge con las barras del `_chrome` de Dart.
  `UrbanoSplashApplication` sigue existiendo porque el manifest reemplaza el `${applicationName}`,
  pero ya no pre-calienta nada: `SplashCanvasView` pinta sin parseo ni caché de composición.
- **`disableAnimations` removes MOTION, not the loading screen.** `SplashGate` always mounts the
  cover; `_SplashCover` reads `Motion.reduced` itself and freezes the painted timeline at `restT` (= the
  rest state: rings traced, dial and bar in place, exit not started) with a `Motion.settle` hold whose
  only job is lifting it. Skipping the cover entirely under reduce-motion is a silent "no aparece la
  pantalla de carga": the engine sets `disableAnimations` when **any** of the three animation scales
  is 0, so OEM battery saver (Honor/Huawei push `animator_duration_scale` to 0) hides it without the
  user asking. A splash is state, not decoration. To diagnose, read `settings get global
animator_duration_scale` — the key is `animator_duration_scale`, NOT `animator_animation_scale`
  (which simply returns `null` and looks like "unset = enabled").
- **The AndroidManifest deliberately has NO `<queries>` block.** The Flutter template ships a
  `PROCESS_TEXT` query, and that is what makes the engine's `io.flutter.plugin.text.ProcessTextPlugin`
  resolve _every_ text-processing app on the phone (Claude, ChatGPT, Grok, DeepSeek, Edge, Google,
  SwiftKey…) and load their icons/labels into Urbano's process on each text selection — exactly the
  `W/.example.urbano: ApkAssets: Deleting an ApkAssets object …` wall the user asked to remove. With
  the query gone the same session logs **0** of those lines (measured on the Honor with `adb logcat`:
  type → select all → open the toolbar overflow). What is left is not ours: the system/OEM services
  the process binds anyway (Talkback = accessibility, `HnFileService`, `com.hihonor.assistant`) and
  other processes' lines (the launcher loading our APK prints as `W/ndroid.launcher`). The trade-off
  is real and accepted: Urbano's selection toolbar no longer lists external "process/translate text"
  apps, and no code or screen depends on them. Don't re-add the block to "fix" a visibility warning —
  this app has no `url_launcher`/`share_plus`, so there is nothing that needs package visibility.
- **Ambient motion is bounded by contract.** The idle life of the app lives in
  `Ambient` / `Bob` / `LiveDot` (`core/animation/motion.dart`) plus `HomeRouteLattice`
  (the header paints Santa Cruz's anillos with a bus that drives through them), the
  planner's scan bar and the self-drawing `_LegRail` of `option.legs`. `Ambient` runs ONE `forward()` over `period * cycles` and **rests at
  `t = 1`**; `Motion.phase(t, cycles)` recovers the per-lap phase. Never swap that for
  `controller.repeat(count: n)`: repeat returns the value to `min`, which erases a
  freshly drawn rail and re-opaques a halo, and an endless ticker freezes the 6 s
  `pumpAndSettle` budgets the planner tests use (both shell branches stay mounted, so a
  home-tab loop counts against a `/journey` test). `app_motion_test.dart` locks this;
  keep total idle time per mount under ~5 s.
- **Route-badge Hero flight**: the tag is `route-badge-<prefix>-<id>` and the prefix
  must match between the list and the detail. The detail reads it from the URL
  (`UrbanoRoutes.routeDetail(id, from: 'home')` → `?from=` → `heroPrefix`), because
  the shell keeps both branches mounted (a shared tag would throw "multiple heroes
  with the same tag"). Any new list that navigates to the detail has to pass its own
  `from:` or the badge silently stops flying. Locked by `test/app_motion_test.dart`.
- **Never put dark text/icons on dark surfaces** (and never white on a light
  fill) — the rule is stated at the top of `core/theme/app_colors.dart` and both
  themes are first-class: no hardcoded `Colors.white` / `Colors.black` /
  `Colors.red.shade700` for content. Text, icons and borders go through
  `AppColors.legible(tint, background)` when the color comes from a GTFS route
  (arbitrary: `2C3E50` is near-black, `F1C40F` near-white) and
  `AppColors.onColor(fill, preferred: textColor)` when it sits on a **solid**
  tint; semantic colors come from the scheme (`colors.error`, `colors.primary…`).
  Measure the background that is actually painted (`Color.lerp(surface, tint, α)`
  for a translucent fill), not the raw token. Locked by
  `test/complaints_feed_test.dart` and `test/nearby_micros_screen_test.dart`
  (contrast measured in dark and light).
- The `/journey` slice is hexagonal like the backend:
  `journey/domain` (places, query, planner state, `decideEndpointDrag`),
  `journey/application` (Riverpod controller, results projection, providers),
  `journey/data` (GTFS/HTTP models + repo) and `journey/presentation`
  (screen + widgets). Presentation still re-exports application so existing
  test imports keep working; new code should import `application/` or
  `domain/` directly. The standing (non-`autoDispose`)
  `journeyPlannerControllerProvider` holds origins/destinations (the shown
  `origin`/`destination` fields vs the committed `plan*` points), the debounced
  replan window, the anti-zoom drop barrier and the micros layers. `copyWith`
  uses the sentinel `keepJourneyField`: omit the parameter to KEEP the field,
  pass `null` to CLEAR it, pass a value to REPLACE it. Above it,
  `journey_planner_screen.dart` is just the UI wiring (map `GlobalKey`,
  draggable sheet) and `journey/presentation/widgets/` are pure
  props/callbacks. Keep new trip policy in `domain/`, orchestration in the
  controller, and new journey UI in those widgets. Tests lock behavior around
  the debounce delays (600/700 ms planner, 350 ms picker) and the "pin drop
  right after a camera gesture is discarded" barrier — don't change those
  without reading `test/journey_result_map_test.dart` first (and
  `test/endpoint_drag_policy_test.dart` for the pure decision). **Viaje NO
  tiene globo «¿A dónde vas?» ni panel de origen/destino** (el usuario lo pidió
  explícitamente; se retiraron `planner-trigger`, `JourneyPlannerCard`, su
  botón de cerrar, el selector de lugares y `pendingPlannerPanelProvider`): el
  viaje se arma SOLO en la portada (`showJourneyDestinationSheet`, que no deja
  planificar con los extremos a < 150 m: `DestinationDraft.tooClose`, misma regla
  que el planeador y el backend en `domain/endpoint_distance.dart`) y en `/journey`
  se edita tocando un pin (abre `/journey/pick` encima del punto) o
  arrastrándolo. «Quitar resultados» limpia y vuelve a Inicio. Si la primera
  búsqueda falla, la carga se retira y un snack lo dice. La hoja de resultados
  nunca se cierra del todo (mínimo 0.18) y recogida su asa `journey-sheet-grip`
  es una píldora con flecha que la reabre con un toque. Los tests arman el viaje
  con `test/helpers/plan_trip.dart` (`planTripFromHome`). Locked by
  `test/journey_results_trigger_test.dart`. Walk legs may carry a street-network
  `geometry` (OTP2); the map widget renders that instead of the straight fallback.
  In both cases the walk's bus-side endpoint is joined to the bus `geometry`
  (`connectWalkAndBusGeometry` in the API, `JourneyMapGeometry.joinWalkToBus` in the app): the shape
  never moves — it is the truth of where the micro passes — and the dashed walk is
  stretched to it, so no 10-20 m gap reads as "it makes me cross the avenue".

## API contract

`docs/api-contract.md` is the source of truth; keep it, the Flutter client
(`core/network/endpoints.dart`), and Swagger annotations in sync when changing endpoints.

- **Geometry direction is a server invariant** (see `docs/api-contract.md`,
  section Journey): `geometry` always runs `fromStop` (board) → `toStop`
  (alight). The backend enforces it with `orientBusLegGeometry` for both OTP
  and the internal planner. The client (`JourneyLeg.mapPoints`) must **not**
  reorient — it only draws. The one correction lived in three layers once and
  caused a long regression; keep it in exactly one place (the backend).

- Success responses are wrapped `{ "data": ..., "meta": ... }`; errors are
  `{ "error": { "statusCode", "message", "details" } }`. Only `GET /health` is unwrapped.
- GTFS conventions: times are `HH:mm:ss` in `America/La_Paz`; hex colors come **without**
  `#` (e.g. `D35400`); GeoJSON coordinates are `[lon, lat]`.
