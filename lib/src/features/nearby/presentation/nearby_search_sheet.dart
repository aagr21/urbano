import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/location/place_search.dart';
import '../../../core/location/reverse_geocoding.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/location.dart';
import '../../journey/data/popular_places.dart';
import '../../journey/domain/journey_place.dart';
import '../../stops/presentation/stop_search_providers.dart';
import '../domain/nearby_micros.dart';
import 'nearby_search_widgets.dart';

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

  NearbyPickedPlace? _picked;
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

  void _pick(NearbyPickedPlace picked) {
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
        NearbyPickedPlace(
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
    final picked = NearbyPickedPlace(
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
    final places = searchPopularPlaces(_field.text);
    final stopHits = _query.length >= _minStopQuery
        ? ref.watch(stopNameSearchProvider(_query))
        : null;
    // Calles y lugares de OpenStreetMap (Photon, acotado a Santa Cruz).
    final street = _field.text.trim();
    final osmHits = street.length >= placeSearchMinChars
        ? ref.watch(placeSearchProvider(street))
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
                  const NearbySearchTitle(),
                  const SizedBox(height: AppSpace.lg),
                  TextField(
                    key: const ValueKey('nearby-search-field'),
                    controller: _field,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Busca una calle, lugar o parada',
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
                      // El ancho se reparte por lo que dice cada uno: mitad y
                      // mitad dejaba «Marcar en el mapa» sin lugar (medido con
                      // Inter en test/nearby_quick_action_test.dart).
                      Expanded(
                        flex: 5,
                        child: NearbyQuickAction(
                          key: const ValueKey('nearby-use-location'),
                          icon: Icons.near_me_rounded,
                          label: 'Mi ubicación',
                          busy: _locating,
                          onTap: _useMyLocation,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        flex: 6,
                        child: NearbyQuickAction(
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
                  if (osmHits != null) ...[
                    const NearbySectionLabel('Calles y lugares'),
                    ...switch (osmHits) {
                      AsyncData(:final value) when value.isEmpty => [
                        const NearbyHintRow(
                          text: 'Ninguna calle o lugar coincide.',
                          icon: Icons.search_off_rounded,
                        ),
                      ],
                      AsyncData(:final value) => [
                        for (final hit in value)
                          NearbyPlaceRow(
                            key: ValueKey('nearby-osm-${hit.name}'),
                            icon: hit.icon,
                            title: hit.name,
                            subtitle: hit.subtitle,
                            selected:
                                _picked?.lat == hit.lat &&
                                _picked?.lon == hit.lon,
                            onTap: () => _pick(
                              NearbyPickedPlace(
                                label: hit.name,
                                lat: hit.lat,
                                lon: hit.lon,
                                icon: hit.icon,
                                detail: hit.subtitle,
                              ),
                            ),
                          ),
                        // Atribución de los datos de OSM, obligatoria.
                        const NearbyHintRow(
                          text: osmAttribution,
                          icon: Icons.copyright_rounded,
                        ),
                      ],
                      AsyncError() => [
                        const NearbyHintRow(
                          text: 'No pudimos buscar calles ahora.',
                          icon: Icons.cloud_off_rounded,
                        ),
                      ],
                      _ => [
                        const NearbyHintRow(
                          text: 'Buscando calles y lugares…',
                          icon: Icons.hourglass_top_rounded,
                        ),
                      ],
                    },
                    const SizedBox(height: AppSpace.sm),
                  ],
                  if (stopHits != null) ...[
                    const NearbySectionLabel('Paradas'),
                    ...switch (stopHits) {
                      AsyncData(:final value) when value.isEmpty => [
                        NearbyHintRow(
                          text: 'Ninguna parada se llama «$_query».',
                          icon: Icons.search_off_rounded,
                        ),
                      ],
                      AsyncData(:final value) => [
                        for (final stop in value.take(8))
                          NearbyPlaceRow(
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
                              NearbyPickedPlace(
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
                        const NearbyHintRow(
                          text: 'No pudimos buscar paradas ahora.',
                          icon: Icons.cloud_off_rounded,
                        ),
                      ],
                      _ => [
                        const NearbyHintRow(
                          text: 'Buscando paradas…',
                          icon: Icons.hourglass_top_rounded,
                        ),
                      ],
                    },
                    const SizedBox(height: AppSpace.sm),
                  ],
                  NearbySectionLabel(
                    _field.text.trim().isEmpty
                        ? 'Lugares populares'
                        : 'Lugares',
                  ),
                  if (places.isEmpty)
                    const NearbyHintRow(
                      text: 'Ningún lugar popular coincide.',
                      icon: Icons.search_off_rounded,
                    ),
                  for (final poi in places)
                    NearbyPlaceRow(
                      key: ValueKey('nearby-poi-${poi.name}'),
                      icon: poi.icon,
                      title: poi.name,
                      subtitle: poi.ringOrZone ?? poi.category,
                      selected:
                          _picked?.lat == poi.lat && _picked?.lon == poi.lon,
                      onTap: () => _pick(
                        NearbyPickedPlace(
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
            NearbySubmitBar(
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
