import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../data/route_facts.dart';
import '../../data/route_models.dart';
import 'route_detail_hero.dart';

/// Tarjeta de servicio: Todo lo que el pasajero pregunta antes de subir, en
/// un solo lugar — si pasa ahora y, debajo, pasaje, primer y último micro.
///
/// La frecuencia no se muestra: el dato del feed no es confiable y prometer
/// «cada 5 min» a quien espera en la parada es peor que no decir nada.
class RouteQuickFacts extends StatelessWidget {
  const RouteQuickFacts({
    super.key,
    required this.direction,
    required this.routeColor,
    required this.now,
  });

  final RouteDirection? direction;
  final Color routeColor;

  /// Hora local con la que se lee el estado del servicio.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final d = direction;
    final status = RouteDetailHero.statusLabel(d, now);
    final running =
        ServiceWindow.from(d?.firstDeparture, d?.lastDeparture)?.phaseAt(now) ==
        ServicePhase.running;
    final statusInk = running
        ? AppColors.legible(AppColors.success, colors.surface)
        : colors.onSurfaceVariant;

    final facts = <_Fact>[
      const _Fact(value: kOfficialFareLabel, label: 'Pasaje'),
      if (d?.firstDeparture != null)
        _Fact(value: GtfsTime.toHm(d!.firstDeparture), label: 'Primer micro'),
      if (d?.lastDeparture != null)
        _Fact(value: GtfsTime.toHm(d!.lastDeparture), label: 'Último micro'),
    ];
    final hairline = dark
        ? AppColors.lineDark
        : colors.outlineVariant.withValues(alpha: 0.7);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: hairline),
      ),
      child: Column(
        children: [
          if (status != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.md,
                AppSpace.lg,
                AppSpace.md,
              ),
              child: Row(
                key: const ValueKey('route-service-status'),
                children: [
                  if (running)
                    LiveDot(color: statusInk, size: 7)
                  else
                    SizedBox.square(
                      dimension: 21,
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: statusInk,
                      ),
                    ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 2,
                      style: text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: running ? statusInk : colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: hairline),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
            child: Row(
              children: [
                for (var i = 0; i < facts.length; i++) ...[
                  if (i > 0) Container(width: 1, height: 32, color: hairline),
                  Expanded(child: _FactColumn(fact: facts[i])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact {
  const _Fact({required this.value, required this.label});

  final String value;
  final String label;
}

class _FactColumn extends StatelessWidget {
  const _FactColumn({required this.fact});

  final _Fact fact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          fact.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        Text(
          fact.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
