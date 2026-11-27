import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/location/location_service.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/router/urbano_bottom_bar.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/theme/theme_mode_controller.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/complaints/application/passenger_controller.dart';
import 'package:urbano/src/features/journey/application/trip_history_controller.dart';
import 'package:urbano/src/features/journey/data/trip_history.dart';
import 'package:urbano/src/features/profile/presentation/profile_screen.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/routes/presentation/micros_screen.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/fake_route_repository.dart';
import 'helpers/memory_theme_mode_store.dart';
import 'helpers/memory_trip_history_store.dart';

/// Identidad del pasajero en memoria: el store real espera a
/// `SharedPreferences`, que bajo `flutter test` nunca responde.
class _InMemoryIdentityStore implements PassengerIdentityStore {
  ({String deviceKey, String nickname})? saved = (
    deviceKey: 'abc123',
    nickname: 'Tucán Viajero',
  );

  @override
  Future<({String deviceKey, String nickname})?> load() async => saved;

  @override
  Future<void> save({
    required String deviceKey,
    required String nickname,
  }) async => saved = (deviceKey: deviceKey, nickname: nickname);
}

const _route = RouteSummary(
  id: '101',
  shortName: '101',
  longName: 'Micro 101 Angostura',
  color: '7F8C8D',
  textColor: 'FFFFFF',
  description: 'Transporte publico urbano de micros',
  type: 3,
  directionsCount: 2,
  stopCount: 84,
  tripCount: 2,
);

/// La barra inferior del diseño: cinco pestañas son ramas del shell y
/// «Lugares» es una acción (abre su hoja).
void main() {
  late MemoryTripHistoryStore history;
  late MemoryThemeModeStore themeStore;

  Future<GoRouter> pumpShell(WidgetTester tester) async {
    history = MemoryTripHistoryStore([
      TripHistoryEntry(
        label: 'Plaza 24 de Septiembre',
        lat: -17.7833,
        lon: -63.1821,
        lastUsed: DateTime.now(),
      ),
    ]);
    themeStore = MemoryThemeModeStore(null);
    final container = ProviderContainer(
      overrides: [
        myLocationProvider.overrideWith(
          (ref) async => const LatLng(-17.7833, -63.1821),
        ),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        routeRepositoryProvider.overrideWithValue(
          FakeRouteRepository(const [_route]),
        ),
        tripHistoryControllerProvider.overrideWith(
          () => TripHistoryController(history),
        ),
        passengerControllerProvider.overrideWith(
          () => PassengerController(_InMemoryIdentityStore()),
        ),
        themeModeStoreProvider.overrideWithValue(themeStore),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return router;
  }

  Future<void> tapTab(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('nav-$id')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  bool selected(WidgetTester tester, String id) {
    final bar = tester.widget<UrbanoBottomBar>(find.byType(UrbanoBottomBar));
    final index = urbanoTabs.indexWhere((tab) => tab.id == id);
    return bar.selectedIndex == index;
  }

  testWidgets('las seis pestañas del diseño, en orden', (tester) async {
    await pumpShell(tester);
    for (final label in const [
      'Inicio',
      'Micros',
      'Viajes',
      'Lugares',
      'Denuncias',
      'Perfil',
    ]) {
      expect(
        find.descendant(
          of: find.byType(UrbanoBottomBar),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: label,
      );
    }
    expect(selected(tester, 'home'), isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Micros y Viajes son ramas del shell', (tester) async {
    final router = await pumpShell(tester);

    await tapTab(tester, 'micros');
    expect(router.state.uri.path, '/micros');
    expect(find.byType(MicrosScreen), findsOneWidget);
    expect(selected(tester, 'micros'), isTrue);

    await tapTab(tester, 'journey');
    expect(router.state.uri.path, '/journey');
    expect(selected(tester, 'journey'), isTrue);

    await tapTab(tester, 'home');
    expect(router.state.uri.path, '/');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Lugares no navega: abre la hoja «¿Qué micro pasa cerca?»', (
    tester,
  ) async {
    final router = await pumpShell(tester);

    await tapTab(tester, 'places');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    expect(find.text('Marcar en el mapa'), findsOneWidget);
    // Sigue marcada la pestaña de donde se abrió.
    expect(selected(tester, 'home'), isTrue);
  });

  testWidgets('Perfil: identidad, tema e historial', (tester) async {
    final router = await pumpShell(tester);

    await tapTab(tester, 'profile');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/profile');
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Tucán Viajero'), findsOneWidget);
    expect(find.text('1 destino guardado en este teléfono.'), findsOneWidget);

    // El tema se elige aquí también, y se persiste.
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(themeStore.lastSaved, ThemeMode.dark);

    // Borrar el historial pide confirmación y vacía el guardado.
    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-clear-history')),
    );
    await tester.tap(find.byKey(const ValueKey('profile-clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('profile-clear-history-confirm')),
    );
    await tester.pumpAndSettle();
    expect(history.saved, isEmpty);
    expect(find.text('Todavía no planificaste viajes.'), findsOneWidget);
  });
}
