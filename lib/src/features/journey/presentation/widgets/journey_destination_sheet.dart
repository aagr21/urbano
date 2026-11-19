import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/location/reverse_geocoding.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../application/journey_planner_controller.dart';
import '../../application/journey_providers.dart';
import '../../application/trip_history_controller.dart';
import '../../data/popular_places.dart';
import '../../data/trip_history.dart';
import '../journey_planner_controller.dart';

/// Full trip saved locally (origin + destination).
@immutable
class SavedTrip {
  const SavedTrip({
    required this.originLabel,
    required this.originLat,
    required this.originLon,
    required this.destinationLabel,
    required this.destinationSubtitle,
    required this.destinationLat,
    required this.destinationLon,
    required this.lastUsed,
    this.durationMinutes,
  });

  final String originLabel;
  final double originLat;
  final double originLon;
  final String destinationLabel;
  final String? destinationSubtitle;
  final double destinationLat;
  final double destinationLon;
  final DateTime lastUsed;
  final int? durationMinutes;

  String get key =>
      '${originLabel.toLowerCase()}|${originLat.toStringAsFixed(4)}|${originLon.toStringAsFixed(4)}|'
      '${destinationLabel.toLowerCase()}|${destinationLat.toStringAsFixed(4)}|${destinationLon.toStringAsFixed(4)}';

  Map<String, Object?> toJson() => {
    'originLabel': originLabel,
    'originLat': originLat,
    'originLon': originLon,
    'destinationLabel': destinationLabel,
    if (destinationSubtitle != null && destinationSubtitle!.trim().isNotEmpty)
      'destinationSubtitle': destinationSubtitle,
    'destinationLat': destinationLat,
    'destinationLon': destinationLon,
    'lastUsed': lastUsed.toIso8601String(),
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
  };

  static SavedTrip? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final oLabel = raw['originLabel'];
    final oLat = raw['originLat'];
    final oLon = raw['originLon'];
    final dLabel = raw['destinationLabel'];
    final dLat = raw['destinationLat'];
    final dLon = raw['destinationLon'];
    final used = switch (raw['lastUsed']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    };
    if (oLabel is! String ||
        dLabel is! String ||
        oLat is! num ||
        oLon is! num ||
        dLat is! num ||
        dLon is! num ||
        used == null) {
      return null;
    }
    final dSub = raw['destinationSubtitle'];
    final dur = raw['durationMinutes'];
    return SavedTrip(
      originLabel: oLabel,
      originLat: oLat.toDouble(),
      originLon: oLon.toDouble(),
      destinationLabel: dLabel,
      destinationSubtitle: dSub is String && dSub.trim().isNotEmpty
          ? dSub
          : null,
      destinationLat: dLat.toDouble(),
      destinationLon: dLon.toDouble(),
      lastUsed: used,
      durationMinutes: dur is num ? dur.toInt() : null,
    );
  }
}

/// Local store for saved trips.
abstract interface class SavedTripsStore {
  Future<List<SavedTrip>> load();
  Future<void> save(List<SavedTrip> trips);
}

class SharedPreferencesSavedTripsStore implements SavedTripsStore {
  static const _key = 'urbano.trips.saved';

  @override
  Future<List<SavedTrip>> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(SavedTrip.fromJson)
          .whereType<SavedTrip>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<SavedTrip> trips) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _key,
        jsonEncode([for (final t in trips) t.toJson()]),
      );
    } catch (_) {}
  }
}

/// Controller for saved trips.
final savedTripsControllerProvider =
    AsyncNotifierProvider<SavedTripsController, List<SavedTrip>>(
      SavedTripsController.new,
    );

class SavedTripsController extends AsyncNotifier<List<SavedTrip>> {
  SavedTripsController([this._store]);

  final SavedTripsStore? _store;

  static const int maxEntries = 10;

  SavedTripsStore get _resolvedStore =>
      _store ?? SharedPreferencesSavedTripsStore();

