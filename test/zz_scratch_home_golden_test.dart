// Scratch: render del Inicio a PNG para revisar los accesos. Se borra al final.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/network/api_client.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/features/home/data/stats.dart';
import 'package:urbano/src/features/home/presentation/home_providers.dart';
import 'package:urbano/src/features/home/presentation/home_screen.dart';
import 'package:urbano/src/features/journey/application/trip_history_controller.dart';
import 'package:urbano/src/features/journey/data/trip_history.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/presentation/route_providers.dart';

import 'helpers/memory_trip_history_store.dart';

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File('assets/fonts/$file').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _load('Inter', [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf',
      'Inter-ExtraBold.ttf',
    ]);
    await _load('Outfit', [
      'Outfit-Regular.ttf',
      'Outfit-Medium.ttf',
      'Outfit-SemiBold.ttf',
      'Outfit-Bold.ttf',
      'Outfit-ExtraBold.ttf',
    ]);
    final icons = File(
      '/home/arnolguevara/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(
        Future.value(ByteData.view(icons.readAsBytesSync().buffer)),
      );
      await loader.load();
    }
  });

  // En CI no existe la fuente MaterialIcons local; los íconos se pintan
  // como cuadrados Ahm y el golden nunca coincide. Este test es un scratch
  // de revisión visual — el comentario del archivo indica que se borra al final.
  // Los golden tests se skippean completamente en CI.
  if (Platform.environment['CI'] != 'true') {
    for (final dark in [false, true]) {
      testWidgets('home ${dark ? 'dark' : 'light'}', (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              statsProvider.overrideWith(
                (ref) async => const Stats(
                  routes: 154,
                  stops: 31461,
                  trips: 308,
                  shapes: 130105,
                  service: ServiceWindow(
                    start: '2026-10-06',
                    end: '2027-10-06',
                    days: 'diario',
                  ),
                  firstDeparture: '06:00:00',
                  lastDeparture: '22:00:00',
                  headwaySeconds: 300,
                ),
              ),
              myLocationProvider.overrideWith(
                (ref) async => const LatLng(-17.7833, -63.1821),
              ),
              routesListProvider.overrideWith(
                (ref, query) async =>
                    const Paged<RouteSummary>(items: [], meta: Meta(total: 0)),
              ),
              tripHistoryControllerProvider.overrideWith(
                () => TripHistoryController(
                  MemoryTripHistoryStore([
                    TripHistoryEntry(
                      label: 'Plaza 24 de Septiembre',
                      subtitle: 'Centro histórico',
                      lat: -17.7833,
                      lon: -63.1821,
                      lastUsed: DateTime.now(),
                      durationMinutes: 8,
                    ),
                  ]),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              debugShowCheckedModeBanner: false,
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/images/gobierno-santa-cruz.png'),
            tester.element(find.byType(HomeScreen)),
          );
        });
        await tester.pump();

        await expectLater(
          find.byType(HomeScreen),
          matchesGoldenFile(
            'goldens/check_home_${dark ? 'dark' : 'light'}.png',
          ),
        );
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
