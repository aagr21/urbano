// Panel de sugerencias bajo los campos de la hoja de destino
// (showJourneyDestinationSheet): «Mi ubicación» (solo origen), hitos
// populares y la salida al mapa. Es solo presentación: la hoja decide qué
// mostrar y qué hacer con cada toque.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/location/place_search.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius, AppSpace;
import '../../../../core/utils/extensions.dart';
import '../../data/popular_places.dart';

/// Hitos populares que coinciden con lo escrito (nombre, categoría o zona).
List<SantaCruzPoi> matchPopularPlaces(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return kSantaCruzPopularPlaces
      .where(
        (poi) =>
            poi.name.toLowerCase().contains(q) ||
            poi.category.toLowerCase().contains(q) ||
            (poi.ringOrZone?.toLowerCase().contains(q) ?? false),
      )
      .take(4)
      .toList(growable: false);
}

class DestinationSuggestionPanel extends StatelessWidget {
  const DestinationSuggestionPanel({
    super.key,
    required this.query,
    required this.pois,
    required this.onPickPoi,
    required this.onPickOnMap,
    this.onUseGps,
    this.online,
    this.onPickSuggestion,
  });

  final String query;
  final List<SantaCruzPoi> pois;
  final ValueChanged<SantaCruzPoi> onPickPoi;
  final VoidCallback onPickOnMap;

  /// Fila «Mi ubicación»: solo en el origen y mientras haya punto GPS.
  final VoidCallback? onUseGps;

  /// Calles y lugares de OpenStreetMap para lo escrito (`null` = no se
  /// consultó, p. ej. con menos de [placeSearchMinChars] letras).
  final AsyncValue<List<PlaceSuggestion>>? online;
  final ValueChanged<PlaceSuggestion>? onPickSuggestion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final gps = onUseGps;
    // Lo de OSM que ya está entre los lugares populares no se repite.
    final local = {for (final poi in pois) poi.name.toLowerCase()};
    final osm = [
      for (final hit in online?.valueOrNull ?? const <PlaceSuggestion>[])
        if (!local.contains(hit.name.toLowerCase())) hit,
    ];
    final searching = online?.isLoading ?? false;
    final pick = onPickSuggestion;

    final rows = <Widget>[
      if (gps != null)
        _SuggestionTile(
          icon: Icons.near_me_rounded,
          title: 'Mi ubicación',
          subtitle: 'Usar tu GPS como punto',
          onTap: gps,
        ),
      for (final poi in pois)
        _SuggestionTile(
          icon: poi.icon,
          title: poi.name,
          subtitle: poi.ringOrZone ?? poi.category,
          onTap: () => onPickPoi(poi),
        ),
      for (final hit in osm)
        _SuggestionTile(
          key: ValueKey('place-suggestion-${hit.name}'),
          icon: hit.icon,
          title: hit.name,
          subtitle: hit.subtitle,
          onTap: pick == null ? () {} : () => pick(hit),
        ),
      if (searching) const _HintRow(text: 'Buscando calles y lugares…'),
      if (pois.isEmpty && osm.isEmpty && !searching && gps == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.sm + 2,
            AppSpace.md,
            AppSpace.sm + 2,
          ),
          child: Text(
            'Sin coincidencias para «${query.trim()}». Prueba otro nombre o elige en el mapa.',
            style: text.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      _SuggestionTile(
        icon: Icons.map_outlined,
        title: 'Elegir en el mapa',
        onTap: onPickOnMap,
      ),
      // Atribución de los datos de OSM, obligatoria cuando se muestran.
      if (osm.isNotEmpty) const _HintRow(text: osmAttribution, small: true),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: colors.outlineVariant, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.2
                      : 0.06,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.outlineVariant),
                  rows[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de aviso sin acción (buscando, atribución).
class _HintRow extends StatelessWidget {
  const _HintRow({required this.text, this.small = false});

  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.md,
        small ? AppSpace.xs : AppSpace.sm + 1,
        AppSpace.md,
        small ? AppSpace.xs : AppSpace.sm + 1,
      ),
      child: Text(
        text,
        style: (small ? context.text.labelSmall : context.text.labelMedium)
            ?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final fill = AppColors.tint(colors.primary, colors.surface, 0.12);
    final sub = subtitle;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.sm + 1,
          AppSpace.md,
          AppSpace.sm + 1,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                icon,
                size: 15,
                color: AppColors.legible(colors.primary, fill),
              ),
            ),
            const SizedBox(width: AppSpace.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.north_west_rounded, size: 13, color: colors.outline),
          ],
        ),
      ),
    );
  }
}
