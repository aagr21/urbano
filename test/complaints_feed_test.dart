import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:urbano/src/core/animation/motion.dart';
import 'package:urbano/src/core/theme/app_colors.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/features/complaints/application/complaints_feed_controller.dart';
import 'package:urbano/src/features/complaints/application/passenger_controller.dart';
import 'package:urbano/src/features/complaints/data/complaint_repository.dart';
import 'package:urbano/src/features/complaints/presentation/complaint_detail_screen.dart';
import 'package:urbano/src/features/complaints/presentation/complaints_screen.dart';
import 'package:urbano/src/features/complaints/presentation/widgets/complaint_chips.dart';
import 'package:urbano/src/features/complaints/presentation/widgets/complaint_post_card.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';

import 'helpers/contrast.dart';
import 'helpers/fake_route_repository.dart';

/// Repo de quejas en memoria: el feed, el filtro y la cabecera se prueban sin
/// backend (regla del repo: `flutter test` no toca la red ni plugins).
class _FakeComplaintRepository implements ComplaintRepository {
  _FakeComplaintRepository(this.items);

  final List<ComplaintSummary> items;

  @override
  Future<List<ComplaintSummary>> list({String? deviceKey}) async => items;

  @override
  Future<void> create({
    required String routeId,
    required String category,
    required String description,
    required List<XFile> photos,
  }) async {}

  @override
  Future<int> setLiked({
    required String complaintId,
    required String deviceKey,
    required bool liked,
  }) async => 1;

  @override
  Future<List<ComplaintComment>> comments(String complaintId) async =>
      const <ComplaintComment>[];

  @override
  Future<ComplaintComment> addComment({
    required String complaintId,
    required String deviceKey,
    required String authorName,
    required String body,
  }) async => throw UnimplementedError();
}

const _routes = <RouteSummary>[
  RouteSummary(
    id: '12',
    shortName: '12',
    longName: 'Micro 12 San Juan',
    color: '2C3E50',
    textColor: 'FFFFFF',
    description: 'Transporte publico urbano de micros',
    type: 3,
    directionsCount: 2,
    stopCount: 40,
    tripCount: 6,
  ),
  RouteSummary(
    id: '55',
    shortName: '55',
    longName: 'Micro 55 Los Pinos',
    color: 'F1C40F',
    textColor: 'FFFFFF',
    description: 'Transporte publico urbano de micros',
    type: 3,
    directionsCount: 2,
    stopCount: 28,
    tripCount: 4,
  ),
];

ComplaintSummary _complaint({
  required String id,
  required String routeId,
  required String category,
  String status = 'pending',
  int likeCount = 0,
  int commentCount = 0,
  List<String> photoUrls = const [],
}) => ComplaintSummary(
  id: id,
  routeId: routeId,
  category: category,
  description: 'Relato del reporte $id con el estado actual del servicio.',
  photoUrls: photoUrls,
  status: status,
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  likeCount: likeCount,
  commentCount: commentCount,
);

/// Tres reportes: 1 de «estado del micro» (pendiente, con 3 fotos, 3 apoyos y
/// 1 comentario), 1 de seguridad verificado (2 apoyos) y 1 de seguridad
/// pendiente sin interacciones. Total de comunidad: 3 / 5 / 1.
final _feed = <ComplaintSummary>[
  _complaint(
    id: 'c1',
    routeId: '12',
    category: 'vehicle',
    likeCount: 3,
    commentCount: 1,
    photoUrls: const [
      'https://blob.test/1.jpg',
      'https://blob.test/2.jpg',
      'https://blob.test/3.jpg',
    ],
  ),
  _complaint(
    id: 'c2',
    routeId: '55',
    category: 'safety',
    status: 'approved',
    likeCount: 2,
  ),
  _complaint(id: 'c3', routeId: '12', category: 'safety'),
];