  @override
  Future<List<SavedTrip>> build() async {
    final saved = await _resolvedStore.load();
    return _sorted(saved);
  }

  Future<void> add({
    required JourneyPlace origin,
    required JourneyPlace destination,
    int? durationMinutes,
    DateTime? at,
  }) async {
    final oPoint = origin.pointOrNull;
    final dPoint = destination.pointOrNull;
    if (oPoint == null || dPoint == null) return;

    final oDesc = _describe(origin);
    final dDesc = _describe(destination);

    final trip = SavedTrip(
      originLabel: oDesc.label,
      originLat: oPoint.lat,
      originLon: oPoint.lon,
      destinationLabel: dDesc.label,
      destinationSubtitle: dDesc.subtitle,
      destinationLat: dPoint.lat,
      destinationLon: dPoint.lon,
      lastUsed: at ?? DateTime.now(),
      durationMinutes: durationMinutes,
    );

    final current = state.valueOrNull ?? await future;
    final next = _sorted([trip, ...current.where((t) => t.key != trip.key)]);
    state = AsyncData(next);
    await _resolvedStore.save(next);
  }

  Future<void> remove(SavedTrip trip) async {
    final current = state.valueOrNull ?? await future;
    final next = current.where((t) => t.key != trip.key).toList();
    state = AsyncData(next);
    await _resolvedStore.save(next);
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    await _resolvedStore.save(const []);
  }

  static List<SavedTrip> _sorted(List<SavedTrip> trips) {
    final list = [...trips]..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return list.length <= maxEntries ? list : list.sublist(0, maxEntries);
  }

  static ({String label, String? subtitle}) _describe(JourneyPlace place) {
    return switch (place) {
      JourneyPlacePoi(:final name, :final subtitle) => (
        label: name,
        subtitle: subtitle == null || subtitle.trim().isEmpty
            ? 'Lugar de Santa Cruz'
            : subtitle,
      ),
      JourneyPlacePoint(:final address, :final lat, :final lon) => (
        label:
            address ?? '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
        subtitle: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
      ),
      JourneyPlaceLocation(:final address, :final lat, :final lon) => (
        label: address ?? 'Mi ubicación',
        subtitle: '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
      ),
    };
  }
}

