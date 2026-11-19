import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../journey/application/journey_planner_controller.dart';
import '../../../journey/application/journey_providers.dart';
import '../../../journey/application/trip_history_controller.dart';
import '../../../journey/data/trip_history.dart';

/// «Tus viajes recientes»: los últimos destinos planificados.
///
/// En la referencia las filas viven dentro de **una sola tarjeta** con su
/// rótulo arriba, no como tarjetas sueltas: el bloque se lee como una lista
/// agrupada de iOS y la píldora de la derecha guarda lo que tardó la última
/// vez. Cada fila es un atajo de un toque: vuelve a poner ese destino en el
/// planeador (y el origen en tu ubicación, si está disponible), abre el panel
/// de origen/destino y cambia a la pestaña Viaje.
///
/// La portada solo lista [visibleOnHome] viajes (los más recientes); el resto
/// del historial (hasta `TripHistoryController.maxEntries`) vive en la hoja
/// «Ver todos», que aparece en la esquina del rótulo solo cuando hay más.
///
/// La sección se oculta sola mientras no haya historial, así una instalación
/// nueva no muestra un bloque vacío.
class RecentTrips extends ConsumerWidget {
  const RecentTrips({super.key});

  /// Filas que caben en la portada. El historial guarda más: lo que no entra
  /// aquí se lee en la hoja «Ver todos».
  static const int visibleOnHome = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(tripHistoryControllerProvider).valueOrNull ??
        const <TripHistoryEntry>[];
    if (history.isEmpty) return const SizedBox.shrink();

    // Mantiene viva la lectura puntual mientras la tarjeta está montada: el
    // `autoDispose` de `myLocationProvider` se llevaba la posición cuando la
    // cabecera salía del pliegue, y la fila necesita el origen para replanificar.
    ref.watch(myLocationProvider);

    final colors = context.colors;
    final text = context.text;
    final softInk = colors.onSurfaceVariant;
    final visible = history.take(visibleOnHome).toList(growable: false);
    final hidden = history.length - visible.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg + AppSpace.xs,
        AppSpace.lg,
        AppSpace.lg + AppSpace.xs,
        AppSpace.xxl,
      ),
      child: _HistoryPanel(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.lg,
              AppSpace.md,
              AppSpace.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  // El rótulo comparte fila con la píldora: se encoge en vez de
                  // cortarse (con letra grande o pantalla angosta) — nunca
                  // «Tus viajes reci…».
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tus viajes recientes',
                      maxLines: 1,
                      style: text.labelSmall?.copyWith(
                        color: softInk,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                if (hidden > 0)
                  _SeeAllButton(
                    key: const ValueKey('recent-trips-see-all'),
                    hiddenCount: hidden,
                    onTap: () => _openAll(context, ref, history),
                  ),
              ],
            ),
          ),
          _HistoryRows(
            entries: visible,
            keyPrefix: 'recent-trip-',
            onSelect: (entry) => _replan(context, ref, entry),
          ),
        ],
      ),
    );
  }

  /// Abre la hoja con el historial completo (el de la portada ya está arriba).
  void _openAll(
    BuildContext context,
    WidgetRef ref,
    List<TripHistoryEntry> history,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _AllTripsSheet(
        entries: history,
        onSelect: (entry) {
          Navigator.of(sheetContext).pop();
          _replan(context, ref, entry);
        },
      ),
    );
  }

  /// Vuelve a planificar el destino guardado.
  void _replan(BuildContext context, WidgetRef ref, TripHistoryEntry entry) {
    final planner = ref.read(journeyPlannerControllerProvider.notifier);
    planner.setPlace(
      JourneyPlacePoi(
        name: entry.label,
        lat: entry.lat,
        lon: entry.lon,
        subtitle: entry.subtitle,
      ),
      isOrigin: false,
    );
    // Sin origen, el viaje no se puede calcular: si ya hay ubicación conocida
    // (sin abrir el GPS otra vez), se usa como punto de partida. Se prefiere la
    // última conocida porque `myLocationProvider` es `autoDispose` y la
    // cabecera —su único oyente en Inicio— ya puede estar fuera del pliegue.
    final state = ref.read(journeyPlannerControllerProvider);
    if (state.origin == null) {
      final position =
          ref.read(lastKnownLocationProvider) ??
          ref.read(myLocationProvider).valueOrNull;
      if (position != null) {
        planner.setPlace(
          JourneyPlaceLocation(lat: position.latitude, lon: position.longitude),
          isOrigin: true,
        );
      }
    }
    ref.read(pendingPlannerPanelProvider.notifier).state = true;
    context.go('/journey');
  }
}

