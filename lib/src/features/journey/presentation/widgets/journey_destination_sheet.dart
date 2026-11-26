import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/location/place_search.dart';
import '../../../../core/location/reverse_geocoding.dart';
import '../../../../core/theme/app_theme.dart' show AppSpace;
import '../../../../core/utils/location.dart';
import '../../application/endpoint_submit.dart';
import '../../application/journey_place_factory.dart';
import '../../application/recent_destinations.dart';
import '../../application/trip_launcher.dart';
import '../../data/popular_places.dart';
import '../../domain/destination_draft.dart';
import '../../domain/journey_place.dart';
import 'journey_destination_endpoints_card.dart';
import 'journey_destination_recents_section.dart';
import 'journey_destination_sheet_header.dart';
import 'journey_destination_suggestions.dart';
import 'pick_endpoint_from_map.dart';

/// Bottom sheet del inicio para armar el viaje: origen (por defecto la
/// ubicación del teléfono), destino y destinos recientes.
Future<void> showJourneyDestinationSheet({
  required BuildContext context,
  required WidgetRef ref,
  required JourneyPlace? initialOrigin,
  required JourneyPlace? initialDestination,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DestinationSheetContent(
      initialOrigin: initialOrigin,
      initialDestination: initialDestination,
    ),
  );
}

/// Cableado de la hoja: traduce cada gesto a una transición de
/// [DestinationDraft] (la política vive allí), pide el GPS para el origen y
/// lanza el viaje con [TripLauncher]. Pintar es cosa de
/// [DestinationEndpointsCard] y [DestinationRecentsSection].
class _DestinationSheetContent extends ConsumerStatefulWidget {
  const _DestinationSheetContent({
    required this.initialOrigin,
    required this.initialDestination,
  });

  final JourneyPlace? initialOrigin;
  final JourneyPlace? initialDestination;

  @override
  ConsumerState<_DestinationSheetContent> createState() =>
      _DestinationSheetContentState();
}

