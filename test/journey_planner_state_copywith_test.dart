import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/journey/presentation/journey_planner_controller.dart';
import 'package:urbano/src/features/journey/presentation/journey_providers.dart';

/// Lock del state del planeador: la convención del `copyWith` con sentinel
/// (omitir = conservar · `null` = limpiar). La primera versión del sentinel
/// rompió por silencio: un call site interno seguía pasando `null` con la
/// vieja semántica de "conservar" y los viajes dejaron de planificar — este
/// spec asegura que ambos significados están declarados y son distintos.
void main() {
  const origin = JourneyPlaceLocation(lat: -17.78, lon: -63.18);
  const dest = JourneyPlaceLocation(lat: -17.70, lon: -63.10);

  group('JourneyPlannerState.copyWith (sentinel)', () {
    test('omitir el parámetro CONSERVA; `null` LIMPIA; valor REEMPLAZA', () {
      final s0 = const JourneyPlannerState().copyWith(
        origin: origin,
        destination: dest,
        time: '08:30',
      );

      // Omitir conserva todo.
      final s1 = s0.copyWith(submitted: true);
      expect(s1.origin, same(origin));
      expect(s1.destination, same(dest));

      // `null` limpia SOLO el campo pasado.
      final s2 = s0.copyWith(destination: null);
      expect(s2.destination, isNull);
      expect(s2.origin, same(origin));
      expect(s2.time, '08:30');

      // Valor reemplaza.
      const newOrigin = JourneyPlaceLocation(lat: -17.5, lon: -63.2);
      final s3 = s0.copyWith(origin: newOrigin);
      expect(s3.origin, same(newOrigin));
      expect(s3.destination, same(dest));
    });

    test('extremos ausentes: copyWith sin nada no revienta', () {
      const s0 = JourneyPlannerState();
      expect(s0.copyWith().origin, isNull);
      expect(s0.copyWith().time, isNull);
    });
  });
}
