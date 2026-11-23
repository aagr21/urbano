import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';

/// Guía del modo lugares cuando no hay consulta ni punto: invitar a escribir,
/// pulsar «cerca de mí» o CLAVAR el lugar directamente en el mapa.
class MicrosPlaceGuide extends StatelessWidget {
  const MicrosPlaceGuide({
    super.key,
    required this.onNearby,
    required this.onPickOnMap,
  });

  final Future<void> Function() onNearby;
  final Future<void> Function() onPickOnMap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Insignia de color con el ícono dentro: la guía ya no es un ícono
                // gris suelto en el vacío (y flota, como el resto de estados vacíos).
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(colors.surface, colors.primary, 0.14),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Bob(
                    amplitude: 2.5,
                    child: Icon(
                      Icons.travel_explore_rounded,
                      size: 38,
                      color: AppColors.legible(
                        colors.primary,
                        Color.lerp(colors.surface, colors.primary, 0.14)!,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '¿Qué línea pasa por donde quieres ir?',
                  textAlign: TextAlign.center,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Escribe una calle, esquina, barrio o hito '
                  '(Terminal, Mercado, Cuarto Anillo…), marca el punto en el mapa '
                  'o usa tu ubicación, y te decimos qué micros sirven ese lugar.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onNearby,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Cerca de mí'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: onPickOnMap,
                      icon: const Icon(
                        Icons.add_location_alt_rounded,
                        size: 18,
                      ),
                      label: const Text('Marcar en el mapa'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
