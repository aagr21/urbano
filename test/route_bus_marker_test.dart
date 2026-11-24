import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/map/map.dart';
import 'package:urbano/src/core/theme/app_colors.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/widgets/urbano_map.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/data/route_repository.dart';
import 'package:urbano/src/features/routes/presentation/route_detail_screen.dart';

import 'helpers/fake_route_repository.dart';

RouteSummary _route(String color) => RouteSummary(
  id: '101',
  shortName: '101',
  longName: 'Angostura',
  color: color,
  textColor: 'FFFFFF',
  description: '',
  type: 3,
  directionsCount: 2,
  stopCount: 10,
  tripCount: 2,
);

/// Monta el detalle de una línea y devuelve (trazo, disco del micro) del
/// mapa de vista previa.
Future<(MapPolyline, MapMarker)> _preview(
  WidgetTester tester,
  String color,
) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        routeRepositoryProvider.overrideWithValue(
          FakeRouteRepository([_route(color)]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const RouteDetailScreen(routeId: '101'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  final map = tester.widget<UrbanoMap>(find.byType(UrbanoMap).first);
  return (
    map.polylines.single,
    map.markers.firstWhere((m) => m.id == 'route-shape-bus'),
  );
}

void main() {
  testWidgets('el disco del micro es del color del trazo y su imagen se '
      'cachea por color (no hereda el de otra línea)', (tester) async {
    final (lineA, busA) = await _preview(tester, '0F766E');
    final (lineB, busB) = await _preview(tester, 'B91C1C');

    Color fill(MapMarker marker) {
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byWidget(marker.child),
              matching: find.byType(Container),
            )
            .first,
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    expect(busB.child.runtimeType, busA.child.runtimeType);
    expect(lineB.color, AppColors.fromHex('B91C1C'));
    expect(fill(busB), lineB.color);
    // Mismo id en las dos líneas, pero distinta imagen: la caché global del
    // rasterizador ya no le sirve a la segunda el disco de la primera.
    expect(busA.id, busB.id);
    expect(busA.imageCacheKey, isNot(busB.imageCacheKey));
    expect(lineA.color, isNot(lineB.color));
  });

  testWidgets('la caja del disco deja aire para la sombra (sin puntas en '
      'las esquinas de la imagen nativa)', (tester) async {
    final (_, bus) = await _preview(tester, '0F766E');

    final disc = tester.widget<Container>(
      find
          .descendant(
            of: find.byWidget(bus.child),
            matching: find.byType(Container),
          )
          .first,
    );
    final size = tester.getSize(find.byWidget(disc));
    final shadow = (disc.decoration! as BoxDecoration).boxShadow!.single;
    // El motor rasteriza la caja del marcador (`width` × `height`): si el
    // disco la llenaba, la sombra se recortaba en el cuadrado y quedaban sus
    // esquinas como puntas oscuras. Ahora sobra al menos su difuminado.
    final margin = (bus.width - size.width) / 2;
    expect(margin, kMarkerShadowMargin);
    expect(margin, greaterThanOrEqualTo(shadow.blurRadius));
    expect((bus.height - size.height) / 2, margin);
  });
}
