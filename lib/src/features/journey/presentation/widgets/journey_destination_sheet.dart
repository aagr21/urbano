import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/location/reverse_geocoding.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart' show AppRadius, AppSpace;
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../application/journey_planner_controller.dart';
import '../../application/journey_providers.dart';
import '../../application/saved_trips_controller.dart';
import '../../application/trip_history_controller.dart';
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
  final TextEditingController _originCtrl = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final TextEditingController _destinationCtrl = TextEditingController();
  final FocusNode _destinationFocus = FocusNode();
  int _recentPage = 0;
  static const int _recentPageSize = 5;

  @override
  void initState() {
    super.initState();
    // Default origin = Mi ubicación (last known or request GPS)
    _origin = widget.initialOrigin;
    _destination = widget.initialDestination;
    if (_origin != null) {
      _originCtrl.text = _destinationLabel(_origin!);
    }
    if (_destination != null) {
      _destinationCtrl.text = _destinationLabel(_destination!);
    }
    _ensureOriginLocation();
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _originFocus.dispose();
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
              // Header como sheet.html: píldora de ubicación + título con logo
              const DestinationSheetHeader(),
              const SizedBox(height: AppSpace.md),
              // Tarjeta blanca con campos de origen y destino
              _buildPlannerCard(context),
              if (savedTrips.isNotEmpty || history.isNotEmpty)
                ...() {
                  final unified = buildUnifiedRecentList(
                    savedTrips: savedTrips,
                    history: history,
                  );
                  final totalPages = (unified.length / _recentPageSize).ceil();
                  final pageItems = unified
                      .skip(_recentPage * _recentPageSize)
                      .take(_recentPageSize)
                      .toList();

                  return [
                    const SizedBox(height: AppSpace.lg),
                    // Encabezado de sección de destinos recientes
                    _buildRecentHeader(context, text),
                    const SizedBox(height: AppSpace.sm),
                    // Lista unificada paginada (5 por página)
                    ..._buildUnifiedRecentTiles(pageItems),
                    if (totalPages > 1) ...[
                      const SizedBox(height: AppSpace.sm),
                      _buildPagination(context, text, totalPages),
                    ],
                  ];
                }(),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta blanca con campos de origen/destino y botón de planificar.
  Widget _buildPlannerCard(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark ? HtmlDesignTokens.slate800 : HtmlDesignTokens.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: dark ? AppColors.lineDark : HtmlDesignTokens.slate200,
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.2)
                : HtmlDesignTokens.slate900.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Contenedor gris con campos
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark
                    ? HtmlDesignTokens.slate900
                    : HtmlDesignTokens.slate50,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: dark ? AppColors.lineDark : HtmlDesignTokens.slate200,
                  width: 0.8,
                ),
              ),
              child: Column(
                children: [
                  // Campo de origen
                  JourneyEndpointField(
                    label: 'Origen',
                    place: _origin,
                    icon: Icons.my_location_rounded,
                    iconBg: HtmlDesignTokens.emerald100,
                    iconInk: HtmlDesignTokens.emerald600,
                    labelInk: HtmlDesignTokens.emerald700,
                    subtitleInk: HtmlDesignTokens.emerald500,
                    mapButtonBg: HtmlDesignTokens.white,
                    mapButtonInk: HtmlDesignTokens.emerald700,
                    mapButtonBorder: HtmlDesignTokens.emerald200,
                    controller: _originCtrl,
                    focusNode: _originFocus,
                    hintText: '¿Dónde estás?',
                    onTap: () {
                      _originFocus.requestFocus();
                      _originCtrl.selection = TextSelection.collapsed(
                        offset: _originCtrl.text.length,
                      );
                    },
                    onMapTap: () => _pickOriginFromMap(),
                  ),
                  // Separador con botón swap
                  JourneySwapDivider(onSwap: _swapEndpoints),
                  // Campo de destino
                  JourneyEndpointField(
                    label: 'Destino',
                    place: _destination,
                    icon: Icons.location_on_rounded,
                    iconBg: HtmlDesignTokens.rose50,
                    iconInk: HtmlDesignTokens.rose500,
                    labelInk: HtmlDesignTokens.roseRed,
                    subtitleInk: HtmlDesignTokens.rose400,
                    mapButtonBg: HtmlDesignTokens.white,
                    mapButtonInk: HtmlDesignTokens.roseRed,
                    mapButtonBorder: HtmlDesignTokens.rose300,
                    controller: _destinationCtrl,
                    focusNode: _destinationFocus,
                    hintText: '¿A dónde vas?',
                    onTap: () {
                      _destinationFocus.requestFocus();
                      _destinationCtrl.selection = TextSelection.collapsed(
                        offset: _destinationCtrl.text.length,
                      );
                    },
                    onMapTap: () => _pickDestinationFromMap(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Botón de planificar — degradado esmeralda
            JourneyPlanButton(
              enabled: _canPlan(),
              onPressed: _canPlan() ? () => _planAndClose() : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Header de sección de destinos recientes.
  Widget _buildRecentHeader(BuildContext context, TextTheme text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: HtmlDesignTokens.teal500.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(
            Icons.history_rounded,
            size: 14,
            color: HtmlDesignTokens.teal600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Tus destinos recientes',
          style: text.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: HtmlDesignTokens.slate800,
          ),
        ),
      ],
    );
  }

  void _swapEndpoints() {
    final tempPlace = _origin;
    final tempText = _originCtrl.text;
    setState(() {
      _origin = _destination;
      _destination = tempPlace;
      _originCtrl.text = _destinationCtrl.text;
      _destinationCtrl.text = tempText;
    });
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
    final place = await pickEndpointFromMap(
      context: context,
      ref: ref,
      title: 'Origen',
      currentPoint: _origin?.pointOrNull,
    );
    if (place != null && mounted) {
      setState(() {
        _origin = place;
        _originCtrl.text = _destinationLabel(_origin!);
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
        _destinationCtrl.text = _destinationLabel(_destination!);
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
    final canGoPrev = _recentPage > 0;
    final canGoNext = _recentPage < totalPages - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Flecha anterior
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
              color: canGoPrev
                  ? HtmlDesignTokens.emerald600
                  : HtmlDesignTokens.slate300,
              size: 28,
            ),
            tooltip: 'Página anterior',
          ),
        ),
        // Indicador de página "1 / 3"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${_recentPage + 1} / $totalPages',
            style: text.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: HtmlDesignTokens.emerald700,
            ),
          ),
        ),
        // Flecha siguiente
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
              color: canGoNext
                  ? HtmlDesignTokens.emerald600
                  : HtmlDesignTokens.slate300,
              size: 28,
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
