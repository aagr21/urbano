# Contribuir a Urbano

Guía corta para ponerse a trabajar sin redescubrir el setup.

## Requisitos

- Flutter stable (Dart ≥ 3.5)
- Node.js ≥ 20
- Docker (para Postgres/PostGIS y OTP2)

## Verificación (el "trío final")

```sh
dart format lib test
flutter analyze lib test     # debe pasar con cero issues
flutter test                # suite offline, sin backend
```

Todo el código nuevo debe pasar `analysis_options.yaml` (strict-casts + strict-raw-types
y ~23 lints). No se "resuelve" un lint comentando la regla ni con `// ignore:` sin
razón en español.

## App Flutter (raíz del repo)

```sh
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

Gotcha importante: `lib/src/core/config/env.dart` apunta por defecto al backend de
producción (Vercel). Para desarrollo local pasa siempre `--dart-define=API_BASE_URL=...`
(`http://localhost:3000/api/v1` en desktop, `http://10.0.2.2:3000/api/v1` en emulador
Android, la IP LAN en dispositivo físico). `.vscode/launch.json` ya lo hace y añade
`--dart-define-from-file=config/env.json` para la clave de Google.

Capas de Google: crea `config/env.json` con `{ "GOOGLE_MAPS_API_KEY": "AIza..." }` y
corre con `--dart-define-from-file=config/env.json`. Sin clave, las dos capas de
Google aparecen marcadas "Requiere clave" en vez de ocultarse.

## Backend (siempre `cd backend` primero)

```sh
docker compose up -d          # PostGIS en puerto 5436
npm install
cp .env.example .env
npm run import:gtfs           # importa gtfs.zip
npm run start:dev             # API en http://localhost:3000/api/v1, docs en /docs

# verificar
npm test                      # unit (sin DB)
npm run test:all               # unit + e2e (requiere DB importada, --runInBand)
npm run build                 # debe compilar
```

No existe `npm run lint`: eslint no está en `devDependencies` y no hay config.
Verifica cambios de backend con `npm test` + `npm run build`.

## Convenciones de diseño

- Valores visuales solo desde tokens: `AppColors`, `AppSpace`, `AppRadius`
  (`lib/src/core/theme/`). Nada de `BorderRadius.circular(<número>)` ni colores
  literales en `lib/`.
- Toda UI nueva pasa por el motion kit (`Reveal`, `PressScale`, `CountUp`, `Ambient`
  en `core/animation/motion.dart`), nunca por `flutter_animate` (no está en
  `pubspec.yaml`).
- Mapa ≠ tema de la app: las capas del mapa (`MapTile`) cambian solo el mapa base;
  botones, chips y paneles siguen el tema de la app.
- La palabra para "like" es **apoyo** en toda copy de usuario.

## Antes de abrir PR

1. `dart format lib test && flutter analyze lib test && flutter test` en verde.
2. `cd backend && npm test && npm run build` en verde.
3. Si tocaste `assets/lottie/splash.json`, corre `tools/sync-splash-lottie.sh`.
4. Mantén `docs/api-contract.md`, `core/network/endpoints.dart` y las anotaciones
   Swagger en sincronía si cambiaste un endpoint.
```
