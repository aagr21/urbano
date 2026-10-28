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

`lib/src/core/config/env.dart` defaults `API_BASE_URL` to the **LAN IP
`http://192.168.1.40:3000/api/v1`**, not localhost as `README.md` claims. Always pass it
explicitly for targeted runs:

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
- The left **micros panel** (`journey/presentation/widgets/journey_micros_sheet.dart`,
  tiles in `journey_micros_tile.dart`) keeps its working state — searched text,
  list scroll, cached `/routes` pages and fetched headsign details — in
  `journeyMicrosSessionProvider` (`journey_providers.dart`), so closing and
  reopening the panel restores it and costs no network call (pull-to-refresh
  re-fetches). Keep any new panel state there, never in the panel `State`. The
  drawn routes themselves live in the planner screen (`_visibleRouteKeys`).
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
- Never read `MediaQuery` inside `initState` (the framework asserts as soon as the
  widget mounts under the shell's `MediaQuery`); decide in `didChangeDependencies`
  behind a "started once" guard, the way `_RevealState` does.
- Entrances are already wired where they belong: `AsyncValueView` reveals its data
  when the skeleton retires, `EmptyState`/`ErrorView` reveal themselves, list tiles
  stagger by `index`. Don't wrap those calls in another `Reveal`/`flutter_animate`
  chain — it double-animates and looks cheap.
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
- `journey/presentation/journey_planner_controller.dart` is the state/controller
  of the planner: a standing (non-`autoDispose`) Riverpod
  `NotifierProvider<JourneyPlannerController, JourneyPlannerState>`
  (`journeyPlannerControllerProvider`) holding origins/destinations (the shown
  `origin`/`destination` fields vs the committed `plan*` points), the debounced
  replan window, the anti-zoom drop barrier and the micros layers. Its
  `copyWith` needs explicit `clear*` flags (`clearOrigin`, `clearTime`, …) to
  NULL a field — passing `null` only REPLACES a non-null value. Above it,
  `journey_planner_screen.dart` is just the UI wiring (map `GlobalKey`,
  draggable sheet, open panel) and `journey/presentation/widgets/` are pure
  props/callbacks. Keep new journey logic in the controller and new journey UI
  in those widgets. Tests lock behavior around `ValueKey('planner-trigger')`, the
  debounce delays (600/700 ms planner, 350 ms picker) and the "pin drop right after a
  camera gesture is discarded" barrier — don't change those without reading
  `test/journey_result_map_test.dart` first. Walk legs may carry a street-network
  `geometry` (OTP2); the map widget renders that instead of the straight fallback.

## API contract

`docs/api-contract.md` is the source of truth; keep it, the Flutter client
(`core/network/endpoints.dart`), and Swagger annotations in sync when changing endpoints.

- Success responses are wrapped `{ "data": ..., "meta": ... }`; errors are
  `{ "error": { "statusCode", "message", "details" } }`. Only `GET /health` is unwrapped.
- GTFS conventions: times are `HH:mm:ss` in `America/La_Paz`; hex colors come **without**
  `#` (e.g. `D35400`); GeoJSON coordinates are `[lon, lat]`.
