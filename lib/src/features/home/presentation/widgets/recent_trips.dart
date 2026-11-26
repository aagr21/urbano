import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../journey/application/journey_place_factory.dart';
import '../../../journey/application/journey_providers.dart';
import '../../../journey/application/trip_history_controller.dart';
import '../../../journey/data/trip_history.dart';
import '../../../journey/domain/journey_place.dart';
import '../../../journey/presentation/widgets/journey_destination_sheet.dart';
import 'recent_trips_all_sheet.dart';
import 'recent_trips_route_indicator.dart';

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final softInk = colors.onSurfaceVariant;
    final visible = history.take(visibleOnHome).toList(growable: false);
    final hidden = history.length - visible.length;

    // Colores del HTML: tarjeta blanca con borde esmeralda.
    final cardBg = dark ? colors.surface : HtmlDesignTokens.whiteBlue;
    final headerBg = dark
        ? colors.primary.withValues(alpha: 0.12)
        : HtmlDesignTokens.emerald50;
    final headerInk = dark
        ? colors.onPrimaryContainer
        : HtmlDesignTokens.emerald600;
    final dividerColor = dark ? AppColors.lineDark : HtmlDesignTokens.slate100;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg + AppSpace.xs,
        AppSpace.lg,
        AppSpace.lg + AppSpace.xs,
        AppSpace.xxl,
      ),
      child: _HistoryPanel(
        cardBg: cardBg,
        borderColor: dark ? AppColors.lineDark : HtmlDesignTokens.emerald50,
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
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: headerBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: headerInk,
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tus viajes recientes',
                      maxLines: 1,
                      style: text.labelSmall?.copyWith(
                        color: softInk,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                if (hidden > 0)
                  _SeeAllButton(
                    key: const ValueKey('recent-trips-see-all'),
                    onTap: () => _openAll(context, ref, history),
                  ),
              ],
            ),
          ),
          _HistoryRows(
            entries: visible,
            keyPrefix: 'recent-trip-',
            dividerColor: dividerColor,
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
      builder: (sheetContext) => AllTripsSheet(
        entries: history,
        onSelect: (entry) {
          Navigator.of(sheetContext).pop();
          _replan(context, ref, entry);
        },
      ),
    );
  }

  /// Abre el sheet de destino con el viaje reciente pre-llenado.
  ///
  /// En lugar de navegar directamente a `/journey`, se abre la hoja modal
  /// (igual que el tile "Viajes") para que el usuario revise o ajuste los
  /// extremos antes de planificar. El origen se pre-llena con la ubicación
  /// conocida si está disponible.
  Future<void> _replan(
    BuildContext context,
    WidgetRef ref,
    TripHistoryEntry entry,
  ) async {
    // Pre-llena el destino con el viaje reciente.
    final destination = JourneyPlaceFactory.fromHistory(entry);
    // Sin origen, el viaje no se puede calcular: si ya hay ubicación conocida
    // (sin abrir el GPS otra vez), se usa como punto de partida. Se prefiere la
    // última conocida porque `myLocationProvider` es `autoDispose` y la
    // cabecera —su único oyente en Inicio— ya puede estar fuera del pliegue.
    JourneyPlace? origin;
    final position =
        ref.read(lastKnownLocationProvider) ??
        ref.read(myLocationProvider).valueOrNull;
    if (position != null) {
      origin = JourneyPlaceFactory.here(
        lat: position.latitude,
        lon: position.longitude,
      );
    }
    await showJourneyDestinationSheet(
      context: context,
      ref: ref,
      initialOrigin: origin,
      initialDestination: destination,
    );
  }
}

/// Tarjeta del historial: estilo del HTML (blanca con borde esmeralda).
///
/// La usan la portada y la hoja «Ver todos», así las dos se leen como el
/// mismo bloque.
class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.children,
    required this.cardBg,
    required this.borderColor,
  });

  final List<Widget> children;
  final Color cardBg;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: radius,
        border: Border.all(color: borderColor),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Filas del historial con sus separadores.
class _HistoryRows extends StatelessWidget {
  const _HistoryRows({
    required this.entries,
    required this.keyPrefix,
    required this.dividerColor,
    required this.onSelect,
  });

  final List<TripHistoryEntry> entries;
  final String keyPrefix;
  final Color dividerColor;
  final ValueChanged<TripHistoryEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              indent: 64,
              endIndent: AppSpace.lg,
              color: dividerColor,
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

/// «Ver todos»: píldora de acción del rótulo, estilo del HTML.
///
/// Usa el par teal del HTML en claro y el tema en oscuro.
class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? colors.primaryContainer : HtmlDesignTokens.emerald100mid;
    final ink = dark ? colors.onPrimaryContainer : HtmlDesignTokens.teal700;
    final radius = BorderRadius.circular(AppRadius.pill);

    return PressScale(
      scale: 0.94,
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.xs + 1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ver todos',
                    style: context.text.labelMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila individual del historial: estilo del HTML.
///
/// Indicador de ruta, etiqueta y píldora de duración.
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

    // Píldora de duración: estilo del HTML (gris claro con ícono).
    final pillFill = dark
        ? colors.onSurface.withValues(alpha: 0.1)
        : HtmlDesignTokens.slate100;
    final pillInk = dark ? colors.onSurface : HtmlDesignTokens.slate500;

    return PressScale(
      scale: 0.97,
      child: InkWell(
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
              SizedBox(
                width: 40,
                height: 40,
                child: RouteDotIndicator(
                  ink: titleInk,
                  lineColor: subInk.withValues(alpha: 0.3),
                ),
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
                      const SizedBox(height: 2),
                      Text(
                        entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: subInk,
                          fontWeight: FontWeight.w400,
                        ),
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
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 12, color: pillInk),
                    const SizedBox(width: 4),
                    Text(
                      _trailing(entry),
                      style: text.labelSmall?.copyWith(
                        color: pillInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
