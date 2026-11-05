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
- Splash de arranque: `tools/sync-splash-lottie.sh` vuelve a minificar `assets/lottie/splash.json`
  hacia `android/app/src/main/assets/splash.json` (obligatorio tras tocar el JSON), y
  `tools/make-ios-splash-frame0.sh` regenera el PNG estático del launch screen de iOS (necesita
  `resvg` o `rsvg-convert`; solo cuando cambie la pose del frame 0).

Backend (always `cd backend` first — the boot order matters):

- `docker compose up -d` → PostGIS on **host port 5436** (not 5432; see `.env` `DB_PORT`)
  and — once `otp-data/graph.obj` exists — **OpenTripPlanner 2 on host port 8081**.
- `npm install && cp .env.example .env && npm run import:gtfs` → imports `gtfs.zip`.
- `npm run fix:gtfs-directions` — dry-run diagnostic of the feed's ida/vuelta orientation; add `--apply`
  (optionally `--routes 75,123`) to rewrite `stop_times.txt`/`shapes.txt` in place. The shipped
  `gtfs.zip` is already repaired (13 routes had `direction_id=1` duplicated in the ida order — see
  `docs/gtfs-dataset.md`); `backend/gtfs.orig.zip` keeps the untouched original. Re-run after pulling a
  new feed, then re-import **and** rebuild the OTP graph.
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
- Skip `npm run lint`: it's broken (eslint isn't in `devDependencies` and no ESLint
  config exists). Verify backend changes with `npm test` + `npm run build`.
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
  whole list with a `"i de N"` counter. The feed card keeps its single bleed photo — it opens the
  detail, which now shows everything. Locked by `test/complaint_photo_gallery_test.dart`; note a
  `PageView` drag in a test must cross half the page width (viewport is 800 px logical by default,
  so `Offset(-500, 0)`), otherwise it settles back on the same photo.
- **The `/complaints` curtain must not eat the first post.** The header card, the category filter
  row and the "La comunidad reporta" row are chrome, not content: the feed's first
  `ComplaintPostCard` (~447 px) has to fit between the list top and the shell's `NavigationBar`
  at 1080×2340@2.75. `_CommunityHeader` is therefore one tight row (badge + title + compact
  `Crear` CTA with tooltip `Crear queja`) above the three `_StatTile`s — no tagline paragraph, no
  full-width button row — and `test/complaints_feed_test.dart` asserts `card.bottom < bar.top` at a
  real phone height (that harness mounts its own `NavigationBar`; `_openFeed` does not). Anything
  new up there goes into the header row or gets scrolled, never stacked below it. Because the CTA
  shares the row with the title, the title is `Expanded > FittedBox(scaleDown)`, **never**
  `TextOverflow.ellipsis` (a long label there truncated "La voz del pasaj…" on real phones); the
  label stays short and its `textStyle` starts from a theme style so it keeps Inter.
- **Text widths measured under `flutter test` are Ahem, not Inter** (one square per glyph, so
  ~1.8× the real string): anything sized by measured text must be re-measured with the real face
  — load it in `setUpAll` with `FontLoader('Inter')` over `assets/fonts/Inter-*.ttf` bytes
  (`dart:io` + cwd = package root), and remember `TextStyle(...)` without `fontFamily` silently
  drops the app's face (only `display/headline/title*` carry Inter via `AppTypography.apply`).
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

- Corners: `AppRadius` (`sm 10 · tile 12 · input 14 · md 16 · lg 24 · xl 32 · pill 999`).
  No `BorderRadius.circular(<número>)` anywhere in `lib/`. `pill` is also correct for thin 4 px
  bars (radius = half the height), so "small number" is not a reason to bypass the scale.
- Spacing `AppSpace`, colors/type `context.colors` / `context.text`
  (`core/utils/extensions.dart`) instead of `Theme.of(context)…`.
  `GlassCard(radius: 20)` is the one known off-scale default (tokenizing it would move pixels);
  don't add more.

## Architecture rules of thumb

