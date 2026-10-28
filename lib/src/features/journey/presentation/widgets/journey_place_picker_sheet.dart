import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/popular_places.dart';

sealed class JourneyPlacePickResult {
  const JourneyPlacePickResult();
}

class JourneyPlacePickSource extends JourneyPlacePickResult {
  const JourneyPlacePickSource._(this.name);
  final String name;

  static const myLocation = JourneyPlacePickSource._('myLocation');
  static const mapPoint = JourneyPlacePickSource._('mapPoint');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JourneyPlacePickSource && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

class JourneyPlacePickPoi extends JourneyPlacePickResult {
  const JourneyPlacePickPoi(this.poi);
  final SantaCruzPoi poi;
}

/// Bottom sheet del selector de origen/destino: permite elegir entre
/// "Mi ubicación" (GPS), "Punto en el mapa" (coordenada libre) o buscar
/// directamente entre los hitos y lugares populares de Santa Cruz (mercados,
/// universidades, plazas, centros comerciales).
Future<JourneyPlacePickResult?> showJourneyPlacePickerSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<JourneyPlacePickResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _PlacePickerSheetContent(title: title),
  );
}

class _PlacePickerSheetContent extends StatefulWidget {
  const _PlacePickerSheetContent({required this.title});

  final String title;

  @override
  State<_PlacePickerSheetContent> createState() =>
      _PlacePickerSheetContentState();
}

class _PlacePickerSheetContentState extends State<_PlacePickerSheetContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textTheme = context.text;
    final colors = context.colors;

    final filteredPlaces = kSantaCruzPopularPlaces.where((poi) {
      if (_filter.isEmpty) return true;
      final query = _filter.toLowerCase();
      return poi.name.toLowerCase().contains(query) ||
          poi.category.toLowerCase().contains(query) ||
          (poi.ringOrZone?.toLowerCase().contains(query) ?? false);
    }).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.85),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: mediaQuery.viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () =>
                    Navigator.of(context)
                        .pop(JourneyPlacePickSource.myLocation),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                  ),
                  child: Icon(
                    Icons.near_me_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
                title: const Text('Mi ubicación'),
                subtitle: Text(
                  'Usar tu GPS como punto del viaje',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () =>
                    Navigator.of(context).pop(JourneyPlacePickSource.mapPoint),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                  ),
                  child: Icon(
                    Icons.add_location_alt_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
                title: const Text('Punto en el mapa'),
                subtitle: Text(
                  'Mover el mapa y confirmar la coordenada',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Lugares de Santa Cruz',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _filter = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Buscar mercado, universidad, mall...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _filter = '');
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: colors.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: filteredPlaces.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No se encontraron lugares con "$_filter"',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredPlaces.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final poi = filteredPlaces[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 2,
                            ),
                            onTap: () =>
                                Navigator.of(context)
                                    .pop(JourneyPlacePickPoi(poi)),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                              child: Icon(
                                poi.icon,
                                size: 20,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            title: Text(
                              poi.name,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              poi.ringOrZone != null
                                  ? '${poi.category} · ${poi.ringOrZone}'
                                  : poi.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: colors.outlineVariant,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
