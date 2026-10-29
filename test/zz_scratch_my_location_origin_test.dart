import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:urbano/src/core/location/location_controller.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/map/map_types.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_result_map.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';

List<String> _ids(WidgetTester tester) => tester
    .widget<JourneyResultMap>(find.byType(JourneyResultMap))
    .extraMarkers
    .map((marker) => marker.id)
    .toList();

List<MapPulse> _pulses(WidgetTester tester) =>
    tester.widget<JourneyResultMap>(find.byType(JourneyResultMap)).extraPulses;

void main() {
  testWidgets('scratch: origen = mi ubicación conserva el punto', (
    tester,
  ) async {
    final service = FakeLocationService(
      initialPermission: LocationPermission.whileInUse,
    );
    final container = ProviderContainer(
      overrides: [
        locationServiceProvider.overrideWithValue(service),
        journeyProvider.overrideWith(
          (ref, JourneyQuery query) async => [fixtureDirectOption()],
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    router.go('/journey');
    await tester.pumpAndSettle();

    // El usuario ya movió el mapa: sin seguimiento, punto Dart a la vista.
    container.read(followLocationProvider.notifier).state = false;
    await tester.pumpAndSettle();
    debugPrint(
      'tras soltar seguimiento: ${_ids(tester)} '
      'follow=${container.read(followLocationProvider)} '
      'pulses=${_pulses(tester).length}',
    );

    await tester.tap(find.byKey(const ValueKey('planner-trigger')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marca un punto en el mapa o usa tu ubicación'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Mi ubicación'),
      ),
    );
    await tester.pumpAndSettle();

    debugPrint(
      'tras elegir origen: ${_ids(tester)} '
      'follow=${container.read(followLocationProvider)} '
      'status=${container.read(locationControllerProvider).status} '
      'lastKnown=${container.read(lastKnownLocationProvider)} '
      'pulses=${_pulses(tester).length}',
    );

    await tester.tap(find.text('Viajar'));
    await tester.pumpAndSettle();

    debugPrint(
      'tras planificar: ${_ids(tester)} '
      'follow=${container.read(followLocationProvider)} '
      'pulses=${_pulses(tester).length}',
    );
  });
}
