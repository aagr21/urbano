import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_micros_sheet.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/stops/data/stop_search_models.dart';
import 'package:urbano/src/features/stops/data/stop_search_repository.dart';

import 'helpers/fake_route_repository.dart';

class FakeStopSearchRepository implements StopSearchRepository {
  FakeStopSearchRepository(this.hits);

  final List<StopHit> hits;
  final List<String> calls = [];

  @override
  Future<List<StopHit>> search(String q) async {
    calls.add('q=$q');
    return hits;
  }

  @override
  Future<List<StopHit>> nearby({
    required double lat,
    required double lon,
  }) async {
    calls.add('nearby=$lat,$lon');
    return hits;
  }
}

StopHit _hit(String name, List<StopRouteRef> routes, {double? distance}) =>
    StopHit(
      id: 'S${name.hashCode}',
      name: name,
      lat: -17.78,
      lon: -63.16,
      routes: routes,
      distanceMeters: distance,
    );

const _micros = [
  StopRouteRef(id: '41', shortName: '41', color: 'D35400'),
  StopRouteRef(id: '60', shortName: '60', color: '27AE60'),
];

const _grid = ['41', '60'];

RouteSummary _route(String shortName) => RouteSummary(
  id: shortName,
  shortName: shortName,
  longName: 'Línea $shortName · Centro',
  color: '2980B9',
  textColor: 'FFFFFF',
  description: 'Transporte publico urbano de micros',
  type: 3,
  directionsCount: 2,
  stopCount: 10,
  tripCount: 1,
);

Widget _app(FakeStopSearchRepository stopRepo, LatLng? me) => ProviderScope(
  overrides: [
    routeRepositoryProvider.overrideWithValue(
      FakeRouteRepository(_grid.map(_route).toList()),
    ),
    stopSearchRepositoryProvider.overrideWithValue(stopRepo),
    myLocationProvider.overrideWith((ref) async => me),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Consumer(
      builder: (context, ref, _) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showJourneyMicrosPanel(
              context,
              ref: ref,
              activeDirectionKeys: const {},
              onToggleDirection: (micro, directionId) async {},
              onClearAll: () {},
            ),
            child: const Text('abrir micros'),
          ),
        ),
      ),
    ),
  ),
);

/// Abre el panel, cambia al modo Lugares y deja el estado listo.
Future<void> _openPlaces(
  WidgetTester tester,
  FakeStopSearchRepository stopRepo, {
  LatLng? me,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(stopRepo, me));
  await tester.tap(find.text('abrir micros'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lugares'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'modo Lugares: escribir + confirmar trae esquinas con sus líneas (sin GPS)',
    (tester) async {
      final repo = FakeStopSearchRepository([
        _hit('Avenida Cristo Redentor esquina Calle Sol', _micros),
        _hit('Terminal Bimodal esquina Cuarto Anillo', _micros),
      ]);
      await _openPlaces(tester, repo);

      // Guía inicial: «cerca de mí» o escribir; sin peticiones.
      expect(find.text('Cerca de mí'), findsOneWidget);
      expect(repo.calls, isEmpty);

      // Commit: escribe y confirma con la acción de teclado «Buscar».
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'cristo');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(repo.calls, ['q=cristo']);
      expect(
        find.text('Avenida Cristo Redentor esquina Calle Sol'),
        findsOneWidget,
      );
      expect(
        find.text('Terminal Bimodal esquina Cuarto Anillo'),
        findsOneWidget,
      );

      // Las líneas de cada esquina aparecen como badges tappable.
      expect(find.text('41'), findsWidgets);
      expect(find.text('60'), findsWidgets);
    },
  );

  testWidgets('sin texto y sin GPS: guía, sin resultados fantasma', (
    tester,
  ) async {
    final repo = FakeStopSearchRepository(const []);
    await _openPlaces(tester, repo);
    // No hay consultas de red todavía: la guía manda hasta intención.
    expect(repo.calls, isEmpty);
    expect(find.text('Cerca de mí'), findsOneWidget);
  });
}
