import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/motion.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/time_formatters.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/urbano_logo.dart';
import '../../home/presentation/home_providers.dart';

/// Acerca de Urbano: fuente GTFS, versión del API y créditos.
class InfoScreen extends ConsumerWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final health = ref.watch(healthProvider);
    final meta = ref.watch(metaProvider);
    final colors = context.colors;
    final text = context.text;

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de Urbano')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 8),
          // El logo abre la escena; el resto de la página entra con la
          // transición del tema. Se anima solo el bloque de identidad para no
          // retrasar contenido que está bajo el borde al hacer scroll.
          const Reveal(slide: 20, child: Center(child: UrbanoLogo(size: 88))),
          const SizedBox(height: 14),
          Center(
            child: Text(
              Env.appName,
              style: AppTypography.wordmark(text.headlineSmall),
            ),
          ),
          Center(
            child: Text(
              Env.tagline,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          const Reveal(index: 1, slide: 12, child: SectionHeader('Apariencia')),
          const Reveal(index: 1, slide: 12, child: _AppearanceCard()),
          const SectionHeader('Fuente de datos'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.verified_rounded,
                      label: 'Versión del dataset',
                      value: meta.maybeWhen(
                        data: (m) => m.summary,
                        error: (_, _) => 'Sin conexión',
                        orElse: () => 'Consultando…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.badge_rounded,
                      label: 'Publicador',
                      value: meta.maybeWhen(
                        data: (m) => m.publisher.isEmpty
                            ? 'No declarado en el feed'
                            : m.publisher,
                        error: (_, _) => 'Sin conexión',
                        orElse: () => 'Consultando…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _InfoRow(
                      icon: Icons.dataset_rounded,
                      label: 'Feed GTFS',
                      value: 'GTFS Santa Cruz de la Sierra (gtfs.zip)',
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.calendar_month_rounded,
                      label: 'Ventana de servicio',
                      tint: colors.secondary,
                      value: stats.maybeWhen(
                        data: (s) =>
                            '${s.service.start} → ${s.service.end} · ${s.service.days}',
                        error: (_, _) => 'Sin datos del feed',
                        orElse: () => 'Consultando…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      label: 'Horario de servicio',
                      tint: colors.tertiary,
                      value: stats.maybeWhen(
                        data: (s) =>
                            '${GtfsTime.toHm(s.firstDeparture)} – ${GtfsTime.toHm(s.lastDeparture)} · ${Fmt.headway(s.headwaySeconds)}',
                        error: (_, _) => 'Sin datos del feed',
                        orElse: () => 'Consultando…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.directions_bus_rounded,
                      label: 'Cobertura',
                      value: stats.maybeWhen(
                        data: (s) =>
                            '${Fmt.number(s.routes)} rutas · ${Fmt.number(s.trips)} viajes',
                        error: (_, _) => 'Sin datos del feed',
                        orElse: () => 'Consultando…',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SectionHeader('Servicio'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    health.when(
                      // Esqueleto en vez del LinearProgressIndicator
                      // genérico: la fila ya anuncia su destino, con el
                      // mismo shimmer aqua de marca que todo el resto.
                      loading: () => const LoadingShimmer(
                        width: double.infinity,
                        height: 22,
                      ),
                      error: (error, _) => const _InfoRow(
                        icon: Icons.cloud_off_rounded,
                        label: 'API',
                        value: 'Sin conexión con el backend',
                        danger: true,
                      ),
                      data: (h) => _InfoRow(
                        icon: Icons.cloud_rounded,
                        label: 'API v${h.version}',
                        tint: colors.secondary,
                        value: h.isOk
                            ? 'Operativa · base ${h.db}'
                            : 'Estado: ${h.status}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _InfoRow(
                      icon: Icons.link_rounded,
                      label: 'Base URL',
                      value: Env.apiBaseUrl,
                      mono: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SectionHeader('Créditos'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hecho con Flutter · maplibre_gl · OpenStreetMap · CARTO.',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Los tiles del mapa © contribuidores de OpenStreetMap '
                      '(estilo claro OpenFreeMap; en tema oscuro, © CARTO). '
                      'Los datos de rutas y horarios provienen del feed GTFS público '
                      'de Santa Cruz de la Sierra. Los horarios son referenciales; '
                      'los micros pueden variar según tráfico y demanda.',
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Urbano · v1.0.0',
                      style: text.labelSmall?.copyWith(color: colors.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta "Apariencia": selector del modo de tema (sistema/claro/oscuro).
///
/// El cambio se aplica al instante en toda la app vía
/// [themeModeControllerProvider] y queda persistido entre sesiones.
class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);
    final colors = context.colors;
    final text = context.text;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.brightness_6_rounded,
                    size: 19,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo',
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Elige si Urbano sigue tu sistema o se queda en un '
                        'tema fijo.',
                        style: text.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('Sistema'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Claro'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Oscuro'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) => ref
                  .read(themeModeControllerProvider.notifier)
                  .setMode(selection.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.tint,
    this.mono = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Tinte de la ficha del ícono (por defecto el primario; `danger` lo
  /// pinta rojo).
  final Color? tint;
  final bool mono;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final chip = tint ?? (danger ? colors.error : colors.primary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: chip.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 19, color: chip),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: mono
                    ? text.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: colors.onSurfaceVariant,
                      )
                    : text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
