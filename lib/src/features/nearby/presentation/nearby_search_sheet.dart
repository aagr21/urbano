import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/location/reverse_geocoding.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/location.dart';
import '../../journey/data/popular_places.dart';
import '../../journey/domain/journey_place.dart';
import '../../stops/presentation/stop_search_providers.dart';
import '../domain/nearby_micros.dart';

/// Abre la hoja de «Lugares»: el usuario elige un punto (escribiendo, con su
/// GPS o marcándolo en el mapa) y un radio, y la hoja devuelve la consulta al
/// pulsar «Buscar cerca». `null` si se cierra sin buscar.
///
/// La navegación a la vista de resultados la hace quien llama: la hoja solo
/// decide QUÉ buscar.
Future<NearbyQuery?> showNearbySearchSheet(BuildContext context) {
  return showModalBottomSheet<NearbyQuery>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const _NearbySearchSheet(),
  );
}

/// Punto elegido en la hoja (aún sin radio).
class _Picked {
  const _Picked({
    required this.label,
    required this.lat,
    required this.lon,
    required this.icon,
    this.detail,
  });

  final String label;
  final double lat;
  final double lon;
  final IconData icon;

  /// Segunda línea: categoría, zona o coordenadas.
  final String? detail;

  _Picked withLabel(String label) =>
      _Picked(label: label, lat: lat, lon: lon, icon: icon, detail: detail);
}

class _NearbySearchSheet extends ConsumerStatefulWidget {
  const _NearbySearchSheet();

  @override
  ConsumerState<_NearbySearchSheet> createState() => _NearbySearchSheetState();
}

class _NearbySearchSheetState extends ConsumerState<_NearbySearchSheet> {
  final _field = TextEditingController();
  Timer? _debounce;

  /// Texto ya asentado (tras el debounce) con el que se busca en paradas.
  String _query = '';

  _Picked? _picked;
  int _radius = kNearbyDefaultRadius;
  bool _locating = false;

  /// Mismo respiro que el resto de buscadores de la app.
  static const Duration _debounceDelay = Duration(milliseconds: 350);

