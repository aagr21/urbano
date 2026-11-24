import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/widgets/loading_shimmer.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/presentation/route_detail_screen.dart';
import 'package:urbano/src/features/routes/presentation/route_providers.dart';

RouteDetail _detail() => const RouteDetail(
  id: '101 ANGOSTURA',
  shortName: '101',
  longName: '101 ANGOSTURA',
  color: '7F8C8D',
  textColor: 'FFFFFF',
  description: 'Transporte publico urbano de micros',
  type: 3,
  directionsCount: 2,
  stopCount: 84,
  tripCount: 2,
  bbox: [],
  directions: [
    RouteDirection(
      directionId: 0,
      headsign: 'Ida',
      tripId: 'T0',
      firstDeparture: '06:00:00',
      lastDeparture: '22:00:00',
      headwaySeconds: 600,
      stopCount: 84,
    ),
    RouteDirection(
      directionId: 1,
      headsign: 'Vuelta',
      tripId: 'T1',
      firstDeparture: '06:10:00',
      lastDeparture: '22:10:00',
      headwaySeconds: 600,
      stopCount: 84,
    ),
  ],
  shape: null,
);

void main() {
  testWidgets('los esqueletos de calles y paradas caben en un móvil angosto', (
    tester,
  ) async {
    // 320 lógicos: el ancho donde las tres píldoras fijas del esqueleto
    // (96 + 120 + 84) y las tres tarjetas de paradas (120 × 3) desbordaban.
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // El detalle resuelve, pero calles y paradas se quedan cargando: es el
    // estado exacto en el que aparecía el "overflowed by" al final.
    final pendingStops = Completer<List<RouteStop>>();
    final pendingStreets = Completer<List<String>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routeDetailProvider.overrideWith((ref, key) async => _detail()),
          routeStopsProvider.overrideWith((ref, key) => pendingStops.future),
          routeStreetsProvider.overrideWith(
            (ref, key) => pendingStreets.future,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RouteDetailScreen(routeId: '101 ANGOSTURA'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Baja hasta el final: los dos esqueletos viven bajo los botones de
    // sentido y las cápsulas de horario.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pump();

    expect(find.byType(LoadingShimmer), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