Backend (`backend/src/modules/<feature>/{domain,application,infrastructure,presentation}`
— hexagonal, don't put business logic in controllers):

- Controllers only validate + delegate; services depend on port interfaces injected by
  token; TypeORM/PostGIS repos live in `infrastructure/`.
- `DB_SYNCHRONIZE=true` in dev: TypeORM auto-syncs schema on boot; PostGIS/B-tree/`pg_trgm`
  indexes are created idempotently at startup (`DatabaseSetupService`).

Flutter app: Riverpod for state, `go_router` (2 tabs: Inicio · Viaje; the old
Rutas tab now lives as the left micros panel in `/journey`, with per-direction
ida/vuelta toggles; `/map` redirects to `/journey`). There is **no `/routes` list
route** anymore — anything wanting the whole catalogue (the home's "Ver todas")
goes through `UrbanoRoutes.openAllMicros`, which flips the branch and sets
`pendingMicrosPanelProvider`; the planner consumes that flag in `initState` with
`listenManual(fireImmediately: true)` (a `ref.listen` inside `build` misses it when
the Viaje branch has never been visited, because that first build runs in the same
frame as the `go()`). dio in `core/network/`, map
behind the `UrbanoMap`
facade, GPS isolated in `core/location/` (injectable `LocationService` so tests run
without geolocator). `/journey` is a single always-mounted screen — don't recreate the
platform view; the merged map/result-sheet design is deliberate (see README).

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
- The left **micros panel** (`journey/presentation/widgets/journey_micros_sheet.dart`
  = solo la puerta (catálogo + ruta); el cajón vive en `micros_panel.dart` y sus
  secciones en `micros_panel_*.dart`, todas de props/callbacks) keeps its working
  state — searched text, list scroll, cached `/routes` pages and fetched headsign
  details — in `journeyMicrosSessionProvider` (`journey_providers.dart`), so
  closing and reopening the panel restores it and costs no network call
  (pull-to-refresh re-fetches). La lógica de estado/negocio del panel (catálogo,
  filtro, modos, toggles) vive en `application/micros_panel_controller.dart`
  (`microsPanelProvider`); en el `State` del cajón solo quedan animaciones,
  gestos, `TextEditingController` y scroll. Keep any new panel state there, never
  in the panel `State`. The drawn routes themselves live in the planner screen
  (`_visibleRouteKeys`).
- Panel animations are frame-driven (`AnimationController` + implicit widgets);
  this file deliberately avoids `flutter_animate` because its `Animate` mounts a
  zero-duration `Timer`, which breaks widget tests that use plain `pump()`
  ("A Timer is still pending…"). Anything mounted inside the panel must also be
  test-tappable: a `Positioned` child hanging off the panel's edge is not
  hit-testable unless its `Stack`/`SizedBox` is wide enough to contain it.
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
  draws itself, `UrbanoLogo` arriving) must pass an explicit `cycles:`. Builders receive
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
  (it asserts `same()` widget identity for panel/sheet and _not_ `same()` for the map, so
  the guard can't silently become a no-op). Apply the same split to any new live stream.
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
- **The boot splash is ONE phase: `SplashGate`, and it is a LOADING screen, not the brand show.**
  The user asked to see carga — not the logo — at the very first moment the app opens, so
  `core/widgets/splash_gate.dart` mounts no `UrbanoLogo`, no `URBANO` wordmark and no tagline: what
  reads is a spinning dial, the word `Cargando`, the real boot stage under it and a progress bar.
  Identity stays in the background (brand gradient, the Santa Cruz rings tracing themselves, the
  `Santa Cruz de la Sierra · datos GTFS` footer); the logo lives inside the app (home header,
  «Acerca de»). Before `SplashGate` there are now TWO native phases on Android: the OS field
  (`windowSplashScreenBackground` / `windowBackground`, which cannot animate) and
  `android/app/src/main/kotlin/.../SplashActivity.kt`, a Kotlin launcher that plays
  `android/app/src/main/assets/splash.json` for 1,5 s and then hands off to `MainActivity` +
  `finish()` (so it never enters the back stack). That JSON is a full **loading screen** — the same
  art the Dart cover paints (Santa Cruz rings + a coral rotating dial with aqua tail + the baked
  `Cargando` text layer + a progress bar), NOT the brand bus it used to be: the native phase had to
  read as carga, not as a logo show. It lives ONLY in the pre-Flutter native phase and as the source
  of iOS's static frame 0 — it is never replayed inside Dart. iOS has no animated launch (Apple
  rejects it), so `LaunchScreen.storyboard` shows a static reproduction of that frame 0
  (`LaunchImage` imageset, generated by `tools/make-ios-splash-frame0.sh` from
  `assets/lottie/splash-frame0.svg`, which draws `Cargando` with Inter via resvg's `--use-font-file`)
  and then the SAME painted `SplashGate` cover (`_RingsPainter` + `_Dial` + `_Loader`) takes over on
  every platform. Keeping the cover painted everywhere is what avoids doubling the baked text/bar on
  iOS. `launch_background.xml`
  still has no logo, and Android 12+ needs
  `windowSplashScreenAnimatedIcon` = the transparent `urbano_splash_icon_blank` — omit it and the
  launcher icon shows, which is the second splash the user rejected.
  `test/splash_gate_test.dart` covers the cover and native resources are
  checked with `:app:processDebugResources`.
  `windowSplashScreenBackground` is **`urbano_primary`, not `primary_dark`**: a 30 fps `screenrecord`
  of a cold start on the Honor (API 35) measured the native field at srgb(0,34,31) against the
  cover's first frame at srgb(4,55,49) — the dark corner of the gradient made the handoff read as a
  separate green screen. `urbano_primary` is the gradient's average, so the two phases are the same
  color.
- **The cover enters already painted.** `_SplashCover._startT` is `0.14` and the loading windows
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
  `main.dart` — NOT from the home) awaits the same calls the home will show (`statsProvider` +
  `routesListProvider(homeCatalogQuery)`) and never throws: it returns `bool` so an unreachable
  backend still lifts, with the `Sin respuesta del servicio` stage instead of a lying `Todo listo`.
  `bootCeiling` (6 s) is that safety — a loading screen that can trap the user is worse than the
  data it is waiting for. `homeCatalogQuery` is a shared const (`routes/presentation/route_providers.dart`)
  because `SimpleCache` does not dedupe in-flight calls: boot, the micros strip and
  `featuredRouteShapeProvider` must hit the same provider element or `/routes` is paid twice. New
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
  arrancar», la queja que abrió este trabajo. Por eso el Lottie NO usa `LottieAnimationView`
  (que es `AppCompatImageView` y empuja a ese parent): vive en `SplashLottieView`, un `View`
  pelado sobre `LottieDrawable` + `Matrix`, que no mira el theme. (2) `RectangleContent` lanza
  NPE si un `{"ty":"rc"}` del JSON no trae el campo `r` (roundness): el fallo llega como crash
  de la app, no como fallo de carga. (3) `windowBackground` sigue pintando el campo plano ANTES
  de la animación — no se puede animar ahí, por eso existe la Activity. (4) La Activity
  pre-calienta el `FlutterEngine`
  (`FlutterEngineCache` + `MainActivity.getCachedEngineId()`): sin eso la splash animada _retarda_
  el arranque en vez de cubrirlo. El coste es `W FlutterEngineCxnRegstry: Attempted to register
plugin ... already registered` ×7 — redundancia inofensiva y necesaria, porque `main()` lee
  SharedPreferences durante `executeDartEntrypoint`, antes del attach. El handoff es idempotente y
  se diagnostica solo con `adb logcat -s UrbanoSplash` (`anim`/`techo`/`sin-composicion`/
  `fallo-lottie`/`atrás`). El JSON de `android/app/src/main/assets/` es una **copia minificada**
  (`tools/sync-splash-lottie.sh`): editar `assets/lottie/splash.json` sin correr el script deja el
  asset viejo, y el parseo del pretty-debug costaba ~2,3 s de campo quieto. (5) En DEBUG el
  parseo del JSON cuesta ~2,5 s (ART verifica el dex de lottie, JIT frío) incluso minificado, así
  que `onCreate` NO puede pagarlo: se vería verde quieto antes del giro. La solución es el
  `UrbanoSplashApplication` (reemplaza el `${applicationName}` del manifest), cuyo `onCreate` llama
  a `SplashActivity.prewarmComposition` en un hilo aparte para que la composición quede cacheada y
  el `fromAsset` de la Activity responda en ~28 ms. Medido en release el parseo es ~315 ms.
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
  planner's scan bar, the self-drawing `_LegRail` of `option.legs` and the floating
  micros badge. `Ambient` runs ONE `forward()` over `period * cycles` and **rests at
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
  `test/journey_micros_panel_test.dart` (dark and light contrast ≥ 4.5 specs).
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
  draggable sheet, open panel) and `journey/presentation/widgets/` are pure
  props/callbacks. Keep new trip policy in `domain/`, orchestration in the
  controller, and new journey UI in those widgets. Tests lock behavior around
  `ValueKey('planner-trigger')`, the debounce delays (600/700 ms planner,
  350 ms picker) and the "pin drop right after a camera gesture is discarded"
  barrier — don't change those without reading
  `test/journey_result_map_test.dart` first (and `test/endpoint_drag_policy_test.dart`
  for the pure decision). Walk legs may carry a street-network
  `geometry` (OTP2); the map widget renders that instead of the straight fallback.

## API contract

`docs/api-contract.md` is the source of truth; keep it, the Flutter client
(`core/network/endpoints.dart`), and Swagger annotations in sync when changing endpoints.

- Success responses are wrapped `{ "data": ..., "meta": ... }`; errors are
  `{ "error": { "statusCode", "message", "details" } }`. Only `GET /health` is unwrapped.
- GTFS conventions: times are `HH:mm:ss` in `America/La_Paz`; hex colors come **without**
  `#` (e.g. `D35400`); GeoJSON coordinates are `[lon, lat]`.
