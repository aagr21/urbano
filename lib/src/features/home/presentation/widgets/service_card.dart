import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
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
///
/// Es un **panel de marca**, no otra tarjeta blanca: fondo verde agua al 8 %,
/// riel de laguna a la izquierda y el recuento en tinta verde medida contra su
/// propio relleno. Es el dato vivo de la app, así que se tiñe como tal.
class ServiceCard extends ConsumerWidget {
  const ServiceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: stats.when(
        loading: () => const Reveal(
          slide: 8,
          child: LoadingShimmer(height: 108, radius: AppRadius.md),
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
    // Todo lo que se pinta aquí se mide contra el relleno REAL del panel.
    final fill = AppColors.tint(colors.primary, colors.surface, 0.08);
    final edge = AppColors.tint(colors.primary, colors.outlineVariant, 0.6);
    final accentInk = AppColors.legible(colors.primary, fill);
    final captionInk = AppColors.legible(colors.onSurfaceVariant, fill);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: edge),
        boxShadow: AppTheme.softShadow(
          color: colors.primary,
          opacity: 0.12,
          blur: 20,
        ),
      ),
      child: Stack(
        children: [
          // Riel de laguna: el mismo gesto del encabezado de sección, así el
          // panel se siente parte de la página y no un objeto pegado.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.primary, AppColors.aqua],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md + 2 + 4,
              AppSpace.md + 2,
              AppSpace.md + 2,
              AppSpace.md + 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LiveDot(
                      color: hasData ? colors.primary : colors.tertiary,
                      size: 6,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Flexible(
                      child: Text(
                        hasData ? 'El servicio anda' : 'Servicio sin datos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
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
                      color: accentInk,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    'No pudimos leer el horario de hoy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      color: captionInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: AppSpace.md),
                // Ventana y frecuencia a lo ancho del panel: antes vivían en
                // una columna a la derecha que recortaba el título en
                // pantallas angostas.
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    _ScheduleChip(
                      icon: Icons.schedule_rounded,
                      label: window ?? '—',
                      background: colors.secondaryContainer,
                      foreground: colors.onSecondaryContainer,
                    ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm + 2,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: AppSpace.xs + 2),
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
