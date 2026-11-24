import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/location/reverse_geocoding.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius, AppSpace;
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../application/journey_planner_controller.dart';
import '../../application/saved_trips_controller.dart';
import '../../application/trip_history_controller.dart';
import '../../data/popular_places.dart';
import '../../data/saved_trips.dart';
import '../../data/trip_history.dart';
import '../../domain/journey_place.dart';
import 'journey_destination_sheet_header.dart';
import 'journey_endpoint_field.dart';
import 'journey_plan_button.dart';
import 'journey_recent_destinations.dart';
import 'journey_recent_destinations_unified.dart';
import 'journey_swap_divider.dart';
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
  late JourneyPlace? _origin;
  late JourneyPlace? _destination;

  /// Último punto GPS conocido: si el usuario borra el texto del origen,
  /// puede volver a «Mi ubicación» sin esperar un fix nuevo.
  JourneyPlaceLocation? _gpsOrigin;

  final TextEditingController _originCtrl = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final TextEditingController _destinationCtrl = TextEditingController();
  final FocusNode _destinationFocus = FocusNode();
  String _originQuery = '';
  String _destinationQuery = '';

  /// `true` en cuanto el usuario escribe o elige un origen propio. Un fix del
  /// GPS que llegue tarde no puede pisar lo que la persona ya eligió: solo
  /// queda guardado como opción «Mi ubicación».
  bool _originTouched = false;

  /// `true` mientras se busca el primer fix del GPS para el origen.
  bool _locating = false;

  /// `true` cuando no hubo forma de leer la ubicación (permiso o servicio).
  bool _originFailed = false;

  int _recentPage = 0;
  static const int _recentPageSize = 5;

  @override
  void initState() {
    super.initState();
    // El origen por defecto es «Mi ubicación»: si ya hay una posición conocida
    // se usa en el acto y, si no, se pide al GPS sin bloquear la hoja.
    _origin = widget.initialOrigin;
    _destination = widget.initialDestination;
    _locating = _origin == null;
    _syncOriginText();
    _syncDestinationText();
    _originFocus.addListener(_onFocusChanged);
    _destinationFocus.addListener(_onFocusChanged);
    _ensureOriginLocation();
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

  /// Las sugerencias viven del foco: al entrar o salir de un campo cambia lo
  /// que se pinta debajo, así que hay que reconstruir.
  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _ensureOriginLocation() async {
    if (_origin != null) {
      if (_locating) setState(() => _locating = false);
      return;
    }

    final lastKnown = ref.read(lastKnownLocationProvider);
    if (lastKnown != null) {
      _setOriginPoint(lastKnown);
      return;
    }

    final granted = await ref
        .read(locationControllerProvider.notifier)
        .activate(context);
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _locating = false;
        _originFailed = true;
      });
      return;
    }

    final position = await ref.read(myLocationProvider.future);
    if (!mounted) return;
    if (position == null) {
      setState(() {
        _locating = false;
        _originFailed = true;
      });
      return;
    }
    _setOriginPoint(position);
  }

  /// Fija el origen GPS **de inmediato** (el punto es lo que habilita el
  /// viaje) y enriquece la dirección después, sin que la hoja espere a la red.
  ///
  /// Si mientras tanto el usuario ya escribió o eligió otro origen, el fix no
  /// lo pisa: solo se recuerda para la sugerencia «Mi ubicación».
  void _setOriginPoint(LatLng point) {
    if (!mounted) return;
    final place = JourneyPlaceLocation(
      lat: point.latitude,
      lon: point.longitude,
    );
    if (_originTouched) {
      setState(() {
        _gpsOrigin = place;
        _locating = false;
      });
      return;
    }
    setState(() {
      _gpsOrigin = place;
      _origin = place;
      _locating = false;
      _originFailed = false;
      _syncOriginText();
    });
    _enrichOriginAddress(point);
  }

  Future<void> _enrichOriginAddress(LatLng point) async {
    if (!mounted) return;
    try {
      final result = await ref.read(reverseGeocodeProvider(point).future);
      if (!mounted || result == null) return;
      final current = _origin;
      if (current is! JourneyPlaceLocation) return;
      if (current.lat != point.latitude || current.lon != point.longitude) {
        return;
      }
      final enriched = JourneyPlaceLocation(
        lat: point.latitude,
        lon: point.longitude,
        address: result.shortFormatted,
      );
      setState(() {
        // El texto visible sigue siendo «Mi ubicación»: la dirección queda
        // como dato del punto, no como valor del campo.
        _origin = enriched;
        _gpsOrigin = enriched;
      });
    } catch (_) {
      // Sin red se queda el punto: la hoja nunca depende del geocodificador.
    }
  }

  /// Texto del campo para un extremo. La ubicación del teléfono siempre se
  /// llama «Mi ubicación» (el punto GPS queda por detrás).
  String _textFor(JourneyPlace? place) => switch (place) {
    null => '',
    JourneyPlaceLocation() => 'Mi ubicación',
    JourneyPlacePoi(:final name) => name,
    JourneyPlacePoint(:final address) => address ?? 'Punto en el mapa',
  };

  void _syncOriginText() {
    final value = _textFor(_origin);
    _originQuery = value;
    if (_originCtrl.text == value) return;
    _originCtrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _syncDestinationText() {
    final value = _textFor(_destination);
    _destinationQuery = value;
    if (_destinationCtrl.text == value) return;
    _destinationCtrl.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _focusOrigin() {
    _originFocus.requestFocus();
    _originCtrl.selection = TextSelection.collapsed(
      offset: _originCtrl.text.length,
    );
  }

  void _focusDestination() {
    _destinationFocus.requestFocus();
    _destinationCtrl.selection = TextSelection.collapsed(
      offset: _destinationCtrl.text.length,
    );
  }

  /// Escribir manda: si el texto deja de coincidir con el lugar resuelto, el
  /// extremo se vacía hasta que se elija una sugerencia (o el mapa).
  void _onOriginChanged(String value) {
    setState(() {
      _originTouched = true;
      _originQuery = value;
      if (value != _textFor(_origin)) _origin = null;
    });
  }

  void _onDestinationChanged(String value) {
    setState(() {
      _destinationQuery = value;
      if (value != _textFor(_destination)) _destination = null;
    });
  }

  /// Hitos populares que coinciden con lo escrito (nombre, categoría o zona).
  List<SantaCruzPoi> _matches(String query) {
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

  bool _wantsGps(String query) =>
      _gpsOrigin != null &&
      'mi ubicación'.contains(query.trim().toLowerCase()) &&
      query.trim().isNotEmpty;

  Widget? _originSuggestions() {
    if (!_originFocus.hasFocus || _originQuery.trim().isEmpty) return null;
    return _buildSuggestionPanel(
      isOrigin: true,
      query: _originQuery,
      pois: _matches(_originQuery),
      // El GPS siempre está a un toque mientras haya punto, escriba lo que
      // escriba el usuario.
      onUseGps: _gpsOrigin != null ? _useGpsOrigin : null,
    );
  }

  Widget? _destinationSuggestions() {
    if (!_destinationFocus.hasFocus || _destinationQuery.trim().isEmpty) {
      return null;
    }
    return _buildSuggestionPanel(
      isOrigin: false,
      query: _destinationQuery,
      pois: _matches(_destinationQuery),
    );
  }

  /// Panel de sugerencias debajo del campo: «Mi ubicación» (solo origen),
  /// hitos populares y la salida al mapa.
  Widget _buildSuggestionPanel({
    required bool isOrigin,
    required String query,
    required List<SantaCruzPoi> pois,
    VoidCallback? onUseGps,
  }) {
    final colors = context.colors;
    final text = context.text;

    Widget tile({
      required IconData icon,
      required String title,
      String? subtitle,
      required VoidCallback onTap,
    }) {
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
                  color: AppColors.tint(colors.primary, colors.surface, 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: AppColors.legible(
                    colors.primary,
                    AppColors.tint(colors.primary, colors.surface, 0.12),
                  ),
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
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
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

    final rows = <Widget>[
      if (onUseGps != null)
        tile(
          icon: Icons.near_me_rounded,
          title: 'Mi ubicación',
          subtitle: 'Usar tu GPS como punto',
          onTap: onUseGps,
        ),
      for (final poi in pois)
        tile(
          icon: poi.icon,
          title: poi.name,
          subtitle: poi.ringOrZone ?? poi.category,
          onTap: () => _pickPoi(poi, isOrigin: isOrigin),
        ),
      if (pois.isEmpty && onUseGps == null)
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
      tile(
        icon: Icons.map_outlined,
        title: 'Elegir en el mapa',
        onTap: isOrigin ? _pickOriginFromMap : _pickDestinationFromMap,
      ),
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

  void _pickPoi(SantaCruzPoi poi, {required bool isOrigin}) {
    final place = JourneyPlacePoi(
      name: poi.name,
      lat: poi.lat,
      lon: poi.lon,
      subtitle: poi.ringOrZone ?? poi.category,
    );
    setState(() {
      if (isOrigin) {
        _origin = place;
        _originTouched = true;
        _locating = false;
        _originFailed = false;
        _syncOriginText();
        _originFocus.unfocus();
      } else {
        _destination = place;
        _syncDestinationText();
        _destinationFocus.unfocus();
      }
    });
  }

  void _useGpsOrigin() {
    final gps = _gpsOrigin;
    if (gps == null) return;
    setState(() {
      _origin = gps;
      _originTouched = false;
      _locating = false;
      _originFailed = false;
      _syncOriginText();
      _originFocus.unfocus();
    });
  }

  void _submitOrigin(String value) {
    final matches = _matches(value);
    if (matches.isNotEmpty) {
      _pickPoi(matches.first, isOrigin: true);
    } else if (_wantsGps(value)) {
      _useGpsOrigin();
    }
  }

  void _submitDestination(String value) {
    final matches = _matches(value);
    if (matches.isNotEmpty) _pickPoi(matches.first, isOrigin: false);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final savedTrips =
        ref.watch(savedTripsControllerProvider).valueOrNull ??
        const <SavedTrip>[];
    final history =
        ref.watch(tripHistoryControllerProvider).valueOrNull ??
        const <TripHistoryEntry>[];
    final unified = buildUnifiedRecentList(
      savedTrips: savedTrips,
      history: history,
    );
    final totalPages = (unified.length / _recentPageSize).ceil();
    final pageItems = unified
        .skip(_recentPage * _recentPageSize)
        .take(_recentPageSize)
        .toList();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        // Tocar fuera de un campo cierra sus sugerencias y el teclado; los
        // botones e inputs hijos ganan el gesto, así que no se traga nada.
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: bottomInset + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DestinationSheetHeader(),
                const SizedBox(height: AppSpace.lg),
                _buildPlannerCard(context),
                if (pageItems.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg + AppSpace.xs),
                  _buildRecentHeader(context, text, unified.length),
                  const SizedBox(height: AppSpace.sm),
                  ..._buildUnifiedRecentTiles(pageItems),
                  if (totalPages > 1) ...[
                    const SizedBox(height: AppSpace.sm),
                    _buildPagination(context, text, totalPages),
                  ],
                ] else
                  _buildEmptyRecents(context, text),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tarjeta del planeador: origen y destino como dos campos tonales, el
  /// botón de invertir entre ellos y el CTA de planificar.
  Widget _buildPlannerCard(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Container(
      decoration: BoxDecoration(
        // En oscuro la hoja y la tarjeta comparten superficie: se sube un
        // escalón para que la tarjeta no se lea solo por el filete.
        color: dark ? colors.surfaceContainerHigh : colors.surface,
        borderRadius: radius,
        border: Border.all(color: colors.outlineVariant, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.22)
                : HtmlDesignTokens.slate900.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Lavado ambiental de las esquinas: da profundidad sin bordes.
            Positioned(
              top: -64,
              right: -64,
              child: _CornerGlow(
                color: HtmlDesignTokens.emerald500,
                alpha: dark ? 0.1 : 0.16,
              ),
            ),
            Positioned(
              bottom: -64,
              left: -64,
              child: _CornerGlow(
                color: HtmlDesignTokens.rose500,
                alpha: dark ? 0.08 : 0.12,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JourneyEndpointField(
                    label: 'Origen',
                    value: _originLabel,
                    emptyHint: 'Escribe o elige tu origen',
                    empty: _origin == null,
                    subtitle: _originSubtitle,
                    tag: _origin is JourneyPlaceLocation ? 'GPS' : null,
                    icon: Icons.my_location_rounded,
                    accent: HtmlDesignTokens.emerald600,
                    controller: _originCtrl,
                    focusNode: _originFocus,
                    inputKey: const ValueKey('journey-origin-input'),
                    onChanged: _onOriginChanged,
                    onSubmitted: _submitOrigin,
                    suggestions: _originSuggestions(),
                    onTap: _focusOrigin,
                    onMapTap: _pickOriginFromMap,
                  ),
                  JourneySwapDivider(onSwap: _swapEndpoints),
                  JourneyEndpointField(
                    label: 'Destino',
                    value: _destinationLabelOrNull,
                    emptyHint: '¿A dónde vas?',
                    empty: _destination == null,
                    subtitle: _destinationSubtitle,
                    icon: Icons.location_on_rounded,
                    accent: HtmlDesignTokens.rose500,
                    controller: _destinationCtrl,
                    focusNode: _destinationFocus,
                    inputKey: const ValueKey('journey-destination-input'),
                    onChanged: _onDestinationChanged,
                    onSubmitted: _submitDestination,
                    suggestions: _destinationSuggestions(),
                    onTap: _focusDestination,
                    onMapTap: _pickDestinationFromMap,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  JourneyPlanButton(
                    enabled: _canPlan(),
                    onPressed: _canPlan() ? _planAndClose : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Encabezado de la sección de destinos recientes.
  Widget _buildRecentHeader(BuildContext context, TextTheme text, int count) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppColors.tint(
      HtmlDesignTokens.emerald600,
      colors.surface,
      dark ? 0.18 : 0.1,
    );
    final ink = AppColors.legible(HtmlDesignTokens.emerald600, fill);

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(Icons.history_rounded, size: 16, color: ink),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            'Tus destinos recientes',
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$count',
            style: text.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  /// Aviso discreto cuando todavía no hay historial ni viajes guardados.
  Widget _buildEmptyRecents(BuildContext context, TextTheme text) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg + AppSpace.xs),
      child: Row(
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 16,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              'Tus destinos recientes aparecerán aquí.',
              style: text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Estado de los extremos ───────────────────────────────────────────────

  /// Origen a la vista: la ubicación del teléfono siempre se llama
  /// «Mi ubicación» (el punto GPS queda por detrás); un lugar o un punto
  /// elegido a mano sí muestran su nombre.
  String? get _originLabel => switch (_origin) {
    null => null,
    JourneyPlaceLocation() => 'Mi ubicación',
    JourneyPlacePoi(:final name) => name,
    JourneyPlacePoint(:final address) => address ?? 'Punto en el mapa',
  };

  String? get _originSubtitle {
    if (_locating) return 'Ubicando tu posición…';
    if (_originFailed) return 'Activa tu ubicación o elige en el mapa';
    return switch (_origin) {
      null => 'Escribe un lugar o elige en el mapa',
      JourneyPlaceLocation() => 'Usando la ubicación de tu teléfono',
      JourneyPlacePoi(:final subtitle) => subtitle ?? 'Lugar elegido',
      JourneyPlacePoint() => 'Punto elegido en el mapa',
    };
  }

  String? get _destinationLabelOrNull => switch (_destination) {
    null => null,
    JourneyPlacePoi(:final name) => name,
    JourneyPlacePoint(:final address) => address ?? 'Punto en el mapa',
    JourneyPlaceLocation(:final address) => address ?? 'Mi ubicación',
  };

  String? get _destinationSubtitle => switch (_destination) {
    null => 'Escribe un lugar o toca uno reciente',
    JourneyPlacePoi(:final subtitle) => subtitle,
    JourneyPlacePoint() => 'Punto elegido en el mapa',
    JourneyPlaceLocation() => 'Usando la ubicación de tu teléfono',
  };

  void _swapEndpoints() {
    setState(() {
      final temp = _origin;
      _origin = _destination;
      _destination = temp;
      _locating = false;
      // Tras invertir, el texto de cada campo sigue a su nuevo lugar y el
      // origen deja de ser intocable salvo que el GPS haya vuelto arriba.
      _originTouched = _origin is! JourneyPlaceLocation;
      _syncOriginText();
      _syncDestinationText();
    });
  }

  bool _canPlan() => _origin != null && _destination != null;

  Future<void> _pickOriginFromMap() async {
    final place = await pickEndpointFromMap(
      context: context,
      ref: ref,
      title: 'Origen',
      currentPoint: _origin?.pointOrNull,
    );
    if (place != null && mounted) {
      setState(() {
        _origin = place;
        _originTouched = true;
        _locating = false;
        _originFailed = false;
        _syncOriginText();
      });
    }
  }

  Future<void> _pickDestinationFromMap() async {
    final place = await pickEndpointFromMap(
      context: context,
      ref: ref,
      title: 'Destino',
      currentPoint: _destination?.pointOrNull,
    );
    if (place != null && mounted) {
      setState(() {
        _destination = place;
        _syncDestinationText();
      });
    }
  }

  Future<void> _planAndClose() async {
    if (!_canPlan() || !mounted) return;

    final planner = ref.read(journeyPlannerControllerProvider.notifier);
    planner.setPlace(_origin!, isOrigin: true);
    planner.setPlace(_destination!, isOrigin: false);
    // Trigger planning immediately so results are ready when navigating
    planner.submit();

    // Save as full trip
    await ref
        .read(savedTripsControllerProvider.notifier)
        .add(origin: _origin!, destination: _destination!);

    // Save destination in history
    await ref
        .read(tripHistoryControllerProvider.notifier)
        .record(destination: _destination!);

    if (!mounted) return;
    context.go('/journey');
  }

  Future<void> _useSavedTrip(SavedTrip trip) async {
    setState(() {
      _origin = JourneyPlaceLocation(
        lat: trip.originLat,
        lon: trip.originLon,
        address: trip.originLabel,
      );
      _destination = JourneyPlacePoi(
        name: trip.destinationLabel,
        lat: trip.destinationLat,
        lon: trip.destinationLon,
        subtitle: trip.destinationSubtitle,
      );
      _locating = false;
      _originFailed = false;
      _syncOriginText();
      _syncDestinationText();
    });
    // Auto-plan and navigate
    await _planAndClose();
  }

  Future<void> _deleteSavedTrip(SavedTrip trip) async {
    await ref.read(savedTripsControllerProvider.notifier).remove(trip);
    if (mounted) setState(() {});
  }

  Future<void> _useHistoryDestination(TripHistoryEntry entry) async {
    final lastKnown = ref.read(lastKnownLocationProvider);
    setState(() {
      _destination = JourneyPlacePoi(
        name: entry.label,
        lat: entry.lat,
        lon: entry.lon,
        subtitle: entry.subtitle,
      );
      // Try to use last known location as origin
      if (lastKnown != null && _origin == null) {
        _origin = JourneyPlaceLocation(
          lat: lastKnown.latitude,
          lon: lastKnown.longitude,
        );
        _locating = false;
      }
      _syncOriginText();
      _syncDestinationText();
    });
    // Auto-plan and navigate if we have both origin and destination
    if (_origin != null) {
      await _planAndClose();
    }
  }

  /// Convierte la lista unificada en widgets [RecentDestinationTile].
  List<Widget> _buildUnifiedRecentTiles(List<RecentDestinationItem> items) {
    return items
        .asMap()
        .entries
        .map(
          (e) => RecentDestinationTile(
            key: ValueKey('recent-${e.value.key}'),
            item: e.value,
            onTap: () => _onRecentItemTap(e.value),
            onDelete: () => _onRecentItemDelete(e.value),
          ),
        )
        .toList();
  }

  /// Controles de paginación con flechas e indicador de página.
  Widget _buildPagination(
    BuildContext context,
    TextTheme text,
    int totalPages,
  ) {
    final colors = context.colors;
    final canGoPrev = _recentPage > 0;
    final canGoNext = _recentPage < totalPages - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PressScale(
          scale: 0.95,
          child: IconButton(
            onPressed: canGoPrev
                ? () {
                    setState(() {
                      _recentPage--;
                    });
                  }
                : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: canGoPrev ? colors.primary : colors.outlineVariant,
              size: 26,
            ),
            tooltip: 'Página anterior',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Text(
            '${_recentPage + 1} / $totalPages',
            style: text.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        PressScale(
          scale: 0.95,
          child: IconButton(
            onPressed: canGoNext
                ? () {
                    setState(() {
                      _recentPage++;
                    });
                  }
                : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoNext ? colors.primary : colors.outlineVariant,
              size: 26,
            ),
            tooltip: 'Página siguiente',
          ),
        ),
      ],
    );
  }

  void _onRecentItemTap(RecentDestinationItem item) {
    if (item is RecentDestinationSavedTrip) {
      _useSavedTrip(item.trip);
    } else if (item is RecentDestinationHistoryEntry) {
      _useHistoryDestination(item.entry);
    }
  }

  Future<void> _onRecentItemDelete(RecentDestinationItem item) async {
    if (item is RecentDestinationSavedTrip) {
      await _deleteSavedTrip(item.trip);
    } else if (item is RecentDestinationHistoryEntry) {
      await ref.read(tripHistoryControllerProvider.notifier).remove(item.entry);
      if (mounted) setState(() {});
    }
  }
}

/// Mancha radial suave para las esquinas de la tarjeta del planeador.
class _CornerGlow extends StatelessWidget {
  const _CornerGlow({required this.color, required this.alpha});

  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      width: 148,
      height: 148,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    ),
  );
}
