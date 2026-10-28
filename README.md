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

# Con las capas de Google activas (ver abajo)
flutter run -d chrome --dart-define-from-file=config/env.json
```

La base URL se inyecta con `--dart-define=API_BASE_URL=...`
(ver `lib/src/core/config/env.dart`); el default compilado es la IP de la red
local `http://192.168.1.40:3000/api/v1`, así que conviene pasarla explícita.
El contrato exacto del API vive en `docs/api-contract.md`.

#### Capas de Google en el mapa

El botón de capas del mapa ofrece siempre cuatro capas: Mapa (OpenStreetMap),
Mapas y Satélite (Google) y Oscuro (MapTiler). Las dos de Google usan la
**Map Tiles API** y necesitan clave; sin ella aparecen marcadas como
«Requiere clave» en vez de esconderse.

```sh
# 1) Escribe tu clave en config/env.json (no la subes a git)
#    { "GOOGLE_MAPS_API_KEY": "AIza..." }
# 2) Ejecuta leyendo ese archivo
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1 \
  --dart-define-from-file=config/env.json
```

En VS Code ya hay configuraciones de lanzamiento que usan ese archivo
(`.vscode/launch.json`). La clave se pide en Google Cloud → _Map Tiles API_
(`createSession` + `2dtiles`); el resto de capas funciona sin ninguna clave.

> **Android**: `INTERNET`, `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` y
> `usesCleartextTraffic="true"` (para `http://10.0.2.2`) ya están en el
> `AndroidManifest.xml`. **iOS**: permiso de ubicación y `NSAllowsLocalNetworking`
> en `Info.plist`.

## 🧪 Verificación

```sh
dart format lib test
flutter analyze     # sin issues (el analysis_options.yaml es estricto a propósito:
                    # strict-casts + strict-raw-types y ~23 lints de estilo)
flutter test        # suite widget completa OFFLINE (parsers, formatters,
                    # api client, widgets, arrastre de marcadores con motor
                    # simulado, drag/replan, aislamiento del rebuild por GPS,
                    # pantalla-mapa fusionada, flujo de ubicación con fakes)
flutter build web --debug
flutter build apk --debug
```

### 🔌 Integración extremo a extremo

Con el backend levantado (ver arriba), `flutter test test/api_integration_test.dart`
ejecuta los repositorios reales de la app contra la API y PostGIS: stats del
feed, detalle con shape GeoJSON, próximas salidas y el planeador de viaje.
Si el API está caído, esos tests se omiten con un mensaje.

## 🧭 Cómo está construido (para quien desarrolla)

- **Detalle técnico**: decisiones de diseño, identidad visual, motor del mapa y pruebas de arrastre → [docs/arquitectura.md](docs/arquitectura.md)
- **Contrato del API** → [docs/api-contract.md](docs/api-contract.md)
- **Dataset GTFS** → [docs/gtfs-dataset.md](docs/gtfs-dataset.md)
- **Backend** (arquitectura hexagonal, comandos) → [backend/README.md](backend/README.md)

---
