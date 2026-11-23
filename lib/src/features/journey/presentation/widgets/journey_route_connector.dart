import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart' show AppRadius, AppSpace;
import '../../../../core/utils/extensions.dart';
import '../../data/popular_places.dart';
import '../../domain/journey_place.dart';

/// Contenedor visual que une origen y destino con campos de texto.
///
/// Muestra dos campos (origen y destino) con íconos diferenciados y un botón
/// "Mapa" para seleccionar el punto en el mapa. El campo de destino muestra
/// sugerencias de lugares populares de Santa Cruz al escribir.
class JourneyRouteConnector extends ConsumerStatefulWidget {
  const JourneyRouteConnector({
    super.key,
    required this.originPlace,
    required this.destinationPlace,
    required this.destinationCtrl,
    required this.destinationFocus,
    required this.onOriginMapTap,
    required this.onDestinationMapTap,
    required this.onPlaceTap,
  });

  final JourneyPlace? originPlace;
  final JourneyPlace? destinationPlace;
  final TextEditingController destinationCtrl;
  final FocusNode destinationFocus;
  final VoidCallback onOriginMapTap;
  final VoidCallback onDestinationMapTap;
  final void Function(SantaCruzPoi) onPlaceTap;

  @override
  ConsumerState<JourneyRouteConnector> createState() =>
      _JourneyRouteConnectorState();
}

class _JourneyRouteConnectorState extends ConsumerState<JourneyRouteConnector> {
  late final FocusNode _originFocus;
  late final TextEditingController _originCtrl;
  String _destFilter = '';
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _originFocus = FocusNode();
    _originCtrl = TextEditingController(text: _originLabel(widget.originPlace));
    widget.destinationCtrl.addListener(_onDestTextChanged);
    widget.destinationFocus.addListener(_onDestFocusChanged);
  }

  @override
  void didUpdateWidget(JourneyRouteConnector oldWidget) {
    super.didUpdateWidget(oldWidget);
    final label = _originLabel(widget.originPlace);
    if (_originCtrl.text != label) {
      _originCtrl.text = label;
    }
  }

  @override
  void dispose() {
    _originFocus.dispose();
    _originCtrl.dispose();
    widget.destinationCtrl.removeListener(_onDestTextChanged);
    widget.destinationFocus.removeListener(_onDestFocusChanged);
    _removeOverlay();
    super.dispose();
  }

  String _originLabel(JourneyPlace? place) {
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

  void _onDestTextChanged() {
    final newFilter = widget.destinationCtrl.text.trim().toLowerCase();
    if (newFilter != _destFilter) {
      setState(() => _destFilter = newFilter);
      _showSuggestions();
    }
  }

  void _onDestFocusChanged() {
    if (!widget.destinationFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeOverlay);
    } else {
      _showSuggestions();
    }
  }

  void _showSuggestions() {
    if (!widget.destinationFocus.hasFocus) return;
    _removeOverlay();

    final places = kSantaCruzPopularPlaces
        .where((poi) {
          if (_destFilter.isEmpty) return true;
          return poi.name.toLowerCase().contains(_destFilter) ||
              poi.category.toLowerCase().contains(_destFilter) ||
              (poi.ringOrZone?.toLowerCase().contains(_destFilter) ?? false);
        })
        .take(5)
        .toList();

    if (places.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => _DestinationSuggestionsOverlay(
        places: places,
        offset: offset,
        size: size,
        onPlaceTap: (poi) {
          widget.onPlaceTap(poi);
          _removeOverlay();
        },
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
    final colors = context.colors;
    final text = context.text;

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Origen
          _EndpointField(
            label: 'Origen',
            accentColor: colors.primary,
            icon: Icons.my_location_rounded,
            controller: _originCtrl,
            focusNode: _originFocus,
            hintText: 'Mi ubicación',
            onMapTap: widget.onOriginMapTap,
            text: text,
          ),
          const SizedBox(height: AppSpace.xs),
          // Destino
          _EndpointField(
            label: 'Destino',
            accentColor: colors.error,
            icon: Icons.pin_drop_rounded,
            controller: widget.destinationCtrl,
            focusNode: widget.destinationFocus,
            hintText: '¿A dónde vas?',
            onMapTap: widget.onDestinationMapTap,
            text: text,
          ),
        ],
      ),
    );
  }
}

/// Campo de extremo (origen o destino) con ícono, texto y botón de mapa.
class _EndpointField extends StatelessWidget {
  const _EndpointField({
    required this.label,
    required this.accentColor,
    required this.icon,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onMapTap,
    required this.text,
  });

  final String label;
  final Color accentColor;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final VoidCallback onMapTap;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => focusNode.requestFocus(),
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: AppSpace.xs + 2,
            ),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                // Ícono de extremo
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: hintText,
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
                ),
                TextButton(
                  onPressed: onMapTap,
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_rounded, size: 14, color: accentColor),
                      const SizedBox(width: 2),
                      Text(
                        'Mapa',
                        style: text.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Overlay de sugerencias de lugares populares para el campo de destino.
class _DestinationSuggestionsOverlay extends StatelessWidget {
  const _DestinationSuggestionsOverlay({
    required this.places,
    required this.offset,
    required this.size,
    required this.onPlaceTap,
  });

  final List<SantaCruzPoi> places;
  final Offset offset;
  final Size size;
  final void Function(SantaCruzPoi) onPlaceTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Positioned(
      left: offset.dx,
      top: offset.dy + size.height + 4,
      width: size.width,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: places.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
            itemBuilder: (_, i) {
              final poi = places[i];
              return ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    poi.icon,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  poi.name,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  poi.ringOrZone != null
                      ? '${poi.category} · ${poi.ringOrZone}'
                      : poi.category,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                onTap: () => onPlaceTap(poi),
              );
            },
          ),
        ),
      ),
    );
  }
}