class _DestinationSheetContentState
    extends ConsumerState<_DestinationSheetContent> {
  late DestinationDraft _draft;

  final _originCtrl = TextEditingController();
  final _originFocus = FocusNode();
  final _destinationCtrl = TextEditingController();
  final _destinationFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _draft = DestinationDraft.initial(
      origin: widget.initialOrigin,
      destination: widget.initialDestination,
    );
    _syncControllers();
    _originFocus.addListener(_onFocusChanged);
    _destinationFocus.addListener(_onFocusChanged);
    // El origen por defecto es «Mi ubicación»: se pide sin bloquear la hoja.
    if (_draft.locating) _locateOrigin();
  }

  @override
  void dispose() {
    _originFocus.removeListener(_onFocusChanged);
    _destinationFocus.removeListener(_onFocusChanged);
    _originCtrl.dispose();
    _originFocus.dispose();
    _destinationCtrl.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  // ── Estado ───────────────────────────────────────────────────────────────

  /// Aplica una transición y pone los campos al día con el borrador.
  void _apply(DestinationDraft Function(DestinationDraft) transition) {
    if (!mounted) return;
    setState(() => _draft = transition(_draft));
    _syncControllers();
  }

  /// Los campos muestran SIEMPRE `originQuery`/`destinationQuery`: escribir
  /// ya coincide (no se toca), elegir un lugar reemplaza el texto.
  void _syncControllers() {
    _syncText(_originCtrl, _draft.originQuery);
    _syncText(_destinationCtrl, _draft.destinationQuery);
  }

  static void _syncText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  /// Las sugerencias viven del foco: entrar o salir de un campo cambia lo
  /// que se pinta debajo.
  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  // ── GPS del origen ───────────────────────────────────────────────────────

  Future<void> _locateOrigin() async {
    final lastKnown = ref.read(lastKnownLocationProvider);
    if (lastKnown != null) return _onGpsFix(lastKnown);

    final granted = await ref
        .read(locationControllerProvider.notifier)
        .activate(context);
    if (!mounted) return;
    final position = granted ? await ref.read(myLocationProvider.future) : null;
    if (position == null) return _apply((d) => d.gpsUnavailable());
    _onGpsFix(position);
  }

  /// El fix fija el origen de inmediato; la dirección llega después, sin que
  /// la hoja espere a la red (y sin red se queda el punto).
  Future<void> _onGpsFix(LatLng point) async {
    final lat = point.latitude, lon = point.longitude;
    _apply((d) => d.gpsResolved(lat: lat, lon: lon));
    if (!_draft.originIsGpsAt(lat: lat, lon: lon)) return;
    try {
      final result = await ref.read(reverseGeocodeProvider(point).future);
      if (result == null) return;
      _apply(
        (d) => d.addressResolved(
          lat: lat,
          lon: lon,
          address: result.shortFormatted,
        ),
      );
    } catch (_) {
      // El geocodificador es un extra: la hoja nunca depende de él.
    }
  }

  // ── Gestos de los campos ─────────────────────────────────────────────────

  void _pick(JourneyPlace place, {required bool isOrigin}) {
    _apply((d) => d.picked(place, isOrigin: isOrigin));
    (isOrigin ? _originFocus : _destinationFocus).unfocus();
  }

  void _useGps() {
    _apply((d) => d.usedGps());
    _originFocus.unfocus();
  }

  void _focus(FocusNode node, TextEditingController controller) {
    node.requestFocus();
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  Future<void> _pickFromMap({required bool isOrigin}) async {
    final place = await pickEndpointFromMap(
      context: context,
      ref: ref,
      title: isOrigin ? 'Origen' : 'Destino',
      currentPoint:
          (isOrigin ? _draft.origin : _draft.destination)?.pointOrNull,
    );
    if (place != null) _apply((d) => d.picked(place, isOrigin: isOrigin));
  }

  /// Calles y lugares de OSM para lo escrito, o `null` si aún es muy corto.
  AsyncValue<List<PlaceSuggestion>>? _online(String query) =>
      query.trim().length < placeSearchMinChars
      ? null
      : ref.watch(placeSearchProvider(query.trim()));

  void _submit(String value, {required bool isOrigin}) {
    final query = value.trim();
    final choice = resolveEndpointSubmit(
      popular: matchPopularPlaces(value),
      wantsGps: isOrigin && _draft.wantsGps(value),
      firstOnline: query.length < placeSearchMinChars
          ? null
          : ref.read(placeSearchProvider(query)).valueOrNull?.firstOrNull,
    );
    switch (choice) {
      case SubmitPoi(:final poi):
        _pick(JourneyPlaceFactory.fromPoi(poi), isOrigin: isOrigin);
      case SubmitGps():
        _useGps();
      case SubmitSuggestion(:final hit):
        _pick(JourneyPlaceFactory.fromSuggestion(hit), isOrigin: isOrigin);
      case SubmitNothing():
        break;
    }
  }

  Widget? _suggestions({required bool isOrigin}) {
    final focus = isOrigin ? _originFocus : _destinationFocus;
    final query = isOrigin ? _draft.originQuery : _draft.destinationQuery;
    if (!focus.hasFocus || query.trim().isEmpty) return null;
    return DestinationSuggestionPanel(
      query: query,
      pois: matchPopularPlaces(query),
      onPickPoi: (poi) =>
          _pick(JourneyPlaceFactory.fromPoi(poi), isOrigin: isOrigin),
      onPickOnMap: () => _pickFromMap(isOrigin: isOrigin),
      // En el origen el GPS está a un toque mientras haya punto, escriba lo
      // que escriba el usuario.
      onUseGps: isOrigin && _draft.gpsOrigin != null ? _useGps : null,
      online: _online(query),
      onPickSuggestion: (hit) =>
          _pick(JourneyPlaceFactory.fromSuggestion(hit), isOrigin: isOrigin),
    );
  }

  EndpointFieldActions _actions({required bool isOrigin}) =>
      EndpointFieldActions(
        onChanged: (value) => _apply(
          (d) => isOrigin ? d.originTyped(value) : d.destinationTyped(value),
        ),
        onSubmitted: (value) => _submit(value, isOrigin: isOrigin),
        onTap: () => isOrigin
            ? _focus(_originFocus, _originCtrl)
            : _focus(_destinationFocus, _destinationCtrl),
        onMapTap: () => _pickFromMap(isOrigin: isOrigin),
      );

  // ── Recientes y planificar ───────────────────────────────────────────────

  Future<void> _onRecentPicked(RecentDestinationItem item) async {
    switch (item) {
      case RecentDestinationSavedTrip(:final trip):
        _apply(
          (d) => d.tripLoaded(
            origin: JourneyPlaceFactory.originOf(trip),
            destination: JourneyPlaceFactory.destinationOf(trip),
          ),
        );
      case RecentDestinationHistoryEntry(:final entry):
        final lastKnown = ref.read(lastKnownLocationProvider);
        _apply(
          (d) => d.historyLoaded(
            destination: JourneyPlaceFactory.fromHistory(entry),
            lastKnown: lastKnown == null
                ? null
                : JourneyPlaceFactory.here(
                    lat: lastKnown.latitude,
                    lon: lastKnown.longitude,
                  ),
          ),
        );
    }
    // Con los dos extremos listos se viaja directo.
    if (_draft.canPlan) await _planAndClose();
  }

  Future<void> _planAndClose() async {
    final origin = _draft.origin, destination = _draft.destination;
    if (origin == null || destination == null || !mounted) return;
    await ref
        .read(tripLauncherProvider)
        .launch(origin: origin, destination: destination);
    if (!mounted) return;
    // La hoja se cierra ANTES de cambiar a Viaje: vive en el navegador de la
    // rama Inicio, y con solo `go()` quedaba abierta por detrás y reaparecía
    // al volver a la portada.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/journey');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        // Tocar fuera de un campo cierra sus sugerencias y el teclado; los
        // botones e inputs hijos ganan el gesto, así que no se traga nada.
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSpace.lg + AppSpace.xs,
              right: AppSpace.lg + AppSpace.xs,
              bottom: media.viewInsets.bottom + AppSpace.lg + AppSpace.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DestinationSheetHeader(),
                const SizedBox(height: AppSpace.lg),
                DestinationEndpointsCard(
                  draft: _draft,
                  originController: _originCtrl,
                  originFocus: _originFocus,
                  destinationController: _destinationCtrl,
                  destinationFocus: _destinationFocus,
                  origin: _actions(isOrigin: true),
                  destination: _actions(isOrigin: false),
                  originSuggestions: _suggestions(isOrigin: true),
                  destinationSuggestions: _suggestions(isOrigin: false),
                  onSwap: () => _apply((d) => d.swapped()),
                  onPlan: _planAndClose,
                ),
                DestinationRecentsSection(onPick: _onRecentPicked),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