/// Tarjeta del historial: grafito con filete claro.
///
/// El historial se separa del lienzo por el borde y el contraste del texto
/// blanco, no por una losa clara. La usan la portada y la hoja «Ver todos»,
/// así las dos se leen como el mismo bloque.
class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.lg);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hairline = dark
        ? AppColors.lineDark
        : colors.outlineVariant.withValues(alpha: 0.7);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : AppTheme.softShadow(opacity: 0.05, blur: 18),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Filas del historial con sus separadores.
class _HistoryRows extends StatelessWidget {
  const _HistoryRows({
    required this.entries,
    required this.keyPrefix,
    required this.onSelect,
  });

  final List<TripHistoryEntry> entries;

  /// Distingue las filas de la portada (`recent-trip-`) de las de la hoja
  /// (`recent-trip-all-`): la hoja se abre encima de la portada y las dos
  /// listas conviven montadas.
  final String keyPrefix;

  final ValueChanged<TripHistoryEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hairline = dark
        ? AppColors.lineDark
        : colors.outlineVariant.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              indent: 64,
              endIndent: AppSpace.lg,
              color: hairline,
            ),
          Reveal(
            key: ValueKey('$keyPrefix${entries[i].key}'),
            index: i,
            slide: 8,
            child: _TripRow(
              entry: entries[i],
              onTap: () => onSelect(entries[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// «Ver todos»: píldora de acción del rótulo de la portada.
///
/// Usa el par `primaryContainer`/`onPrimaryContainer` del tema (menta con tinta
/// profunda en claro, verde hondo con tinta luminosa en oscuro), así se lee en
/// los dos modos sin volver a medir el contraste. El número de viajes que
/// quedan fuera se dice en el globo del ícono.
class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({
    super.key,
    required this.hiddenCount,
    required this.onTap,
  });

  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = colors.onPrimaryContainer;
    final radius = BorderRadius.circular(AppRadius.pill);

    return PressScale(
      scale: 0.94,
      child: Material(
        color: colors.primaryContainer,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.xs + 1,
              AppSpace.sm + 1,
              AppSpace.xs + 1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ver todos',
                  style: context.text.labelMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AppSpace.xs + 1),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.xs,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$hiddenCount',
                    textAlign: TextAlign.center,
                    style: context.text.labelSmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja «Ver todos»: el historial completo, con el mismo bloque agrupado de la
/// portada. Tocar una fila cierra la hoja y replanifica ese destino.
class _AllTripsSheet extends StatelessWidget {
  const _AllTripsSheet({required this.entries, required this.onSelect});

  final List<TripHistoryEntry> entries;
  final ValueChanged<TripHistoryEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppColors.tint(colors.primary, colors.surface, 0.12);
    final iconInk = dark
        ? colors.onSurface
        : AppColors.legible(colors.primary, fill);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.history_rounded, size: 21, color: iconInk),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tus viajes recientes',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        entries.length == 1
                            ? '1 destino guardado'
                            : '${entries.length} destinos guardados',
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            _HistoryPanel(
              children: [
                _HistoryRows(
                  entries: entries,
                  keyPrefix: 'recent-trip-all-',
                  onSelect: onSelect,
                ),
                const SizedBox(height: AppSpace.xs),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.entry, required this.onTap});

  final TripHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleInk = colors.onSurface;
    final subInk = colors.onSurfaceVariant;
    final fill = AppColors.tint(colors.primary, colors.surface, 0.12);
    final iconInk = dark
        ? colors.onSurface
        : AppColors.legible(colors.primary, fill);
    final pillFill = dark ? AppColors.lineDark : colors.surfaceContainerHigh;
    final pillInk = dark
        ? colors.onSurface
        : AppColors.legible(colors.onSurfaceVariant, pillFill);

    return InkWell(
      onTap: onTap,
      splashColor: titleInk.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm + 2,
          AppSpace.md,
          AppSpace.sm + 2,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: Icon(Icons.place_rounded, size: 21, color: iconInk),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: titleInk,
                    ),
                  ),
                  if (entry.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: subInk),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.sm + 2,
                vertical: AppSpace.xs + 1,
              ),
              decoration: BoxDecoration(
                color: pillFill,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                _trailing(entry),
                style: text.labelSmall?.copyWith(
                  color: pillInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lo que tardó la última vez (como en la referencia); si el plan nunca
  /// llegó a calcularse, cuándo se intentó.
  static String _trailing(TripHistoryEntry entry) {
    final minutes = entry.durationMinutes;
    if (minutes != null && minutes > 0) return Fmt.duration(minutes);
    final days = DateTime.now().difference(entry.lastUsed).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'ayer';
    return 'hace $days d';
  }
}