  /// Una búsqueda de paradas con menos letras devuelve medio feed.
  static const int _minStopQuery = 3;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _pick(_Picked picked) {
    FocusScope.of(context).unfocus();
    setState(() => _picked = picked);
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final granted = await ref
          .read(locationControllerProvider.notifier)
          .activate(context);
      if (!granted || !mounted) return;
      final position = await ref.read(myLocationProvider.future);
      if (position == null || !mounted) return;
      _pick(
        _Picked(
          label: 'Mi ubicación',
          lat: position.latitude,
          lon: position.longitude,
          icon: Icons.near_me_rounded,
          detail: 'Tu posición actual',
        ),
      );
    } on LocationFailure {
      if (mounted) {
        context.showSnack('No pudimos leer tu ubicación.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    final current = _picked;
    final params = <String, String>{'title': 'Punto a consultar'};
    if (current != null) {
      params['lat'] = '${current.lat}';
      params['lon'] = '${current.lon}';
    }
    final point = await context.push<JourneyPoint>(
      Uri(path: '/journey/pick', queryParameters: params).toString(),
    );
    if (point == null || !mounted) return;
    final picked = _Picked(
      label: 'Punto en el mapa',
      lat: point.lat,
      lon: point.lon,
      icon: Icons.push_pin_rounded,
      detail:
          '${point.lat.toStringAsFixed(5)}, ${point.lon.toStringAsFixed(5)}',
    );
    _pick(picked);
    // El nombre de la calle llega después (Nominatim); si el usuario no cambió
    // de punto mientras tanto, se pone en lugar del genérico.
    final address = await ref
        .read(reverseGeocodingServiceProvider)
        .reverseGeocode(LatLng(point.lat, point.lon));
    if (!mounted || address == null || _picked != picked) return;
    final name = address.shortFormatted.trim();
    if (name.isNotEmpty) setState(() => _picked = picked.withLabel(name));
  }

  void _submit() {
    final picked = _picked;
    if (picked == null) return;
    Navigator.of(context).pop(
      NearbyQuery(
        lat: picked.lat,
        lon: picked.lon,
        label: picked.label,
        radiusMeters: _radius,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = context.colors;
    final text = context.text;
    final typed = _field.text.trim().toLowerCase();

    final places = typed.isEmpty
        ? kSantaCruzPopularPlaces
        : kSantaCruzPopularPlaces.where((poi) {
            return poi.name.toLowerCase().contains(typed) ||
                poi.category.toLowerCase().contains(typed) ||
                (poi.ringOrZone?.toLowerCase().contains(typed) ?? false);
          }).toList();
    final stopHits = _query.length >= _minStopQuery
        ? ref.watch(stopNameSearchProvider(_query))
        : null;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg + 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetTitle(),
                  const SizedBox(height: AppSpace.lg),
                  TextField(
                    key: const ValueKey('nearby-search-field'),
                    controller: _field,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Busca una plaza, mercado o parada',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _field.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Borrar',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _field.clear();
                                _onChanged('');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          key: const ValueKey('nearby-use-location'),
                          icon: Icons.near_me_rounded,
                          label: 'Mi ubicación',
                          busy: _locating,
                          onTap: _useMyLocation,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: _QuickAction(
                          key: const ValueKey('nearby-pick-map'),
                          icon: Icons.add_location_alt_rounded,
                          label: 'Marcar en el mapa',
                          onTap: _pickOnMap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Flexible(
              child: ListView(
                key: const ValueKey('nearby-search-results'),
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.sm,
                ),
                children: [
                  if (stopHits != null) ...[
                    const _SectionLabel('Paradas'),
                    ...switch (stopHits) {
                      AsyncData(:final value) when value.isEmpty => [
                        _HintRow(
                          text: 'Ninguna parada se llama «$_query».',
                          icon: Icons.search_off_rounded,
                        ),
                      ],
                      AsyncData(:final value) => [
                        for (final stop in value.take(8))
                          _PlaceRow(
                            key: ValueKey('nearby-stop-hit-${stop.id}'),
                            icon: Icons.signpost_rounded,
                            title: stop.name,
                            subtitle: stop.routes.isEmpty
                                ? 'Parada'
                                : '${stop.routes.length} '
                                      '${stop.routes.length == 1 ? 'línea' : 'líneas'}'
                                      ' paran aquí',
                            selected:
                                _picked?.lat == stop.lat &&
                                _picked?.lon == stop.lon,
                            onTap: () => _pick(
                              _Picked(
                                label: stop.name,
                                lat: stop.lat,
                                lon: stop.lon,
                                icon: Icons.signpost_rounded,
                                detail: 'Parada',
                              ),
                            ),
                          ),
                      ],
                      AsyncError() => [
                        const _HintRow(
                          text: 'No pudimos buscar paradas ahora.',
                          icon: Icons.cloud_off_rounded,
                        ),
                      ],
                      _ => [
                        const _HintRow(
                          text: 'Buscando paradas…',
                          icon: Icons.hourglass_top_rounded,
                        ),
                      ],
                    },
                    const SizedBox(height: AppSpace.sm),
                  ],
                  _SectionLabel(
                    typed.isEmpty ? 'Lugares populares' : 'Lugares',
                  ),
                  if (places.isEmpty)
                    const _HintRow(
                      text: 'Ningún lugar popular coincide.',
                      icon: Icons.search_off_rounded,
                    ),
                  for (final poi in places)
                    _PlaceRow(
                      key: ValueKey('nearby-poi-${poi.name}'),
                      icon: poi.icon,
                      title: poi.name,
                      subtitle: poi.ringOrZone ?? poi.category,
                      selected:
                          _picked?.lat == poi.lat && _picked?.lon == poi.lon,
                      onTap: () => _pick(
                        _Picked(
                          label: poi.name,
                          lat: poi.lat,
                          lon: poi.lon,
                          icon: poi.icon,
                          detail: poi.ringOrZone ?? poi.category,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _SubmitBar(
              picked: _picked,
              radius: _radius,
              onRadius: (r) => setState(() => _radius = r),
              onSubmit: _submit,
              bottomInset: media.viewInsets.bottom > 0
                  ? AppSpace.md
                  : media.padding.bottom + AppSpace.md,
              colors: colors,
              text: text,
            ),
          ],
        ),
      ),
    );
  }
}

/// Placa + «¿Qué micro pasa cerca?» + bajada.
class _SheetTitle extends StatelessWidget {
  const _SheetTitle();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final plate = AppColors.tint(AppColors.success, colors.surface);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: plate,
            borderRadius: BorderRadius.circular(AppRadius.tile),
          ),
          child: Icon(
            Icons.share_location_rounded,
            color: AppColors.legible(AppColors.success, plate),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Qué micro pasa cerca?',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Elige un punto y te mostramos las líneas y su sentido.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Atajo grande: «Mi ubicación» / «Marcar en el mapa».
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = AppColors.tint(colors.primary, colors.surface, 0.1);
    final ink = AppColors.legible(colors.primary, fill);
    return PressScale(
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.input),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.md,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: busy
                      ? Icon(Icons.more_horiz_rounded, size: 20, color: ink)
                      : Icon(icon, size: 20, color: ink),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w700,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xs,
        AppSpace.sm,
        AppSpace.xs,
        AppSpace.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  const _HintRow({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: AppSpace.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de un lugar o parada; elegida, se marca con el color primario.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final fill = selected
        ? AppColors.tint(colors.primary, colors.surface, 0.12)
        : Colors.transparent;
    final plate = AppColors.tint(colors.primary, colors.surface, 0.1);
    // El resaltado lo pinta el propio ListTile (`selectedTileColor`) sobre el
    // Material de la hoja: una caja de color por encima taparía su ripple.
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: onTap,
        dense: true,
        selected: selected,
        selectedTileColor: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: plate,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.legible(colors.primary, plate),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        trailing: selected
            ? Icon(
                Icons.check_circle_rounded,
                color: AppColors.legible(colors.primary, fill),
              )
            : null,
      ),
    );
  }
}

/// Pie fijo: el punto elegido, el radio y «Buscar cerca».
class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.picked,
    required this.radius,
    required this.onRadius,
    required this.onSubmit,
    required this.bottomInset,
    required this.colors,
    required this.text,
  });

  final _Picked? picked;
  final int radius;
  final ValueChanged<int> onRadius;
  final VoidCallback onSubmit;
  final double bottomInset;
  final ColorScheme colors;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final current = picked;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.lg + 4,
          AppSpace.md,
          AppSpace.lg + 4,
          bottomInset,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: Motion.fade,
              child: current == null
                  ? Text(
                      'Elige un lugar de la lista, tu ubicación o un punto '
                      'del mapa.',
                      key: const ValueKey('nearby-picked-empty'),
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : Row(
                      key: ValueKey('nearby-picked-${current.label}'),
                      children: [
                        Icon(
                          current.icon,
                          size: 20,
                          color: AppColors.legible(
                            AppColors.accent,
                            colors.surface,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            current.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.xs + 2,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.xs),
                  child: Text(
                    'Radio',
                    style: text.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final r in kNearbyRadii)
                  ChoiceChip(
                    key: ValueKey('nearby-sheet-radius-$r'),
                    label: Text(formatNearbyDistance(r.toDouble())),
                    selected: r == radius,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onRadius(r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            FilledButton.icon(
              key: const ValueKey('nearby-submit'),
              onPressed: current == null ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
              ),
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('Buscar cerca'),
            ),
          ],
        ),
      ),
    );
  }
}
