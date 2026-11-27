import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../../journey/application/journey_place_factory.dart';
import '../../../journey/application/journey_providers.dart';
import '../../../journey/application/trip_history_controller.dart';
import '../../../journey/data/trip_history.dart';
import '../../../journey/domain/journey_place.dart';
import '../../../journey/presentation/widgets/journey_destination_sheet.dart';
import 'recent_trip_row.dart';
import 'recent_trips_all_sheet.dart';

/// «Tus viajes recientes»: los últimos destinos planificados.
///
/// Rótulo con reloj y, debajo, **una tarjeta por viaje** (diseño de la
/// portada): el ícono del recorrido, el destino, la píldora de cuándo se usó
/// («Hoy», «Ayer») y la X que lo quita del historial. Cada fila es un atajo de un toque: vuelve a poner ese destino en el
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
    final visible = history.take(visibleOnHome).toList(growable: false);
    final hidden = history.length - visible.length;
    final headerPlate = AppColors.tint(
      colors.primary,
      colors.surface,
      dark ? 0.2 : 0.12,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.xl,
        AppSpace.lg,
        AppSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: headerPlate,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 24,
                  color: dark ? colors.primary : AppColors.greenDeep,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tus viajes recientes',
                    maxLines: 1,
                    style: text.titleLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
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
          const SizedBox(height: AppSpace.md),
          for (var i = 0; i < visible.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpace.sm + 2),
              child: Reveal(
                key: ValueKey('recent-trip-${visible[i].key}'),
                index: i,
                slide: 8,
                child: _TripCard(
                  entry: visible[i],
                  onTap: () => _replan(context, ref, visible[i]),
                  onRemove: () => ref
                      .read(tripHistoryControllerProvider.notifier)
                      .remove(visible[i]),
                ),
              ),
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

/// «Ver todos»: píldora verde de acción del rótulo.
class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark
        ? colors.primaryContainer
        : AppColors.tint(colors.primary, colors.surface, 0.14);
    final ink = dark ? colors.onPrimaryContainer : AppColors.greenDeep;
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
                horizontal: AppSpace.md + 2,
                vertical: AppSpace.sm,
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

/// Una fila del historial como tarjeta propia (diseño de la portada): toda la
/// tarjeta replanifica y la X la borra del historial.
class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  final TripHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.md + 2);
    return PressScale(
      scale: 0.98,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: radius,
          border: Border.all(
            color: dark ? AppColors.lineDark : colors.outlineVariant,
          ),
          boxShadow: AppTheme.softShadow(
            color: Colors.black,
            opacity: dark ? 0.18 : 0.05,
            blur: 12,
            dy: 4,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: colors.onSurface.withValues(alpha: 0.06),
            child: RecentTripRowContent(entry: entry, onRemove: onRemove),
          ),
        ),
      ),
    );
  }
}
