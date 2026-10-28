import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/theme/app_colors.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/journey/presentation/journey_markers.dart';
import 'package:urbano/src/features/journey/presentation/journey_planner_controller.dart';
import 'package:urbano/src/features/journey/presentation/widgets/journey_micros_sheet.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';

import 'helpers/contrast.dart';
import 'helpers/fake_route_repository.dart';

RouteSummary _route(
  String shortName,
  String longName, {
  String color = 'D35400',
  String textColor = 'FFFFFF',
}) => RouteSummary(
  id: shortName,
  shortName: shortName,
  longName: longName,
  color: color,
  textColor: textColor,
  description: 'Transporte publico urbano de micros',
  type: 3,
  directionsCount: 2,
  stopCount: 20,
  tripCount: 2,
);

/// `41 · Plan 400`, `60 · Canoto` y `105 · Centro`: nombres distintos para
/// probar el buscador por numeral y por nombre largo.
List<RouteSummary> _tresLineas() => [
  _route('41', 'Línea 41 · Plan 400'),
  _route('60', 'Línea 60 · Canoto'),
  _route('105', 'Línea 105 · Centro'),
];

/// Estado compartido entre el harness y el panel: las claves activas están en
/// el controller del planeador (el panel las mira con `ref.watch`), el
/// harness solo intenta el guard a través del notifier.
class _Harness {
  _Harness({Set<String> active = const {}}) : _seed = active;

  final Set<String> _seed;
  WidgetRef? ref;
  final List<String> toggles = [];
  int clears = 0;

  /// Conecta el harness al arbol de providers y siembra el estado inicial.
  /// El seed va POST-FRAME: modificar un provider dentro del `build` del
  /// Consumer es ilegal («Tried to modify a provider while the widget tree
  /// was building»).
  void attach(WidgetRef newRef) {
    ref = newRef;
    if (_seed.isEmpty) return;
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedActive(_seed));
  }

  bool _attached = false;

  Set<String> get active =>
      ref!.read(journeyPlannerControllerProvider).visibleRouteKeys;

  void toggle(RouteSummary micro, int directionId) {
    final key = microDirectionKey(micro.id, directionId);
    toggles.add(key);
    final current = active;
    _seedActive(
      current.contains(key)
          ? {...current.where((k) => k != key)}
          : {...current, key},
    );
  }

  void clearAll() {
    clears++;
    _seedActive(const {});
  }

  void _seedActive(Set<String> keys) {
    final notifier = ref!.read(journeyPlannerControllerProvider.notifier);
    notifier.state = notifier.state.copyWith(visibleRouteKeys: keys);
  }
}

Widget _app(FakeRouteRepository repo, _Harness state, {bool dark = false}) =>
    ProviderScope(
      overrides: [routeRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) {
            state.attach(ref);
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showJourneyMicrosPanel(
                    context,
                    ref: ref,
                    onToggleDirection: (micro, directionId) async =>
                        state.toggle(micro, directionId),
                    onClearAll: state.clearAll,
                  ),
                  child: const Text('abrir micros'),
                ),
              ),
            );
          },
        ),
      ),
    );

/// Abre el panel y espera la carga paginada + la transición de deslizamiento.
Future<void> _open(
  WidgetTester tester,
  FakeRouteRepository repo,
  _Harness state, {
  bool dark = false,
}) async {
  // Superficie alta: el panel es de altura completa y las tarjetas llevaron
  // su banner de foto (más alto) — con el 800×600 por defecto la tercera
  // tarjeta queda fuera del viewport y no es localizable.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(repo, state, dark: dark));
  await tester.tap(find.text('abrir micros'));
  await tester.pumpAndSettle();
}

/// Cierra el panel por su tirador del borde derecho.
Future<void> _close(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.chevron_left_rounded));
  await tester.pumpAndSettle();
}

/// Vuelve a abrir el panel (con el `ProviderScope` ya montado: la sesión del
/// panel sigue viva, igual que en la app).
Future<void> _reopen(WidgetTester tester) async {
  await tester.tap(find.text('abrir micros'));
  await tester.pumpAndSettle();
}

/// Localiza el chip de dirección de la tarjeta de una línea concreta: las
/// tarjetas se generan en orden del listado, así que el enésimo icono de
/// flecha (ida →, vuelta ←) corresponde a la enésima línea.
Finder _chipIcon(List<RouteSummary> lines, String longName, IconData icon) {
  final index = lines.indexWhere((l) => l.longName == longName);
  return find.byIcon(icon).at(index);
}

