import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/map/fake_map_engine.dart';
import 'package:urbano/src/core/map/map_types.dart';
import 'package:urbano/src/core/router/app_router.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/utils/location.dart';
import 'package:urbano/src/core/widgets/urbano_map.dart';
import 'package:urbano/src/features/journey/data/journey_models.dart';
import 'package:urbano/src/features/journey/data/journey_repository.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';
import 'package:urbano/src/features/journey/presentation/map_picker_screen.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_planner_card.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_result_map.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_results_sheet.dart';

import 'helpers/fake_location_service.dart';
import 'helpers/journey_fixtures.dart';

const JourneyPoint _origin = (lat: -17.78, lon: -63.15);
const JourneyPoint _destination = (lat: -17.79, lon: -63.16);

Widget _mapApp(JourneyOption option) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: SizedBox(
      height: 420,
      child: JourneyResultMap(
        option: option,
        origin: _origin,
        destination: _destination,
        showTiles: false,
      ),
    ),
  ),
);

void main() {
  group('JourneyResultMap', () {
    testWidgets('dibuja geometry, caminatas punteadas y marcadores', (
      tester,
    ) async {
      await tester.pumpWidget(_mapApp(fixtureDirectOption()));
      await tester.pumpAndSettle();

      final map = tester.widget<UrbanoMap>(find.byType(UrbanoMap));
      // 2 tramos de caminata + 1 de micro.
      expect(map.polylines, hasLength(3));

      final walks = map.polylines
          .where((line) => line.color == const Color(0xFF94A3B8))
          .toList();
      expect(walks, hasLength(2));
      expect(walks.first.dashed, isTrue);

      final bus = map.polylines.firstWhere((line) => line.width == 6);
      expect(bus.points, hasLength(3)); // la geometry recortada del shape
      expect(bus.outline, isTrue);

      expect(find.byKey(const ValueKey('journey-map-origin')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('journey-map-destination')),
        findsOneWidget,
      );
    });

    testWidgets('cambia de opción: transbordo y micro sin geometry degradado', (
      tester,
    ) async {
      await tester.pumpWidget(_mapApp(fixtureDirectOption()));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_mapApp(fixtureTransferOption()));
      await tester.pumpAndSettle();

      final map = tester.widget<UrbanoMap>(find.byType(UrbanoMap));
      // 2 caminatas + 2 micros (uno con geometry, otro en línea recta).
      expect(map.polylines, hasLength(4));

      final straightLines = map.polylines
          .where((line) => line.width == 6 && line.points.length == 2)
          .toList();
      expect(straightLines, hasLength(1)); // geometry null → fromStop → toStop
    });

    testWidgets('sin datos de mapa muestra al menos origen y destino', (
      tester,
    ) async {
      final bare = JourneyOption.fromJson(const {
        'type': 'direct',
        'departAt': '06:03:00',
        'arriveAt': '06:41:00',
        'durationMinutes': 38,
        'legs': [
          {'kind': 'bus', 'routeId': '1', 'routeColor': 'D35400'},
        ],
      });
      expect(bare.hasMapData, isFalse);

      await tester.pumpWidget(_mapApp(bare));
      await tester.pumpAndSettle();

      final map = tester.widget<UrbanoMap>(find.byType(UrbanoMap));
      expect(map.polylines, isEmpty);
      expect(find.byKey(const ValueKey('journey-map-origin')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('journey-map-destination')),
        findsOneWidget,
      );
      // Sin shortName no hay insignia de ruta (ni error).
      expect(find.byKey(const ValueKey('journey-map-route-0')), findsNothing);
    });
  });

  group('JourneyResultMap · insignias de ruta (qué micro es cada línea)', () {
    testWidgets(
      'la insignia va sobre el punto medio de su tramo, en su color',
      (tester) async {
        await tester.pumpWidget(_mapApp(fixtureDirectOption()));
        await tester.pumpAndSettle();

        // Insignia del micro "1" visible en el mapa.
        final badge = find.byKey(const ValueKey('journey-map-route-0'));
        expect(badge, findsOneWidget);
        expect(find.text('1'), findsOneWidget);

        // La geometry del fixture son 3 puntos equidistantes: el punto medio
        // exacto es el segundo vértice del shape.
        final marker = tester
            .widget<UrbanoMap>(find.byType(UrbanoMap))
            .markers
            .firstWhere((m) => m.id == 'journey-map-route-0');
        expect(marker.point.latitude, closeTo(-17.785, 1e-9));
        expect(marker.point.longitude, closeTo(-63.155, 1e-9));
        expect(marker.draggable, isFalse);

        // El color de la insignia es el de la polilínea del mismo tramo.
        expect((marker.child as dynamic).color, const Color(0xFFD35400));

        // Y la leyenda dice qué micro es con ese mismo color.
        expect(find.text('Micro 1'), findsOneWidget);
        expect(find.text('Caminata'), findsOneWidget);
        expect(find.text('Transbordo'), findsOneWidget);
      },
    );

    testWidgets('transbordo: una insignia por micro y leyenda con ambos', (
      tester,
    ) async {
      await tester.pumpWidget(_mapApp(fixtureTransferOption()));
      await tester.pumpAndSettle();

      // Dos micros → dos insignias con su nombre.
      expect(find.byKey(const ValueKey('journey-map-route-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('journey-map-route-1')), findsOneWidget);
      expect(find.text('101 ANGOSTURA'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      final map = tester.widget<UrbanoMap>(find.byType(UrbanoMap));

      // La segunda ruta no tiene geometry: su insignia cae en el punto
      // medio de la línea recta fromStop → toStop.
      final second = map.markers.firstWhere(
        (m) => m.id == 'journey-map-route-1',
      );
      expect(second.point.latitude, closeTo(-17.7875, 1e-9));
      expect(second.point.longitude, closeTo(-63.1575, 1e-9));

      // Leyenda con los dos micros y la fila de transbordo.
      expect(find.text('Micro 101 ANGOSTURA'), findsOneWidget);
      expect(find.text('Micro 5'), findsOneWidget);
      expect(find.text('Transbordo'), findsOneWidget);
    });
  });

  group('JourneyResultMap · arrastre de marcadores', () {
    testWidgets(
      'origen arrastrable: notifica el punto y el marcador no regresa',
      (tester) async {
        LatLng? moved;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SizedBox(
                height: 420,
                child: JourneyResultMap(
                  option: fixtureDirectOption(),
                  origin: _origin,
                  destination: _destination,
                  showTiles: false,
                  onOriginMoved: (point) => moved = point,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        const dropped = LatLng(-17.77, -63.14);
        tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .debugFireMarkerDrag('journey-map-origin', dropped);
        await tester.pumpAndSettle();

        // La pantalla recibe el nuevo punto…
        expect(moved, isNotNull);
        expect(moved!.latitude, closeTo(dropped.latitude, 1e-9));
        expect(moved!.longitude, closeTo(dropped.longitude, 1e-9));

        // …y hasta que cambien las propiedades el marcador se queda ahí.
        final map = tester.widget<UrbanoMap>(find.byType(UrbanoMap));
        final origin = map.markers.firstWhere(
          (marker) => marker.id == 'journey-map-origin',
        );
        expect(origin.point, dropped);
        expect(origin.draggable, isFalse);

        // La caminata de origen también parte del punto soltado.
        final walk = map.polylines.firstWhere((line) => line.dashed);
        expect(walk.points.first, dropped);
      },
    );

    testWidgets('destino arrastrable: notifica el nuevo punto', (tester) async {
      LatLng? moved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              height: 420,
              child: JourneyResultMap(
                option: fixtureDirectOption(),
                origin: _origin,
                destination: _destination,
                showTiles: false,
                onDestinationMoved: (point) => moved = point,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const dropped = LatLng(-17.80, -63.17);
      tester
          .state<FakeMapEngineState>(find.byType(FakeMapEngine))
          .debugFireMarkerDrag('journey-map-destination', dropped);
      await tester.pumpAndSettle();

      expect(moved, isNotNull);
      expect(moved!.latitude, closeTo(dropped.latitude, 1e-9));

      final map = tester.widget<UrbanoMap>(find.byType(UrbanoMap));
      final destination = map.markers.firstWhere(
        (marker) => marker.id == 'journey-map-destination',
      );
      expect(destination.point, dropped);
    });
  });

  group('JourneyResultMap · tocar extremos para editar', () {
    testWidgets('tocar el pin de origen avisa (abre el selector)', (
      tester,
    ) async {
      var originTaps = 0;
      var destinationTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              height: 420,
              child: JourneyResultMap(
                option: fixtureDirectOption(),
                origin: _origin,
                destination: _destination,
                showTiles: false,
                onOriginTap: () => originTaps++,
                onDestinationTap: () => destinationTaps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<FakeMapEngineState>(find.byType(FakeMapEngine))
          .debugFireMarkerTap('journey-map-origin');
      await tester.pumpAndSettle();

      expect(originTaps, 1);
      expect(destinationTaps, 0);
    });

    testWidgets('tocar el pin de destino avisa (abre el selector)', (
      tester,
    ) async {
      var originTaps = 0;
      var destinationTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              height: 420,
              child: JourneyResultMap(
                option: fixtureDirectOption(),
                origin: _origin,
                destination: _destination,
                showTiles: false,
                onOriginTap: () => originTaps++,
                onDestinationTap: () => destinationTaps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<FakeMapEngineState>(find.byType(FakeMapEngine))
          .debugFireMarkerTap('journey-map-destination');
      await tester.pumpAndSettle();

      expect(destinationTaps, 1);
      expect(originTaps, 0);
    });

    testWidgets('los extremos son fijos (no arrastrables)', (tester) async {
      await tester.pumpWidget(_mapApp(fixtureDirectOption()));
      await tester.pumpAndSettle();

      final map = tester.widget<UrbanoMap>(find.byType(UrbanoMap));
      final origin = map.markers.firstWhere(
        (marker) => marker.id == 'journey-map-origin',
      );
      final destination = map.markers.firstWhere(
        (marker) => marker.id == 'journey-map-destination',
      );
      expect(origin.draggable, isFalse);
      expect(destination.draggable, isFalse);

      // Anclados por la punta: el pin señala el punto exacto.
      expect(origin.anchor, MapMarkerAnchor.bottom);
      expect(destination.anchor, MapMarkerAnchor.bottom);
    });
  });

  group('JourneyPlannerScreen · mapa didáctico único', () {
    Future<ProviderContainer> pumpPlanner(
      WidgetTester tester, {
      List<JourneyQuery>? queryLog,
    }) async {
      final container = ProviderContainer(
        overrides: [
          myLocationProvider.overrideWith(
            (ref) async => const LatLng(-17.7833, -63.1821),
          ),
          journeyProvider.overrideWith((ref, query) async {
            queryLog?.add(query);
            return [fixtureDirectOption(), fixtureTransferOption()];
          }),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
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
      // Se devuelve el contenedor: algunos tests necesitan escribir un
      // provider (p. ej. encender el seguimiento) sin pasar por la UI.
      return container;
    }

    /// Puntos fijos del harness: origen y destino a ~3 km (los antiguos
    /// puntos de prueba; con paradas fuera, el origen/destino solo es punto).
    const originPoint = LatLng(-17.78, -63.15);
    const destinationPoint = LatLng(-17.80, -63.17);

    /// Marca un punto en el mapa como origen/destino (mismo flujo que el
    /// usuario: hoja de selección → "Punto en el mapa" → confirmar).
    Future<void> pickPlace(
      WidgetTester tester,
      String hint, {
      required LatLng point,
    }) async {
      await tester.tap(find.text(hint));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Punto en el mapa'));
      await tester.pumpAndSettle();
      tester
          .state<FakeMapEngineState>(
            find.descendant(
              of: find.byType(MapPickerScreen),
              matching: find.byType(FakeMapEngine),
            ),
          )
          .moveCamera(point, 15);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este punto'));
      await tester.pumpAndSettle();
    }

    // El panel de origen/destino arranca cerrado: se abre con la píldora
    // inferior antes de poder tocar los campos.
    Future<void> openPanel(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('planner-trigger')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'un evento de ubicación mueve SOLO el mapa: el panel y la hoja no se '
      'reconstruyen (regresión de rendimiento)',
      (tester) async {
        final container = await pumpPlanner(tester);

        // Viaje real planificado: así la hoja de resultados también está en el
        // árbol y puede medirse.
        await openPanel(tester);
        await pickPlace(
          tester,
          'Marca un punto en el mapa o usa tu ubicación',
          point: originPoint,
        );
        await pickPlace(
          tester,
          'Marca dónde quieres llegar',
          point: destinationPoint,
        );
        await tester.tap(find.text('Viajar'));
        await tester.pumpAndSettle();
        // Al planificar el panel se guarda solo: se vuelve a abrir para tener
        // también la tarjeta de origen/destino medida.
        await openPanel(tester);

        // Sondas: `JourneyPlannerCard` (panel de origen/destino) y
        // `JourneyResultsSheet` (hoja inferior). Son hijos directos del `build`
        // de la pantalla y se construyen sin `const`, así que su identidad de
        // widget es una prueba directa de si el `build` corrió o no.
        final card = find.byType(JourneyPlannerCard);
        final sheet = find.byType(JourneyResultsSheet);
        final map = find.byType(JourneyResultMap);
        expect(card, findsOneWidget);
        expect(sheet, findsOneWidget);
        expect(map, findsOneWidget);
        final cardBefore = tester.widget(card);
        final sheetBefore = tester.widget(sheet);
        final mapBefore = tester.widget<JourneyResultMap>(map);

        // Encender el seguimiento: eso es exactamente lo que emite el stream de
        // GPS al cambiar la cámara.
        container.read(followLocationProvider.notifier).state = true;
        await tester.pumpAndSettle();

        // El mapa SÍ vio el cambio (el test no es vacío: la aislación existe,
        // no se traga los eventos).
        expect(
          tester.widget<JourneyResultMap>(map),
          isNot(same(mapBefore)),
          reason: '_LiveMapLayer debe reconstruir el mapa con el seguimiento',
        );
        // El resto del árbol quedó en su sitio: antes, el `build` de la
        // pantalla miraba `locationControllerProvider` y cada posición nueva
        // reconstruía panel, chips, controles y hoja de resultados.
        expect(
          tester.widget(card),
          same(cardBefore),
          reason:
              'un tick de GPS no debe reconstruir el panel de origen/destino',
        );
        expect(
          tester.widget(sheet),
          same(sheetBefore),
          reason: 'un tick de GPS no debe reconstruir la hoja de resultados',
        );
      },
    );

    testWidgets(
      'el botón swap queda separado de los iconos de mapa/editar de los '
      'campos (regresión: antes se encimaba)',
      (tester) async {
        await pumpPlanner(tester);
        await tester.pump();
        await openPanel(tester);

        final swap = tester.getRect(
          find.byTooltip('Invertir origen y destino'),
        );
        final mapIcons = find.byTooltip('Elegir en el mapa');
        expect(mapIcons, findsNWidgets(2));

        // El swap vive sobre el conector del timeline (izquierda): debe
        // quedar ENTERO a la izquierda de los iconos de mapa de ambos
        // campos, con holgura real (≥80 px en la superficie de test), y sin
        // tocar el borde derecho de ningún campo.
        var minGap = double.infinity;
        for (final element in mapIcons.evaluate()) {
          final rect = tester.getRect(find.byWidget(element.widget));
          expect(swap.right, lessThanOrEqualTo(rect.left));
          minGap = math.min(minGap, rect.left - swap.right);
        }
        expect(minGap, greaterThanOrEqualTo(80));

        // Verticalmente centrado sobre el conector entre ambos puntos.
        expect(swap.center.dy, greaterThan(swap.height)); // bajo el punto verde
      },
    );

    testWidgets('el mapa es la MISMA instancia antes y después de planificar y '
        'sincroniza con la opción seleccionada', (tester) async {
      await pumpPlanner(tester);
      await tester.pump();

      // Modo exploración: mapa montado + píldora, panel cerrado, sin capas
      // de viaje.
      final mapElement = tester.element(find.byType(JourneyResultMap));
      expect(find.byType(JourneyResultMap), findsOneWidget);
      expect(find.textContaining('Marca origen y destino'), findsOneWidget);
      expect(find.text('Opción 1 en el mapa'), findsNothing);
      // Los campos de origen/destino están ocultos hasta abrir el panel.
      expect(
        find.text('Marca un punto en el mapa o usa tu ubicación'),
        findsNothing,
      );

      await openPanel(tester);
      await pickPlace(
        tester,
        'Marca un punto en el mapa o usa tu ubicación',
        point: originPoint,
      );
      await pickPlace(
        tester,
        'Marca dónde quieres llegar',
        point: destinationPoint,
      );

      await tester.tap(find.text('Viajar'));
      await tester.pumpAndSettle();

      // Mapa con la primera opción + hoja con la lista de opciones.
      // IDENTIDAD: el Element (y su State) del mapa no cambió → la vista
      // nativa no se creó ni se destruyó entre estados.
      expect(tester.element(find.byType(JourneyResultMap)), same(mapElement));
      expect(find.text('Opción 1 en el mapa'), findsOneWidget);
      expect(find.text('En el mapa'), findsOneWidget);
      // La "pantalla completa" ya no es una pantalla separada (el mapa fusionado
      // ES la pantalla, UNA sola instancia): ahora es solo un toggle dentro de
      // los controles del mapa.
      expect(find.byType(JourneyResultMap), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

      // Al tocar otra tarjeta, el mapa cambia a esa opción (con transbordo).
      await tester.scrollUntilVisible(
        find.text('55 min'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('55 min'));
      await tester.pumpAndSettle();

      expect(find.text('Opción 2 en el mapa'), findsOneWidget);
      expect(find.text('En el mapa'), findsOneWidget);
      // Seguimos con el MISMO mapa (solo cambió la capa dibujada).
      expect(tester.element(find.byType(JourneyResultMap)), same(mapElement));
    });

    testWidgets(
      'la pantalla completa oculta paneles y barra; salir los restaura',
      (tester) async {
        await pumpPlanner(tester);
        await tester.pump();

        // Planifica para tener hoja de resultados + barra del shell visibles.
        await openPanel(tester);
        await pickPlace(
          tester,
          'Marca un punto en el mapa o usa tu ubicación',
          point: originPoint,
        );
        await pickPlace(
          tester,
          'Marca dónde quieres llegar',
          point: destinationPoint,
        );
        await tester.tap(find.text('Viajar'));
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Opción 1 en el mapa'), findsOneWidget);

        // Entra en pantalla completa desde los controles del mapa.
        await tester.tap(find.byIcon(Icons.fullscreen_rounded));
        await tester.pumpAndSettle();

        // Solo queda el mapa: sin hoja de resultados, sin panel/píldora y sin
        // la barra inferior del shell; el botón ahora ofrece salir.
        expect(find.text('Opción 1 en el mapa'), findsNothing);
        expect(find.byKey(const ValueKey('planner-trigger')), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
        expect(find.byType(JourneyResultMap), findsOneWidget);

        // Sale de pantalla completa y todo vuelve a su sitio.
        await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Opción 1 en el mapa'), findsOneWidget);
        expect(find.byKey(const ValueKey('planner-trigger')), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'los pines de origen/destino fijados se ven EN EL MAPA antes de '
      'planificar, y la cámara se mueve hasta ellos (regresión: solo se '
      'dibujaban con resultados, así que lo marcado no se reflejaba)',
      (tester) async {
        await pumpPlanner(tester);
        await tester.pump();

        // Modo exploración sin puntos: el mapa NO pinta extremos.
        List<MapMarker> markers() =>
            tester.widget<UrbanoMap>(find.byType(UrbanoMap)).markers;
        expect(
          markers().where((m) => m.id == 'journey-map-origin'),
          isEmpty,
          reason: 'sin origen fijado no debe haber pin de origen',
        );

        final before = tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .camera
            .center;

        // Fija SOLO el origen.
        await openPanel(tester);
        await pickPlace(
          tester,
          'Marca un punto en el mapa o usa tu ubicación',
          point: originPoint,
        );
        await tester.pumpAndSettle();

        expect(
          markers().where((m) => m.id == 'journey-map-origin').toList(),
          hasLength(1),
          reason: 'lo marcado debe verse reflejado en el mapa, sin planificar',
        );
        expect(
          markers().where((m) => m.id == 'journey-map-destination'),
          isEmpty,
          reason: 'el destino aún no está fijado: no se pinta',
        );

        final afterOrigin = tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .camera
            .center;
        expect(
          afterOrigin,
          isNot(equals(before)),
          reason: 'la cámara debe moverse hasta el punto fijado',
        );
        expect(afterOrigin.latitude, closeTo(originPoint.latitude, 0.01));
        expect(afterOrigin.longitude, closeTo(originPoint.longitude, 0.01));

        // Fija también el destino: ahora hay DOS pines.
        await pickPlace(
          tester,
          'Marca dónde quieres llegar',
          point: destinationPoint,
        );
        await tester.pumpAndSettle();

        expect(
          markers().where((m) => m.id == 'journey-map-origin').toList(),
          hasLength(1),
        );
        expect(
          markers().where((m) => m.id == 'journey-map-destination').toList(),
          hasLength(1),
        );
      },
    );

    testWidgets(
      'arrastrar el origen re-planifica (chip "Recalculando…" + debounce)',
      (tester) async {
        await pumpPlanner(tester);
        await tester.pump();

        await openPanel(tester);
        await pickPlace(
          tester,
          'Marca un punto en el mapa o usa tu ubicación',
          point: originPoint,
        );
        await pickPlace(
          tester,
          'Marca dónde quieres llegar',
          point: destinationPoint,
        );

        await tester.tap(find.text('Viajar'));
        await tester.pumpAndSettle();

        final mapElement = tester.element(find.byType(JourneyResultMap));
        expect(find.byType(JourneyResultMap), findsOneWidget);
        expect(find.text('Recalculando…'), findsNothing);

        // Simula el drop nativo del marcador de origen.
        const dropped = LatLng(-17.77, -63.14);
        tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .debugFireMarkerDrag('journey-map-origin', dropped);
        await tester.pump();

        // Mientras corre el debounce el mapa sigue visible con el aviso.
        expect(find.text('Recalculando…'), findsOneWidget);
        expect(find.byType(JourneyResultMap), findsOneWidget);

        // Pasa el debounce (600 ms) y la nueva consulta termina.
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        expect(find.text('Recalculando…'), findsNothing);
        expect(find.byType(JourneyResultMap), findsOneWidget);
        expect(tester.element(find.byType(JourneyResultMap)), same(mapElement));

        // El campo de origen ahora es el punto soltado (re-planificado).
        expect(
          find.textContaining('Punto en el mapa · -17.77000, -63.14000'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'soltar el origen y el destino en la MISMA ventana de debounce aplica '
      'los DOS puntos (regresión: el debounce compartido cancelaba el '
      'primero y el viaje se planificaba con un punto viejo)',
      (tester) async {
        final queries = <JourneyQuery>[];
        await pumpPlanner(tester, queryLog: queries);
        await tester.pump();

        await openPanel(tester);
        await pickPlace(
          tester,
          'Marca un punto en el mapa o usa tu ubicación',
          point: originPoint,
        );
        await pickPlace(
          tester,
          'Marca dónde quieres llegar',
          point: destinationPoint,
        );

        await tester.tap(find.text('Viajar'));
        await tester.pumpAndSettle();

        // Drop de origen… sin esperar los 600 ms del debounce…
        tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .debugFireMarkerDrag(
              'journey-map-origin',
              const LatLng(-17.77, -63.14),
            );
        await tester.pump();

        // …y drop de destino dentro de la MISMA ventana.
        tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .debugFireMarkerDrag(
              'journey-map-destination',
              const LatLng(-17.80, -63.17),
            );
        await tester.pump();

        // Pasa el debounce de ambos: los DOS campos deben reflejar lo soltado.
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Punto en el mapa · -17.77000, -63.14000'),
          findsOneWidget,
          reason: 'el origen soltado se aplicó',
        );
        expect(
          find.textContaining('Punto en el mapa · -17.80000, -63.17000'),
          findsOneWidget,
          reason: 'el destino soltado se aplicó',
        );

        // Y la CONSULTA definitiva lleva los DOS puntos soltados: con el
        // debounce compartido el origen se cancelaba y se planificaba con el
        // punto viejo aunque el campo ya mostraba el nuevo.
        expect(
          queries.last.originPoint,
          equals((lat: -17.77, lon: -63.14)),
          reason: 'la replanificación usó el origen soltado',
        );
        expect(
          queries.last.destinationPoint,
          equals((lat: -17.80, lon: -63.17)),
          reason: 'la replanificación usó el destino soltado',
        );
      },
    );

    testWidgets(
      'al soltar un extremo, el campo refleja las coordenadas AL INSTANTE '
      '(sin esperar el debounce; la replanificación sigue coactuada)',
      (tester) async {
        await pumpPlanner(tester);
        await tester.pump();

        await openPanel(tester);
        await pickPlace(
          tester,
          'Marca un punto en el mapa o usa tu ubicación',
          point: originPoint,
        );
        await pickPlace(
          tester,
          'Marca dónde quieres llegar',
          point: destinationPoint,
        );
        await tester.tap(find.text('Viajar'));
        await tester.pumpAndSettle();

        // Simula el drop nativo del marcador de origen…
        tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .debugFireMarkerDrag(
              'journey-map-origin',
              const LatLng(-17.77, -63.14),
            );
        // …y mira AL INSTANTE (un frame, sin pasar los 600 ms del debounce).
        await tester.pump();

        expect(
          find.textContaining('Punto en el mapa · -17.77000, -63.14000'),
          findsOneWidget,
          reason: 'las coordenadas del campo deben cambiar al soltar el punto',
        );
        // La replanificación de red sigue coactuada por el debounce.
        expect(find.text('Recalculando…'), findsOneWidget);

        // Consume el debounce para no dejar timers pendientes al terminar.
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'las coordenadas son DINÁMICAS durante el arrastre (fase `move`): '
      'el campo cambia mientras el dedo se mueve, sin esperar a soltarlo',
      (tester) async {
        await pumpPlanner(tester);
        await tester.pump();

        await openPanel(tester);
        await pickPlace(
          tester,
          'Marca un punto en el mapa o usa tu ubicación',
          point: originPoint,
        );
        await pickPlace(
          tester,
          'Marca dónde quieres llegar',
          point: destinationPoint,
        );
        await tester.tap(find.text('Viajar'));
        await tester.pumpAndSettle();

        // Evento intermedio del arrastre (el dedo sigue moviéndose)…
        tester
            .state<FakeMapEngineState>(find.byType(FakeMapEngine))
            .debugFireMarkerDrag(
              'journey-map-origin',
              const LatLng(-17.775, -63.145),
              phase: MapMarkerDragPhase.move,
            );
        // …y el campo lo refleja en UN frame: ni al soltar ni tras los 600 ms.
        await tester.pump();

        expect(
          find.textContaining('Punto en el mapa · -17.77500, -63.14500'),
          findsOneWidget,
          reason:
              'las coordenadas deben seguir el arrastre mientras se arrastra',
        );
        // La replanificación de red sigue coactuada al debounce.
        expect(find.text('Recalculando…'), findsOneWidget);

        // Consume el debounce para no dejar timers pendientes al terminar.
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('soltar el extremo EXACTAMENTE donde ya estaba NO replanifica: '
        'un pellizco de zoom cancelado devuelve el punto de arranque y el '
        'viaje debe quedar intacto', (tester) async {
      final queries = <JourneyQuery>[];
      await pumpPlanner(tester, queryLog: queries);
      await tester.pump();

      await openPanel(tester);
      await pickPlace(
        tester,
        'Marca un punto en el mapa o usa tu ubicación',
        point: originPoint,
      );
      await pickPlace(
        tester,
        'Marca dónde quieres llegar',
        point: destinationPoint,
      );
      await tester.tap(find.text('Viajar'));
      await tester.pumpAndSettle();
      expect(queries, hasLength(1));

      // Pellizco que el detector cancela: hubo move intermedio (marcó el
      // recalculo) y el end llega EXACTAMENTE al punto de arranque.
      tester
          .state<FakeMapEngineState>(find.byType(FakeMapEngine))
          .debugFireMarkerDrag(
            'journey-map-origin',
            const LatLng(-17.77, -63.14),
            phase: MapMarkerDragPhase.move,
          );
      await tester.pump();
      expect(find.text('Recalculando…'), findsOneWidget);

      tester
          .state<FakeMapEngineState>(find.byType(FakeMapEngine))
          .debugFireMarkerDrag(
            'journey-map-origin',
            const LatLng(-17.78, -63.15), // punto de arranque del pin
          );
      await tester.pump();

      expect(
        find.text('Recalculando…'),
        findsNothing,
        reason: 'el pin volvió a su punto de arranque: no hay recalculo',
      );

      // Pasado el debounce no se consulta nada más.
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();
      expect(
        queries,
        hasLength(1),
        reason: 'la consulta original no debe repetirse',
      );

      // El campo refleja el punto FINAL del gesto (las coordenadas del
      // arranque): sin replanificar porque las coordenadas ya eran esas.
      expect(
        find.textContaining('Punto en el mapa · -17.78000, -63.15000'),
        findsOneWidget,
      );
    });
  });

  group('JourneyResultMap · caminatas por la red viaria (OTP)', () {
    // Opción cuyo acceso y egreso a pie vienen con geometría trazada por la
    // red viaria (motor OTP2): el cliente debe dibujar ESE trazo, no una
    // línea recta que atraviese manzanas.
    JourneyOption optionWithWalkGeometry() => JourneyOption.fromJson(const {
      'type': 'direct',
      'departAt': '06:03:00',
      'arriveAt': '06:41:00',
      'durationMinutes': 38,
      'walkToStop': {
        'id': 'S10',
        'name': 'Parada 10',
        'distanceMeters': 80,
        'lat': -17.78,
        'lon': -63.15,
      },
      'walkFromStop': {
        'id': 'S200',
        'name': 'Parada 200',
        'distanceMeters': 120,
        'lat': -17.7895,
        'lon': -63.1595,
      },
      'legs': [
        {
          'kind': 'walk',
          'durationMinutes': 2,
          'distanceMeters': 80,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [-63.15, -17.78],
              [-63.1505, -17.7805],
              [-63.1512, -17.781],
              [-63.15, -17.7812],
            ],
          },
        },
        {
          'kind': 'bus',
          'routeId': '1',
          'routeShortName': '1',
          'routeColor': 'D35400',
          'tripId': 'T1',
          'fromStopId': 'S10',
          'toStopId': 'S200',
          'departAt': '06:03:00',
          'arriveAt': '06:39:00',
          'stops': 12,
          'fromStop': {
            'id': 'S10',
            'name': 'Parada 10',
            'lat': -17.78,
            'lon': -63.15,
          },
          'toStop': {
            'id': 'S200',
            'name': 'Parada 200',
            'lat': -17.7895,
            'lon': -63.1595,
          },
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [-63.15, -17.7812],
              [-63.155, -17.785],
              [-63.1595, -17.7895],
            ],
          },
        },
        {
          'kind': 'walk',
          'durationMinutes': 3,
          'distanceMeters': 120,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [-63.1595, -17.7895],
              [-63.1598, -17.7899],
              [-63.16, -17.79],
            ],
          },
        },
      ],
    });

    testWidgets('dibuja la geometría a pie cuando el backend la provee', (
      tester,
    ) async {
      await tester.pumpWidget(_mapApp(optionWithWalkGeometry()));
      await tester.pumpAndSettle();

      final map = tester.widget<UrbanoMap>(find.byType(UrbanoMap));
      // 2 caminatas (con geometría) + 1 micro.
      expect(map.polylines, hasLength(3));

      final walks = map.polylines
          .where((line) => line.color == const Color(0xFF94A3B8))
          .toList();
      expect(walks, hasLength(2));
      expect(walks.every((line) => line.dashed), isTrue);

      // La caminata de acceso usa TODOS los puntos del trazo por calle (4),
      // no solo los 2 extremos de la línea recta origen → parada.
      final access = walks.firstWhere((line) => line.points.length >= 2);
      expect(access.points, hasLength(4));
      expect(access.points.first, const LatLng(-17.78, -63.15));
      expect(access.points.last, const LatLng(-17.7812, -63.15));

      // La caminata de egreso también respeta su trazo por calle y termina
      // en el pin de destino.
      final egress = walks.firstWhere(
        (line) =>
            line.points.last.latitude == -17.79 &&
            line.points.last.longitude == -63.16,
      );
      expect(egress.points, hasLength(3));
    });
  });

  group('JourneyResultMap · no re-encuadra si el usuario explora el mapa', () {
    // Opción con un tramo de micro LARGO y sin geometry (línea recta entre
    // sus paradas): sus boundss son mucho más anchos, así que si el viaje
    // se re-encuadra al cambiar de opción, la cámara ALEJA (baja el zoom).
    JourneyOption optionFar() => JourneyOption.fromJson(const {
      'type': 'direct',
      'departAt': '06:03:00',
      'arriveAt': '07:33:00',
      'durationMinutes': 90,
      'legs': [
        {
          'kind': 'bus',
          'routeId': '1',
          'routeShortName': '1',
          'routeColor': 'D35400',
          'tripId': 'T1',
          'fromStopId': 'SfarA',
          'toStopId': 'SfarB',
          'departAt': '06:03:00',
          'arriveAt': '07:29:00',
          'stops': 40,
          'fromStop': {
            'id': 'SfarA',
            'name': 'Parada lejos A',
            'lat': -17.95,
            'lon': -63.45,
          },
          'toStop': {
            'id': 'SfarB',
            'name': 'Parada lejos B',
            'lat': -17.98,
            'lon': -63.48,
          },
        },
      ],
    });

    FakeMapEngineState engine(WidgetTester tester) =>
        tester.state<FakeMapEngineState>(find.byType(FakeMapEngine));

    testWidgets('cambiar de opción re-encuadra el viaje (comportamiento base: '
        'sin gesto del usuario, el cambio de opción sigue encuadrando)', (
      tester,
    ) async {
      await tester.pumpWidget(_mapApp(fixtureDirectOption()));
      await tester.pumpAndSettle();
      final before = engine(tester).camera;

      // Cambio de opción SIN que el usuario mueva la cámara: se re-encuadra.
      await tester.pumpWidget(_mapApp(optionFar()));
      await tester.pumpAndSettle();

      final after = engine(tester).camera;
      expect(
        after.zoom,
        lessThan(before.zoom),
        reason: 'la opción nueva es más ancha: el encuadre debe alejarse',
      );
      expect(after.center, isNot(equals(before.center)));
    });

    testWidgets(
      'si el usuario movió la cámara, cambiar de opción NO re-encuadra: '
      'alejar el mapa y explorar no salta de vuelta al viaje',
      (tester) async {
        await tester.pumpWidget(_mapApp(fixtureDirectOption()));
        await tester.pumpAndSettle();
        tester
            .state<JourneyResultMapState>(find.byType(JourneyResultMap))
            .debugUserMovedCamera();
        final before = engine(tester).camera;

        await tester.pumpWidget(_mapApp(optionFar()));
        await tester.pumpAndSettle();

        expect(
          engine(tester).camera,
          equals(before),
          reason: 'la cámara del usuario debe respetarse',
        );
      },
    );

    testWidgets('fijar un extremo nuevo REACTIVA el auto-encuadre (fue acción '
        'explícita del usuario)', (tester) async {
      await tester.pumpWidget(_mapApp(fixtureDirectOption()));
      await tester.pumpAndSettle();
      tester
          .state<JourneyResultMapState>(find.byType(JourneyResultMap))
          .debugUserMovedCamera();
      final zoomBefore = engine(tester).camera.zoom;

      // La pantalla fija un origen nuevo Y la consulta trae una opción distinta.
      const newOrigin = (lat: -17.77, lon: -63.14);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              height: 420,
              child: JourneyResultMap(
                option: optionFar(),
                origin: newOrigin,
                destination: _destination,
                showTiles: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        engine(tester).camera.zoom,
        lessThan(zoomBefore),
        reason:
            'tras fijar un extremo nuevo, la opción larga debe '
            're-encuadrar de nuevo',
      );
    });
  });
}