/// Identidad del pasajero en memoria.
///
/// `passengerControllerProvider` SIN override se queda colgado bajo
/// `flutter test`: su store real llama `SharedPreferences.getInstance()`, y el
/// channel del plugin nunca responde en el binding de tests (el `catch` del
/// store no salva un `await` que no termina). El feed entero depende de esa
/// identidad para `likedByMe`, así que hay que inyectar el store, no el
/// controller.
class _InMemoryIdentityStore implements PassengerIdentityStore {
  ({String deviceKey, String nickname})? saved;

  @override
  Future<({String deviceKey, String nickname})?> load() async => saved;

  @override
  Future<void> save({
    required String deviceKey,
    required String nickname,
  }) async => saved = (deviceKey: deviceKey, nickname: nickname);
}

Widget _app(
  List<ComplaintSummary> items, {
  required Widget home,
  bool dark = false,
}) => ProviderScope(
  overrides: [
    complaintRepositoryProvider.overrideWithValue(
      _FakeComplaintRepository(items),
    ),
    routeRepositoryProvider.overrideWithValue(FakeRouteRepository(_routes)),
    passengerControllerProvider.overrideWith(
      () => PassengerController(_InMemoryIdentityStore()),
    ),
  ],
  child: MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: home,
  ),
);

/// Abre el feed y deja el contenido asentado.
///
/// No se usa `pumpAndSettle` mientras el esqueleto está en pantalla:
/// `LoadingShimmer` anima en `repeat()` eterno y el settle nunca terminaría.
Future<void> _openFeed(
  WidgetTester tester, {
  List<ComplaintSummary>? items,
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(items ?? _feed, dark: dark, home: const ComplaintsScreen()),
  );
  // Dos frames: resuelven la identidad y el `/complaints` en memoria. A partir
  // de aquí el esqueleto (con su shimmer eterno) ya no está montado y el
  // settle puede correr.
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Abre el feed dentro del shell de 3 pestañas, a alto de teléfono real.
///
/// La `NavigationBar` importa: es el borde inferior contra el que se mide si la
/// primera queja se ve o no, y sin ella la pantalla mediría 300 px más.
Future<void> _openFeedInShell(
  WidgetTester tester, {
  Size physical = const Size(1080, 2340),
  double ratio = 2.75,
}) async {
  tester.view.physicalSize = physical;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      _feed,
      home: Scaffold(
        body: const ComplaintsScreen(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 2,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_rounded),
              label: 'Viaje',
            ),
            NavigationDestination(
              icon: Icon(Icons.feedback_rounded),
              label: 'Quejas',
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Pastilla de filtro del feed: es la única con `onTap` (las de la tarjeta y
/// del estado son informativas).
Finder _filterPill(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is ComplaintPill && widget.label == label && widget.onTap != null,
);

Finder _pill(String label) => find.byWidgetPredicate(
  (widget) => widget is ComplaintPill && widget.label == label,
);

/// Relleno pintado de la pastilla y tinta de su texto, leídos del ÁRBOL.
///
/// Se mide lo que el widget realmente pinta (no lo que el helper «debería»
/// devolver): así el test rompe si alguien teñiría sobre una superficie
/// distinta de la que hay detrás o escribiría la letra en otro color.
({Color fill, Color ink}) _pillColors(WidgetTester tester, String label) {
  final pill = _pill(label);
  expect(pill, findsWidgets, reason: 'no existe la pastilla «$label»');
  final containerFinder = find
      .descendant(of: pill, matching: find.byType(AnimatedContainer))
      .first;
  final container = tester.widget<AnimatedContainer>(containerFinder);
  final fill = (container.decoration! as BoxDecoration).color!;
  final ink = tester
      .widgetList<Text>(find.descendant(of: pill, matching: find.byType(Text)))
      .first
      .style!
      .color!;
  return (fill: fill, ink: ink);
}

void main() {
  group('feed de quejas', () {
    testWidgets('lista los reportes con motivo, estado y cifras de comunidad', (
      tester,
    ) async {
      await _openFeed(tester);

      expect(find.byType(ComplaintPostCard), findsNWidgets(3));
      expect(find.text('Micro 12'), findsNWidgets(2));
      // Pendiente de revisión: la tarjeta lo dice; la verificada no lo repite.
      expect(find.text('En revisión'), findsNWidgets(2));
      expect(find.text('Verificada'), findsNothing);
      // Contador de adjuntos sobre la foto.
      expect(find.text('+2 fotos'), findsOneWidget);

      // Los tres primeros CountUp del árbol son los de la cabecera (van antes
      // que la lista): reportes, apoyos y comentarios del feed COMPLETO.
      final counters = tester
          .widgetList<CountUp>(find.byType(CountUp))
          .take(3)
          .map((widget) => widget.value)
          .toList();
      expect(counters, [3, 5, 1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el pie social dice «apoyo», nunca «me gusta»', (tester) async {
      await _openFeed(tester);

      // `c3` llega con 0 apoyos: ahí es donde el botón muestra la palabra en
      // texto. La copia de la app habla de APOYOS (lo mismo dice la cabecera),
      // el préstamo «me gusta» queda prohibido aunque el API siga con `like`.
      expect(find.text('Apoyo'), findsOneWidget);
      expect(find.textContaining('gusta'), findsNothing);
    });

    testWidgets(
      'a alto de teléfono la primera queja entra completa bajo la barra',
      (tester) async {
        await _openFeedInShell(tester);

        final barTop = tester.getRect(find.byType(NavigationBar)).top;
        final card = tester.getRect(find.byType(ComplaintPostCard).first);
        // La cortina (cabecera + filtros + título) no puede comerse la primera
        // tarjeta: si crece, el reporte vuelve a quedar mutilado.
        expect(
          card.bottom,
          lessThan(barTop),
          reason:
              'la primera queja (h ${card.height.toStringAsFixed(0)}) no '
              'cabe entre ${card.top.toStringAsFixed(0)} y ${barTop.toStringAsFixed(0)}',
        );
        // Y el acceso directo a crear sigue visible sin scrollear.
        expect(find.byTooltip('Crear queja'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'el título de la cabecera no se corta con elipsis junto al CTA',
      (tester) async {
        await _openFeedInShell(tester);

        // Bajo `flutter test` las medidas de texto son de Ahem (un cuadrado por
        // glifo), así que no se puede comprobar «cuánto sobra»: se fija el
        // mecanismo. Título y CTA comparten fila; si alguien le devuelve el
        // `TextOverflow.ellipsis`, en un teléfono real vuelve
        // «La voz del pasaj…».
        final title = tester.widget<Text>(find.text('La voz del pasajero'));
        expect(title.maxLines, 1);
        expect(title.overflow, isNot(TextOverflow.ellipsis));
        expect(
          find.ancestor(
            of: find.text('La voz del pasajero'),
            matching: find.byType(FittedBox),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'en pantalla angosta (360 px) las pastillas no desbordan su fila',
      (tester) async {
        await _openFeedInShell(
          tester,
          physical: const Size(720, 1280),
          ratio: 2.0,
        );

        // `Estado del micro` + `En revisión` van en un `Wrap` dentro de la
        // tarjeta: con el ancho justo la pastilla se elide pero no desborda.
        expect(_pill('Estado del micro'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'filtrar por motivo deja solo sus reportes (y se puede quitar)',
      (tester) async {
        await _openFeed(tester);

        expect(_filterPill('Seguridad'), findsOneWidget);
        await tester.tap(_filterPill('Seguridad'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(ComplaintPostCard), findsNWidgets(2));
        expect(find.text('Micro 12'), findsNWidgets(1));
        // El contador de la cabecera y la barra de acciones siguen: lo que cambia
        // es lo listado, no lo que la comunidad dijo.
        expect(find.text('La comunidad reporta'), findsOneWidget);

        // Tocarlo de nuevo lo desactiva (el filtro es un toggle).
        await tester.tap(_filterPill('Seguridad'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(ComplaintPostCard), findsNWidgets(3));
      },
    );

    testWidgets(
      'con un solo motivo en el feed no aparece la barra de filtros',
      (tester) async {
        await _openFeed(
          tester,
          items: [_complaint(id: 'x', routeId: '12', category: 'schedule')],
        );

        expect(_filterPill('Frecuencia u horario'), findsNothing);
        expect(find.byType(ComplaintPostCard), findsOneWidget);
      },
    );

    testWidgets('el formulario resalta el motivo con su acento saturado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const <ComplaintSummary>[],
          home: const CreateComplaintScreen(routes: _routes),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Los seis motivos, todos tactables, con el color de su categoría.
      final tappable = tester
          .widgetList<ComplaintPill>(
            find.byWidgetPredicate(
              (widget) => widget is ComplaintPill && widget.onTap != null,
            ),
          )
          .toList();
      expect(tappable.length, complaintCategoryOrder.length);
      expect(
        tappable.where((pill) => pill.emphasized).length,
        1,
        reason: 'solo el motivo elegido va saturado',
      );

      // El elegido por defecto es «vehicle»: su relleno es el acento al 34%
      // sobre la superficie de la sección del formulario.
      final surface = AppTheme.light().colorScheme.surface;
      final selected = _pillColors(tester, 'Estado del micro');
      expect(
        selected.fill,
        AppColors.tint(AppColors.categoryVehicle, surface, 0.34),
      );
      expect(
        colorContrast(selected.ink, selected.fill),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('detalle del reporte', () {
    testWidgets('reusa las mismas pastillas y cifras que la tarjeta', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          _feed,
          home: ComplaintDetailScreen(
            complaint: _feed.first,
            route: _routes.first,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Misma identidad que en el feed: insignia, motivo y estado (aquí el
      // estado se muestra siempre, verificado o no).
      expect(find.text('Micro 12'), findsOneWidget);
      expect(find.text('Estado del micro'), findsOneWidget);
      expect(find.text('En revisión'), findsOneWidget);
      expect(find.text('3 fotos adjuntas'), findsOneWidget);
      // Wiring de la galería en el post: las otras dos también son alcanzables
      // (una miniatura por adjunto + contador sobre la principal).
      expect(find.text('1/3'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('complaint-photo-thumb-2')),
        findsOneWidget,
      );
      // La barra social del detalle cuenta el hilo en su pastilla.
      expect(find.text('1 comentarios'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('contraste de los acentos vivos', () {
    // Los seis motivos y los tres estados se pintan como pastillas OPACAS
    // teñidas sobre la superficie de la tarjeta: lo único que tiene que ganar
    // al contraste es la letra contra ESE relleno, en ambos temas.
    for (final dark in [false, true]) {
      final label = dark ? 'modo oscuro' : 'modo claro';
      testWidgets('motivos y estados son legibles en $label', (tester) async {
        final theme = dark ? AppTheme.dark() : AppTheme.light();
        final cardSurface = theme.colorScheme.surfaceContainerLow;
        await tester.pumpWidget(
          _app(
            const <ComplaintSummary>[],
            dark: dark,
            home: Scaffold(
              body: ListView(
                children: [
                  for (final category in complaintCategoryOrder)
                    CategoryChip(category: category, on: cardSurface),
                  for (final status in ['pending', 'approved', 'rejected'])
                    StatusChip(status: status, on: cardSurface),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        for (final category in complaintCategoryOrder) {
          final text = categoryLabelOf(category);
          final colors = _pillColors(tester, text);
          expect(
            colors.fill,
            // 0.16 es el alfa por defecto de [AppColors.tint]: la pastilla
            // informativa se tiñe así de fábrica.
            AppColors.tint(AppColors.categoryAccent(category), cardSurface),
            reason: '$text debe teñirse con el helper de la casa',
          );
          expect(
            colorContrast(colors.ink, colors.fill),
            greaterThanOrEqualTo(4.5),
            reason: 'el motivo «$text» queda ilegible en $label',
          );
        }

        for (final status in ['En revisión', 'Verificada', 'Descartada']) {
          final colors = _pillColors(tester, status);
          expect(
            colorContrast(colors.ink, colors.fill),
            greaterThanOrEqualTo(4.5),
            reason: 'el estado «$status» queda ilegible en $label',
          );
        }
      });
    }
  });
}
