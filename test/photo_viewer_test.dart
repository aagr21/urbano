import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/widgets/photo_viewer.dart';
import 'package:urbano/src/core/widgets/route_photo.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/presentation/route_detail_screen.dart';
import 'package:urbano/src/features/routes/presentation/route_providers.dart';

// La foto de un micro es TOCABLE: se abre a pantalla completa con un vuelo
// desde la miniatura (`openPhotoViewer`). Estos tests fijan el contrato:
// - el tag del Hero lleva el ORIGEN delante (`detail`, …) para que dos ramas
//   del shell no compartan tag;
// - el tap abre `PhotoViewerScreen`, que cierra con la ✕ o tocando la foto.

const _foto = 'https://example.test/micro.jpg';

RouteDetail _detail({String? imageUrl = _foto}) => RouteDetail(
  id: '41',
  shortName: '41',
  longName: 'Línea 41 · Plan 400',
  color: 'D35400',
  textColor: 'FFFFFF',
  description: 'Transporte publico urbano de micros',
  type: 3,
  directionsCount: 2,
  stopCount: 20,
  tripCount: 2,
  imageUrl: imageUrl,
  bbox: const [],
  directions: const [
    RouteDirection(
      directionId: 0,
      headsign: 'Ida',
      tripId: 'T0',
      firstDeparture: '06:00:00',
      lastDeparture: '22:00:00',
      headwaySeconds: 600,
      stopCount: 20,
    ),
  ],
  shape: null,
);

/// Monta el detalle de la línea 41 (con foto salvo que [imageUrl] sea null).
Future<void> _openDetail(
  WidgetTester tester, {
  String? imageUrl = _foto,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routeDetailProvider.overrideWith(
          (ref, key) async => _detail(imageUrl: imageUrl),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const RouteDetailScreen(routeId: '41', heroPrefix: 'home'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// El `Hero` de la foto del detalle (prefijo propio, `detail`).
Finder get _photoHero => find.byWidgetPredicate(
  (widget) => widget is Hero && widget.tag == photoHeroTag('detail', '41'),
);

/// El visor montado (el detalle sigue debajo, así que se busca dentro).
Finder get _viewer => find.byType(PhotoViewerScreen);

void main() {
  group('Foto del micro a pantalla completa', () {
    testWidgets('la foto del detalle vuela al visor y la ✕ lo cierra', (
      tester,
    ) async {
      await _openDetail(tester);
      expect(_photoHero, findsOneWidget);

      await tester.tapAt(tester.getCenter(_photoHero));
      await tester.pumpAndSettle();

      expect(_viewer, findsOneWidget);
      expect(
        find.descendant(
          of: _viewer,
          matching: find.text('Línea 41 · Plan 400'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _viewer, matching: find.text('Foto del micro')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: _viewer,
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();

      expect(_viewer, findsNothing);
    });

    testWidgets('tocar la foto también cierra el visor', (tester) async {
      await _openDetail(tester);
      await tester.tapAt(tester.getCenter(_photoHero));
      await tester.pumpAndSettle();

      expect(_viewer, findsOneWidget);

      // El centro de la foto (el pie del visor es IgnorePointer).
      await tester.tapAt(tester.getCenter(_viewer));
      await tester.pumpAndSettle();

      expect(_viewer, findsNothing);
    });

    testWidgets('la foto se ve completa y al acercarla se puede arrastrar', (
      tester,
    ) async {
      await _openDetail(tester);
      await tester.tapAt(tester.getCenter(_photoHero));
      await tester.pumpAndSettle();

      final photo = find.descendant(
        of: _viewer,
        matching: find.byType(RoutePhoto),
      );
      expect(photo, findsOneWidget);

      // La caja de la foto queda DENTRO del visor: se abre completa, sin
      // recorte ni zoom forzado.
      final base = tester.getRect(photo);
      final screen = tester.getRect(_viewer);
      expect(screen.contains(base.topLeft), isTrue);
      expect(screen.contains(base.bottomRight - const Offset(1, 1)), isTrue);

      // Pellizco: dos dedos se separan desde el centro.
      final center = tester.getCenter(_viewer);
      final first = await tester.createGesture();
      final second = await tester.createGesture();
      await first.down(center - const Offset(30, 0));
      await second.down(center + const Offset(30, 0));
      await tester.pump();
      await first.moveTo(center - const Offset(120, 0));
      await second.moveTo(center + const Offset(120, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      final zoomed = tester.getRect(photo);
      expect(zoomed.width, greaterThan(base.width * 1.5));

      // Con la foto acercada, el arrastre la mueve dentro del encuadre.
      await tester.dragFrom(center, const Offset(-60, 0));
      await tester.pumpAndSettle();

      expect(tester.getRect(photo).left, lessThan(zoomed.left));
    });

    testWidgets('sin foto no hay vuelo ni visor', (tester) async {
      await _openDetail(tester, imageUrl: null);

      expect(_photoHero, findsNothing);
      expect(_viewer, findsNothing);
    });
  });
}