/// Bottom sheet for picking destination with origin pre-filled and recent destinations.
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
  final TextEditingController _destinationCtrl = TextEditingController();
  final FocusNode _destinationFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Default origin = Mi ubicación (last known or request GPS)
    _origin = widget.initialOrigin;
    _destination = widget.initialDestination;
    if (_destination != null) {
      _destinationCtrl.text = _destinationLabel(_destination!);
    }
    _ensureOriginLocation();
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  Future<void> _ensureOriginLocation() async {
    if (_origin != null) return;
    final lastKnown = ref.read(lastKnownLocationProvider);
    if (lastKnown != null) {
      String? address;
      try {
        final result = await ref.read(
          reverseGeocodeProvider(
            LatLng(lastKnown.latitude, lastKnown.longitude),
          ).future,
        );
        address = result?.shortFormatted;
      } catch (_) {}
      setState(() {
        _origin = JourneyPlaceLocation(
          lat: lastKnown.latitude,
          lon: lastKnown.longitude,
          address: address,
        );
      });
    } else {
      // Request GPS
      final granted = await ref
          .read(locationControllerProvider.notifier)
          .activate(context);
      if (granted && mounted) {
        final position = await ref.read(myLocationProvider.future);
        if (position != null && mounted) {
          String? address;
          try {
            final result = await ref.read(
              reverseGeocodeProvider(
                LatLng(position.latitude, position.longitude),
              ).future,
            );
            address = result?.shortFormatted;
          } catch (_) {}
          setState(() {
            _origin = JourneyPlaceLocation(
              lat: position.latitude,
              lon: position.longitude,
              address: address,
            );
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final savedTrips =
        ref.watch(savedTripsControllerProvider).valueOrNull ??
        const <SavedTrip>[];
    final history =
        ref.watch(tripHistoryControllerProvider).valueOrNull ??
        const <TripHistoryEntry>[];

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: bottomInset + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Punto de partida: Mi ubicación (pre-filled, read-only)
              _OriginField(
                place: _origin,
                onMapTap: () => _pickOriginFromMap(),
                colors: colors,
                text: text,
              ),
              const SizedBox(height: 12),
              // Destino: TextField con botón "Mapa" al final
              _DestinationField(
                controller: _destinationCtrl,
                focusNode: _destinationFocus,
                place: _destination,
                onMapTap: () => _pickDestinationFromMap(),
                onPlaceTap: (poi) => _setDestinationFromPoi(poi),
                colors: colors,
                text: text,
              ),
              const SizedBox(height: 12),
              // Botón planificar
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.directions_transit_rounded),
                  label: const Text('Planificar viaje'),
                  onPressed: _canPlan() ? () => _planAndClose() : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                  ),
                ),
              ),
              if (savedTrips.isNotEmpty || history.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  'Tus destinos recientes',
                  style: text.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                // Saved trips (full origin→destination)
                if (savedTrips.isNotEmpty) ...[
                  Text(
                    'Viajes guardados',
                    style: text.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...savedTrips.map(
                    (trip) => _SavedTripTile(
                      key: ValueKey('saved-trip-${trip.key}'),
                      trip: trip,
                      onTap: () => _useSavedTrip(trip),
                      onDelete: () => _deleteSavedTrip(trip),
                      colors: colors,
                      text: text,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // History destinations only
                if (history.isNotEmpty) ...[
                  Text(
                    'Destinos frecuentes',
                    style: text.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...history.map(
                    (entry) => _HistoryDestinationTile(
                      key: ValueKey('history-dest-${entry.key}'),
                      entry: entry,
                      onTap: () => _useHistoryDestination(entry),
                      colors: colors,
                      text: text,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _canPlan() => _origin != null && _destination != null;

  String _destinationLabel(JourneyPlace place) {
    return switch (place) {
      JourneyPlacePoi(:final name) => name,
      JourneyPlacePoint(:final lat, :final lon, :final address) =>
        address ?? '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
      JourneyPlaceLocation(:final lat, :final lon) =>
        '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
    };
  }

  Future<void> _pickOriginFromMap() async {
    final params = <String, String>{'title': 'Origen'};
    if (_origin?.pointOrNull case final point?) {
      params['lat'] = '${point.lat}';
      params['lon'] = '${point.lon}';
    }
    final point = await context.push<JourneyPoint>(
      Uri(path: '/journey/pick', queryParameters: params).toString(),
    );
    if (point != null && mounted) {
      String? address;
      try {
        final result = await ref.read(
          reverseGeocodeProvider(LatLng(point.lat, point.lon)).future,
        );
        address = result?.shortFormatted;
      } catch (_) {}
      setState(() {
        _origin = JourneyPlacePoint(
          lat: point.lat,
          lon: point.lon,
          address: address,
        );
      });
    }
  }

  Future<void> _pickDestinationFromMap() async {
    final params = <String, String>{'title': 'Destino'};
    if (_destination?.pointOrNull case final point?) {
      params['lat'] = '${point.lat}';
      params['lon'] = '${point.lon}';
    }
    final point = await context.push<JourneyPoint>(
      Uri(path: '/journey/pick', queryParameters: params).toString(),
    );
    if (point != null && mounted) {
      String? address;
      try {
        final result = await ref.read(
          reverseGeocodeProvider(LatLng(point.lat, point.lon)).future,
        );
        address = result?.shortFormatted;
      } catch (_) {}
      setState(() {
        _destination = JourneyPlacePoint(
          lat: point.lat,
          lon: point.lon,
          address: address,
        );
        _destinationCtrl.text = _destinationLabel(_destination!);
      });
    }
  }

  void _setDestinationFromPoi(SantaCruzPoi poi) {
    setState(() {
      _destination = JourneyPlacePoi(
        name: poi.name,
        lat: poi.lat,
        lon: poi.lon,
        subtitle: poi.ringOrZone,
      );
      _destinationCtrl.text = poi.name;
      _destinationFocus.unfocus();
    });
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
    String? originAddress;
    try {
      final result = await ref.read(
        reverseGeocodeProvider(LatLng(trip.originLat, trip.originLon)).future,
      );
      originAddress = result?.shortFormatted;
    } catch (_) {}
    setState(() {
      _origin = JourneyPlaceLocation(
        lat: trip.originLat,
        lon: trip.originLon,
        address: originAddress,
      );
      _destination = JourneyPlacePoi(
        name: trip.destinationLabel,
        lat: trip.destinationLat,
        lon: trip.destinationLon,
        subtitle: trip.destinationSubtitle,
      );
      _destinationCtrl.text = _destinationLabel(_destination!);
    });
    // Auto-plan and navigate
    await _planAndClose();
  }

  Future<void> _deleteSavedTrip(SavedTrip trip) async {
    await ref.read(savedTripsControllerProvider.notifier).remove(trip);
    if (mounted) setState(() {});
  }

  Future<void> _useHistoryDestination(TripHistoryEntry entry) async {
    String? originAddress;
    final lastKnown = ref.read(lastKnownLocationProvider);
    if (lastKnown != null) {
      try {
        final result = await ref.read(
          reverseGeocodeProvider(
            LatLng(lastKnown.latitude, lastKnown.longitude),
          ).future,
        );
        originAddress = result?.shortFormatted;
      } catch (_) {}
    }
    setState(() {
      _destination = JourneyPlacePoi(
        name: entry.label,
        lat: entry.lat,
        lon: entry.lon,
        subtitle: entry.subtitle,
      );
      _destinationCtrl.text = entry.label;
      // Try to use last known location as origin
      if (lastKnown != null && _origin == null) {
        _origin = JourneyPlaceLocation(
          lat: lastKnown.latitude,
          lon: lastKnown.longitude,
          address: originAddress,
        );
      }
    });
    // Auto-plan and navigate if we have both origin and destination
    if (_origin != null) {
      await _planAndClose();
    }
  }
}

class _OriginField extends StatefulWidget {
  const _OriginField({
    required this.place,
    required this.onMapTap,
    required this.colors,
    required this.text,
  });

  final JourneyPlace? place;
  final VoidCallback onMapTap;
  final ColorScheme colors;
  final TextTheme text;

  @override
  State<_OriginField> createState() => _OriginFieldState();
}

class _OriginFieldState extends State<_OriginField> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(text: _labelFor(widget.place));
  }

  @override
  void didUpdateWidget(_OriginField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final label = _labelFor(widget.place);
    if (_controller.text != label) {
      _controller.text = label;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFieldTap() {
    _focusNode.requestFocus();
  }

  String _labelFor(JourneyPlace? place) {
    if (place == null) return '';
    return switch (place) {
      JourneyPlacePoi(:final name) => name,
      JourneyPlacePoint(:final address, :final lat, :final lon) =>
        address ?? '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
      JourneyPlaceLocation(:final address, :final lat, :final lon) =>
        address ??
            'Mi ubicación (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})',
    };
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.colors.primary.withValues(alpha: 0.08);
    final borderColor = widget.colors.primary.withValues(alpha: 0.3);
    final iconColor = widget.colors.primary;

    return InkWell(
      onTap: _onFieldTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.colors.primary.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Icon(
                Icons.my_location_rounded,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Punto de partida',
                    style: widget.text.labelSmall?.copyWith(
                      color: widget.colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Escribe un lugar',
                      hintStyle: widget.text.bodyMedium?.copyWith(
                        color: widget.colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isCollapsed: true,
                    ),
                    style: widget.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: widget.colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: widget.onMapTap,
              style: TextButton.styleFrom(
                foregroundColor: widget.colors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Mapa',
                style: widget.text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.colors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationField extends ConsumerStatefulWidget {
  const _DestinationField({
    required this.controller,
    required this.focusNode,
    required this.place,
    required this.onMapTap,
    required this.onPlaceTap,
    required this.colors,
    required this.text,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final JourneyPlace? place;
  final VoidCallback onMapTap;
  final void Function(SantaCruzPoi) onPlaceTap;
  final ColorScheme colors;
  final TextTheme text;

  @override
  ConsumerState<_DestinationField> createState() => _DestinationFieldState();
}

class _DestinationFieldState extends ConsumerState<_DestinationField> {
  String _filter = '';
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final newFilter = widget.controller.text.trim().toLowerCase();
    if (newFilter != _filter) {
      setState(() => _filter = newFilter);
      _showSuggestions();
    }
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeOverlay);
    } else {
      _showSuggestions();
    }
  }

  void _showSuggestions() {
    if (!widget.focusNode.hasFocus) return;
    _removeOverlay();

    final places = kSantaCruzPopularPlaces
        .where((poi) {
          if (_filter.isEmpty) return true;
          return poi.name.toLowerCase().contains(_filter) ||
              poi.category.toLowerCase().contains(_filter) ||
              (poi.ringOrZone?.toLowerCase().contains(_filter) ?? false);
        })
        .take(5)
        .toList();

    if (places.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: widget.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(
                color: widget.colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: places.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: widget.colors.outlineVariant.withValues(alpha: 0.5),
              ),
              itemBuilder: (ctx, i) {
                final poi = places[i];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      poi.icon,
                      size: 18,
                      color: widget.colors.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    poi.name,
                    style: widget.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    poi.ringOrZone != null
                        ? '${poi.category} · ${poi.ringOrZone}'
                        : poi.category,
                    style: widget.text.bodySmall?.copyWith(
                      color: widget.colors.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    widget.onPlaceTap(poi);
                    _removeOverlay();
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final text = widget.text;

    return InkWell(
      onTap: widget.onMapTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Icon(Icons.place_rounded, size: 20, color: colors.primary),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Destino',
                    style: text.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    decoration: InputDecoration(
                      hintText: 'Escribe un lugar o toca "Mapa"',
                      hintStyle: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isCollapsed: true,
                    ),
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: widget.onMapTap,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Mapa',
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedTripTile extends StatelessWidget {
  const _SavedTripTile({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onDelete,
    required this.colors,
    required this.text,
  });

  final SavedTrip trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ColorScheme colors;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final fill = AppColors.tint(colors.primary, colors.surface, 0.12);
    final trailing = trip.durationMinutes != null && trip.durationMinutes! > 0
        ? '${trip.durationMinutes} min'
        : _timeAgo(trip.lastUsed);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trip.originLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trip.destinationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(
              trailing,
              style: text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Eliminar viaje',
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final days = DateTime.now().difference(dt).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'ayer';
    return 'hace $days d';
  }
}

class _HistoryDestinationTile extends StatelessWidget {
  const _HistoryDestinationTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.colors,
    required this.text,
  });

  final TripHistoryEntry entry;
  final VoidCallback onTap;
  final ColorScheme colors;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final fill = AppColors.tint(colors.primary, colors.surface, 0.12);
    final trailing = entry.durationMinutes != null && entry.durationMinutes! > 0
        ? '${entry.durationMinutes} min'
        : _timeAgo(entry.lastUsed);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: Icon(Icons.place_rounded, size: 18, color: colors.primary),
            ),
            const SizedBox(width: AppSpace.sm),
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
                      color: colors.onSurface,
                    ),
                  ),
                  if (entry.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(
              trailing,
              style: text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final days = DateTime.now().difference(dt).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return 'ayer';
    return 'hace $days d';
  }
}
