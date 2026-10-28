import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../../data/journey_models.dart';
import '../journey_providers.dart';

/// Panel inferior de la consulta (carga / error / vacío) mientras no hay
/// resultados en memoria: aparece como tarjeta sobre el mapa.
class JourneyStatusPanel extends ConsumerWidget {
  const JourneyStatusPanel({
    super.key,
    required this.query,
    required this.result,
    required this.endpointsTooClose,
    required this.endpointsDistanceM,
  });

  final JourneyQuery query;
  final AsyncValue<List<JourneyOption>> result;

  /// `true` si origen y destino están (casi) en el mismo sitio.
  final bool endpointsTooClose;

  /// Distancia en línea recta entre ambos extremos (para el mensaje).
  final double? endpointsDistanceM;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      child: AsyncValueView<List<JourneyOption>>(
        value: result,
        onRetry: () => ref.invalidate(journeyProvider(query)),
        isEmpty: (options) => options.isEmpty,
        emptyIcon: Icons.directions_off_rounded,
        emptyTitle: endpointsTooClose
            ? 'Están muy cerca'
            : 'No encontramos viajes',
        emptyMessage: endpointsTooClose
            ? 'El origen y el destino están a '
                  '${(endpointsDistanceM ?? 0).round()} m: camina hasta allí, '
                  'no hay viaje de bus que valga la pena.'
            : 'No hay rutas directas ni con un transbordo para ese '
                  'origen/destino a esa hora. Prueba otra hora u otro punto.',
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_Scanning(), SkeletonList(count: 2)],
        ),
        onError: (error) => ErrorView(
          error: error,
          compact: true,
          onRetry: () => ref.invalidate(journeyProvider(query)),
        ),
        data: (_) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Barra de búsqueda con vida propia: un punto luminoso recorre el corredor
/// mientras el backend arma el viaje, para que «cargando» se lea «está haciendo
/// algo» y no una tarjeta muerta con grises.
class _Scanning extends StatelessWidget {
  const _Scanning();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LiveDot(color: colors.secondary, size: 7),
            // El halo necesita 3x el núcleo: se compensa el hueco para que el
            // texto no quede pegado al punto.
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                'Buscando conexiones de micro…',
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 4,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Ambient(
                period: const Duration(milliseconds: 1600),
                builder: (context, t, phase, child) => Align(
                  alignment: Alignment(-1 + 2 * phase, 0),
                  child: child,
                ),
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    gradient: LinearGradient(
                      colors: [
                        colors.secondary.withValues(alpha: 0),
                        colors.secondary,
                        colors.secondary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}