/// Desplazamiento vertical del listado del panel (para verificar que el scroll
/// sobrevive a cerrar y reabrir).
double _listOffset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position
    .pixels;

/// Color con el que está pintado un texto del panel (estos lo llevan explícito).
Color _textColor(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style!.color!;

/// Relleno pintado del `Container` antecesor **más inmediato** de [of] (en
/// `find.ancestor` el resultado `.first` es el más cercano, no el más externo).
Color _paintedBackground(
  WidgetTester tester,
  Finder of, {
  bool animated = false,
}) {
  final ancestors = find.ancestor(
    of: of,
    matching: find.byType(animated ? AnimatedContainer : Container),
  );
  final decoration = animated
      ? tester.widget<AnimatedContainer>(ancestors.first).decoration!
      : tester.widget<Container>(ancestors.first).decoration!;
  return (decoration as BoxDecoration).color!;
}

/// Foreground del contenido de un chip de dirección: lo fija el
/// `DefaultTextStyle` que interpola el color, no el `TextStyle` del `Text`.
Color _inheritedTextColor(WidgetTester tester, Finder finder) => tester
    .widget<DefaultTextStyle>(
      find.ancestor(of: finder, matching: find.byType(DefaultTextStyle)).first,
    )
    .style
    .color!;

void main() {
  group('JourneyMicrosPanel', () {
    testWidgets('carga TODAS las líneas paginando /routes hasta meta.total', (
      tester,
    ) async {
      final repo = FakeRouteRepository([
        for (var i = 1; i <= 105; i++) _route('$i', 'Línea $i · Centro'),
      ]);
      final state = _Harness();
      await _open(tester, repo, state);

      // Dos páginas: la primera llena (100) y una segunda con el resto (5).
      expect(repo.listCalls, [
        'page=1 limit=100 sort=name',
        'page=2 limit=100 sort=name',
      ]);
      // El encabezado cuenta las líneas ya cargadas (todas).
      expect(find.text('105 líneas · elige ida o vuelta'), findsOneWidget);

      // La última línea (de la 2ª página) es alcanzable con scroll; con el
      // banner de foto cada tarjeta mide ~230 px (~24 000 px en total), así
      // que el salto tiene que superar con holgura los 50 intentos por
      // defecto de `scrollUntilVisible`.
      await tester.scrollUntilVisible(
        find.text('Línea 105 · Centro'),
        700,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Línea 105 · Centro'), findsOneWidget);
    });

    testWidgets('el buscador filtra por numeral y por nombre (sin red)', (
      tester,
    ) async {
      final repo = FakeRouteRepository(_tresLineas());
      final state = _Harness();
      await _open(tester, repo, state);

      final search = find.byType(TextField);
      expect(
        tester.widget<TextField>(search).decoration?.hintText,
        'Buscar línea…',
      );

      // Por numeral: solo la 60.
      await tester.enterText(search, '60');
      await tester.pumpAndSettle();
      expect(find.text('Línea 60 · Canoto'), findsOneWidget);
      expect(find.text('Línea 41 · Plan 400'), findsNothing);
      expect(find.text('Línea 105 · Centro'), findsNothing);

      // Por nombre largo (insensible a mayúsculas): solo la 60 de nuevo.
      await tester.enterText(search, 'CANOTO');
      await tester.pumpAndSettle();
      expect(find.text('Línea 60 · Canoto'), findsOneWidget);
      expect(find.text('Línea 41 · Plan 400'), findsNothing);

      // Sin coincidencias: estado vacío con el texto buscado.
      await tester.enterText(search, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados para "zzz".'), findsOneWidget);

      // El botón de limpiar del campo restaura el listado completo.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Línea 41 · Plan 400'), findsOneWidget);
      expect(find.text('Línea 60 · Canoto'), findsOneWidget);
      expect(find.text('Línea 105 · Centro'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('cada tarjeta muestra botones Ida y Vuelta independientes', (
      tester,
    ) async {
      final repo = FakeRouteRepository(_tresLineas());
      final state = _Harness();
      await _open(tester, repo, state);

      // Tres líneas × dos direcciones.
      expect(find.text('Ida'), findsNWidgets(3));
      expect(find.text('Vuelta'), findsNWidgets(3));
    });

    testWidgets('tocar Ida dibuja esa dirección y otro toque la apaga', (
      tester,
    ) async {
      final lines = _tresLineas();
      final repo = FakeRouteRepository(lines);
      final state = _Harness();
      await _open(tester, repo, state);

      // El toque va al centro del chip (donde vive el icono).
      await tester.tap(
        _chipIcon(
          lines,
          'Línea 60 · Canoto',
          Icons.arrow_circle_right_outlined,
        ),
      );
      await tester.pumpAndSettle();
      expect(state.toggles, ['60#0']);
      expect(repo.detailCalls, contains('detail=60#0'));
      expect(find.text('1 recorridos en el mapa'), findsOneWidget);

      // Con el headsign ya conocido, el check desaparece: se apaga tocando
      // de nuevo el centro de la etiqueta "Ida" de la misma tarjeta.
      await tester.tap(find.text('Ida').at(1));
      await tester.pumpAndSettle();
      expect(state.toggles, ['60#0', '60#0']);
      expect(find.text('3 líneas · elige ida o vuelta'), findsOneWidget);
    });

    testWidgets('Ida y Vuelta pueden activarse a la vez (claves separadas)', (
      tester,
    ) async {
      final lines = _tresLineas();
      final repo = FakeRouteRepository(lines);
      final state = _Harness();
      await _open(tester, repo, state);

      await tester.tap(
        _chipIcon(
          lines,
          'Línea 60 · Canoto',
          Icons.arrow_circle_right_outlined,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        _chipIcon(lines, 'Línea 60 · Canoto', Icons.arrow_circle_left_outlined),
      );
      await tester.pumpAndSettle();

      expect(state.toggles, ['60#0', '60#1']);
      expect(state.active, {'60#0', '60#1'});
      expect(find.text('2 recorridos en el mapa'), findsOneWidget);
      // El panel carga el detalle una sola vez (perezoso, en el primer
      // toque) y reutiliza ambas direcciones para el segundo toque.
      expect(repo.detailCalls, ['detail=60#0']);
    });

    testWidgets('la selección se refleja VISIBLE y en vivo en la tarjeta', (
      tester,
    ) async {
      final lines = _tresLineas();
      final repo = FakeRouteRepository(lines);
      final state = _Harness();
      await _open(tester, repo, state);

      // Sin activar: nada de checks en los chips.
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      await tester.tap(
        _chipIcon(
          lines,
          'Línea 60 · Canoto',
          Icons.arrow_circle_right_outlined,
        ),
      );
      await tester.pumpAndSettle();

      // El check vive SOLO en el chip activado (feedback visible al vuelo).
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      // La barra acento del banner (recorrido dibujado) se despliega, SOLO
      // en la tarjeta tocada.
      final accent = find.descendant(
        of: find.byKey(const ValueKey('micro-tile-60')),
        matching: find.byKey(const ValueKey('route-accent-bar')),
      );
      expect(accent, findsOneWidget);
      final accentOf = find.descendant(
        of: find.byKey(const ValueKey('micro-tile-41')),
        matching: find.byKey(const ValueKey('route-accent-bar')),
      );
      expect(
        tester.widget<AnimatedContainer>(accent).constraints?.maxHeight,
        3,
      );
      expect(
        tester.widget<AnimatedContainer>(accentOf).constraints?.maxHeight,
        0,
      );

      await tester.tap(find.text('Ida').at(1));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(
        tester.widget<AnimatedContainer>(accent).constraints?.maxHeight,
        0,
      );
    });

    testWidgets('"Limpiar" borra todos los recorridos activos de una pasada', (
      tester,
    ) async {
      final repo = FakeRouteRepository(_tresLineas());
      final state = _Harness(active: {'41#0', '60#1'});
      await _open(tester, repo, state);

      expect(find.text('2 recorridos en el mapa'), findsOneWidget);

      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();

      expect(state.clears, 1);
      expect(state.active, isEmpty);
      expect(find.text('3 líneas · elige ida o vuelta'), findsOneWidget);
    });

    testWidgets('"Activar todas" activa ida y vuelta de cada línea, en orden', (
      tester,
    ) async {
      final repo = FakeRouteRepository(_tresLineas());
      final state = _Harness(active: {'60#0'});
      await _open(tester, repo, state);

      await tester.tap(find.text('Activar todas'));
      await tester.pumpAndSettle();

      // Recorre `micros` en orden y salta la dirección ya activa.
      expect(state.toggles, ['41#0', '41#1', '60#1', '105#0', '105#1']);
      expect(find.text('6 recorridos en el mapa'), findsOneWidget);
    });

    testWidgets('sin líneas registradas muestra el estado vacío', (
      tester,
    ) async {
      final repo = FakeRouteRepository(const []);
      final state = _Harness();
      await _open(tester, repo, state);

      // Una sola petición y el estado vacío del panel.
      expect(repo.listCalls, ['page=1 limit=100 sort=name']);
      expect(find.text('No hay micros registrados todavía.'), findsOneWidget);
      // El icono de bus aparece en la cabecera Y en el estado vacío.
      expect(find.byIcon(Icons.directions_bus_rounded), findsNWidgets(2));
    });

    testWidgets(
      'reabrir conserva búsqueda y headsign sin volver a pagar /routes',
      (tester) async {
        final lines = _tresLineas();
        final repo = FakeRouteRepository(
          lines,
          headsigns: ('Plan 400', 'Monseñor Rivero'),
        );
        final state = _Harness();
        await _open(tester, repo, state);

        // Dibuja la ida de la 60 (el panel pide su detalle: llega el headsign)
        // y deja el buscador filtrando esa línea.
        await tester.tap(
          _chipIcon(
            lines,
            'Línea 60 · Canoto',
            Icons.arrow_circle_right_outlined,
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '60');
        await tester.pumpAndSettle();
        expect(find.text('Plan 400'), findsOneWidget);

        await _close(tester);
        expect(find.text('Micros'), findsNothing);
        await _reopen(tester);

        // El catálogo vive en la sesión del panel: reabrir no vuelve a la red.
        expect(repo.listCalls, ['page=1 limit=100 sort=name']);
        // Sigue escrito el filtro (con el listado ya recortado) y el headsign
        // consultado antes de cerrar.
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '60',
        );
        expect(find.text('Línea 60 · Canoto'), findsOneWidget);
        expect(find.text('Línea 41 · Plan 400'), findsNothing);
        expect(find.text('Plan 400'), findsOneWidget);
        // El recorrido sigue activado (ese estado vive en la pantalla padre).
        expect(state.active, {'60#0'});
        expect(find.text('1 recorridos en el mapa'), findsOneWidget);
      },
    );

    testWidgets('reabrir devuelve el listado en la misma posición de scroll', (
      tester,
    ) async {
      final repo = FakeRouteRepository([
        for (var i = 1; i <= 105; i++) _route('$i', 'Línea $i · Centro'),
      ]);
      final state = _Harness();
      await _open(tester, repo, state);

      await tester.drag(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      final before = _listOffset(tester);
      expect(before, greaterThan(0));

      await _close(tester);
      await _reopen(tester);

      expect(_listOffset(tester), closeTo(before, 1));
      // Dos páginas traídas una sola vez (la sesión ya las tiene).
      expect(repo.listCalls, [
        'page=1 limit=100 sort=name',
        'page=2 limit=100 sort=name',
      ]);
    });

    testWidgets('tirar del panel hacia la izquierda lo cierra', (tester) async {
      final repo = FakeRouteRepository(_tresLineas());
      final state = _Harness();
      await _open(tester, repo, state);

      await tester.drag(find.text('Micros'), const Offset(-140, 0));
      await tester.pumpAndSettle();

      expect(find.text('Micros'), findsNothing);
      // Cerrar NO apaga nada: los recorridos siguen en el mapa.
      expect(state.active, isEmpty);
      expect(repo.listCalls.length, 1);

      await _reopen(tester);
      expect(find.text('Micros'), findsOneWidget);
    });

    testWidgets('"Limpiar" solo está activo si hay recorridos dibujados', (
      tester,
    ) async {
      final lines = _tresLineas();
      final repo = FakeRouteRepository(lines);
      final state = _Harness();
      await _open(tester, repo, state);

      final limpiar = find.widgetWithText(OutlinedButton, 'Limpiar');
      expect(tester.widget<OutlinedButton>(limpiar).onPressed, isNull);

      await tester.tap(
        _chipIcon(
          lines,
          'Línea 60 · Canoto',
          Icons.arrow_circle_right_outlined,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(limpiar).onPressed, isNotNull);

      await tester.tap(limpiar);
      await tester.pumpAndSettle();
      expect(state.clears, 1);
      expect(tester.widget<OutlinedButton>(limpiar).onPressed, isNull);
    });

    testWidgets(
      'a ancho de móvil la tarjeta con headsign y píldora no desborda',
      (tester) async {
        // 393×851 lógicos: el panel mide min(340, 85% del ancho) y las tarjetas
        // se aprietan; cualquier overflow lanza excepción y rompe la prueba.
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);

        final lines = [
          _route(
            '119',
            'Línea 119 AZUL · Monumental de la Barra hasta el Urubó por 2do Anillo',
          ),
          _route('60', 'Línea 60 · Canoto'),
        ];
        final repo = FakeRouteRepository(
          lines,
          headsigns: ('Plan 400', 'Monseñor Rivero'),
        );
        final state = _Harness();
        await _open(tester, repo, state);

        // Ida y vuelta activas: píldora «2», headsign en ambos chips y check.
        await tester.tap(
          _chipIcon(
            lines,
            lines[0].longName,
            Icons.arrow_circle_right_outlined,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          _chipIcon(lines, lines[0].longName, Icons.arrow_circle_left_outlined),
        );
        await tester.pumpAndSettle();

        expect(state.active, {'119#0', '119#1'});
        expect(find.text('Plan 400'), findsOneWidget);
        expect(find.text('Monseñor Rivero'), findsOneWidget);
        expect(find.text('2 recorridos en el mapa'), findsOneWidget);
        // El tirador queda dentro de la pantalla (es zona táctil del panel).
        expect(
          tester.getCenter(find.byIcon(Icons.chevron_left_rounded)).dx,
          lessThan(393),
        );
      },
    );

    testWidgets(
      'en modo oscuro ninguna letra queda oscura sobre fondo oscuro',
      (tester) async {
        // El peor caso que puede devolver el GTFS: una línea casi negra
        // (`2C3E50`) sobre la superficie de grafito del tema oscuro. Los
        // colores de línea no se pintan tal cual como letras: se aclaran.
        final lines = [_route('60', 'Línea 60 · Canoto', color: '2C3E50')];
        final repo = FakeRouteRepository(lines);
        final state = _Harness();
        await _open(tester, repo, state, dark: true);

        await tester.tap(
          _chipIcon(
            lines,
            lines[0].longName,
            Icons.arrow_circle_right_outlined,
          ),
        );
        await tester.pumpAndSettle();

        // Píldora del contador: el número contra el fondo que realmente la
        // envuelve (tinte mezclado sobre la tarjeta).
        expect(
          colorContrast(
            _textColor(tester, find.text('1')),
            _paintedBackground(tester, find.byIcon(Icons.public_rounded)),
          ),
          greaterThanOrEqualTo(4.5),
        );

        // Chip activo: su relleno es el color de línea sólido.
        final ida = find.text('Ida');
        expect(
          colorContrast(
            _inheritedTextColor(tester, ida),
            _paintedBackground(tester, ida, animated: true),
          ),
          greaterThanOrEqualTo(4.5),
        );

        // "Limpiar" con algo que limpiar: el token `error` del tema, nunca un
        // rojo oscuro fijado a mano (`Colors.red.shade700`).
        final limpiar = tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Limpiar'),
            )
            .style!;
        expect(
          colorContrast(
            limpiar.foregroundColor!.resolve({})!,
            AppColors.surfaceDark,
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    testWidgets(
      'un color de línea claro no deja letras blancas sobre su relleno',
      (tester) async {
        // Amarillo GTFS (`F1C40F`): el blanco "porque sí" también es ilegible,
        // así que `AppColors.onColor` tiene que virar a negro la letra.
        final lines = [
          _route('77', 'Línea 77 · Puerto Nuevo', color: 'F1C40F'),
        ];
        final repo = FakeRouteRepository(lines);
        final state = _Harness();
        await _open(tester, repo, state);

        await tester.tap(
          _chipIcon(
            lines,
            lines[0].longName,
            Icons.arrow_circle_right_outlined,
          ),
        );
        await tester.pumpAndSettle();

        final ida = find.text('Ida');
        expect(
          colorContrast(
            _inheritedTextColor(tester, ida),
            _paintedBackground(tester, ida, animated: true),
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          colorContrast(
            _textColor(tester, find.text('1')),
            _paintedBackground(tester, find.byIcon(Icons.public_rounded)),
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  });
}
