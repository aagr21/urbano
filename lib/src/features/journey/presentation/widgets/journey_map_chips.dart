import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Chips sobre el mapa, entre la tarjeta del planeador y los controles:
/// qué opción se está viendo ("Opción N en el mapa"), el estado del
/// recálculo ("Recalculando…" / error con reintento) y el spinner de
/// polilíneas de rutas cargándose.
class JourneyMapChips extends StatelessWidget {
  const JourneyMapChips({
    super.key,
    required this.hasResults,
    required this.bare,
    required this.selectedIndex,
    required this.replanning,
    required this.refreshFailed,
    required this.loadingRoutes,
    this.onRetryRefresh,
  });

  /// `true` con viaje planificado en memoria (el badge de opción solo
  /// aplica con opciones reales, no en "vacío").
  final bool hasResults;

  /// `true` si la respuesta no trajo ninguna opción.
  final bool bare;

  /// Índice de la opción dibujada en el mapa.
  final int selectedIndex;

  /// `true` mientras se recalcula tras mover un extremo.
  final bool replanning;

  /// `true` si el recálculo falló y seguimos mostrando el viaje anterior.
  final bool refreshFailed;

  /// `true` mientras se carga el recorrido de un micro.
  final bool loadingRoutes;

  /// Reintentar el recálculo fallido (solo aplica con [refreshFailed]).
  final VoidCallback? onRetryRefresh;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.2),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: hasResults || loadingRoutes
          ? Row(
              key: const ValueKey('map-chips'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasResults && !bare) ...[
                  _MapBadge(index: selectedIndex),
                  if (replanning || refreshFailed) const SizedBox(width: 8),
                ],
                if (replanning || refreshFailed)
                  _ReplanChip(
                    failed: refreshFailed,
                    onRetry: refreshFailed ? onRetryRefresh : null,
                  ),
                if (loadingRoutes) ...[
                  if (hasResults || replanning || refreshFailed)
                    const SizedBox(width: 8),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            )
          : const SizedBox.shrink(key: ValueKey('map-chips-empty')),
    );
  }
}

/// Chip sobre el mapa: "Recalculando…" mientras se pide el nuevo viaje, o
/// aviso de error con reintento si la actualización falló.
class _ReplanChip extends StatelessWidget {
  const _ReplanChip({required this.failed, this.onRetry});

  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: failed ? colors.error : colors.outlineVariant,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.sync_problem_rounded : Icons.refresh_rounded,
            size: 15,
            color: failed ? colors.error : colors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            failed ? 'No se pudo recalcular' : 'Recalculando…',
            style: text.labelSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (failed && onRetry != null)
            IconButton(
              tooltip: 'Reintentar',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              onPressed: onRetry,
              icon: Icon(
                Icons.refresh_rounded,
                size: 17,
                color: colors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Badge flotante sobre el mapa: indica qué opción de viaje se está viendo.
class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_rounded, size: 14, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            'Opción ${index + 1} en el mapa',
            style: text.labelSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
