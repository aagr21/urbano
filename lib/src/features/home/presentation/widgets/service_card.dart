import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../core/widgets/loading_shimmer.dart';
import '../home_providers.dart';

/// Tarjeta "El servicio hoy": lo primero que importa a quien sale a la calle
/// —si el transporte anda, hasta qué hora y cada cuánto— reemplazando la
/// fila de estadísticas del feed ("rutas / entre salidas") que solo hablaba
/// al desarrollador.
///
/// [statsProvider] trae la foto entera del GTFS; aquí solo se muestran los
/// tres datos sobre los que alguien decide salir. Sin backend, degradamos a
/// guiones elegantes en vez de romper el home.
class ServiceCard extends ConsumerWidget {
  const ServiceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: stats.when(
        loading: () => const Reveal(
          slide: 8,
          child: LoadingShimmer(height: 88, radius: AppRadius.md),
        ),
        error: (_, _) => const _ServiceCardBody(
          lines: null,
          days: null,
          window: null,
          headway: null,
        ),
        data: (s) {
          return _ServiceCardBody(
            lines: s.routes,
            days: s.service.days.isEmpty ? null : s.service.days,
            window: _hours(s.firstDeparture, s.lastDeparture),
            headway: Fmt.headway(s.headwaySeconds),
          );
        },
      ),
    );
  }

  /// `06:00:00` / `22:00:00` → `06:00 → 22:00` (o `null` si el feed no trae
  /// ventana de servicio legible).
  String? _hours(String first, String last) {
    if (first.length < 4 || last.length < 4) return null;
    return '${first.substring(0, 5)} → ${last.substring(0, 5)}';
  }
}

class _ServiceCardBody extends StatelessWidget {
  const _ServiceCardBody({
    required this.lines,
    required this.days,
    required this.window,
    required this.headway,
  });

  /// `null` = «no hay dato» (sin backend): la tarjeta respira igual,
  /// con guiones.
  final int? lines;
  final String? days;
  final String? window;
  final String? headway;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final hasData = lines != null;

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LiveDot(
                      color: hasData ? colors.primary : colors.tertiary,
                      size: 6,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        hasData ? 'El servicio anda' : 'Servicio sin datos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // El conteo de líneas entra subiendo: es el «dato recién
                // traído del feed» del home, ahora con significado propio.
                if (lines != null)
                  CountUp(
                    value: lines!,
                    format: (v) =>
                        days == null ? '$v líneas' : '$v líneas · $days',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    'No pudimos leer el horario de hoy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ScheduleChip(
                icon: Icons.schedule_rounded,
                label: window ?? '—',
                background: colors.secondaryContainer,
                foreground: colors.onSecondaryContainer,
              ),
              const SizedBox(height: 8),
              _ScheduleChip(
                icon: Icons.update_rounded,
                label: headway ?? '—',
                background: colors.tertiaryContainer,
                foreground: colors.onTertiaryContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip sólido del horario (ventana de salida / frecuencia).
class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
