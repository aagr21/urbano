import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/map/map.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../data/journey_models.dart';
import '../../data/journey_repository.dart';
import 'journey_map_complete_pill.dart';
import 'journey_map_controls.dart';
import 'journey_result_map.dart';

/// Centro del mapa cuando todavía no hay GPS ni punto elegido.
const santaCruzCenter = LatLng(-17.7833, -63.1821);

/// Convierte una coordenada del motor en el punto record del planeador.
JourneyPoint pointOf(LatLng point) =>
    (lat: point.latitude, lon: point.longitude);

/// El mapa con la **ubicación en vivo**.
///
/// Es un `Consumer` aparte por rendimiento: [locationControllerProvider] emite
/// una posición en CADA tick de GPS. Mirado desde el `build` de
/// [_JourneyPlannerScreenState] reconstruía la pantalla entera (panel, chips,
/// hoja de resultados y su `LayoutBuilder`) cuando lo único que cambia es el
/// centro de la cámara. Aquí un tick solo reconstruye [JourneyResultMap].
///
/// La lógica de siempre se conserva tal cual: el origen es SIEMPRE el punto
/// marcado por el usuario y solo si no hay ninguno se usa «mi ubicación» (con
/// Santa Cruz de respaldo); el seguimiento se aplica cuando la intención
/// ([followLocationProvider]) coincide con permiso y GPS activos (`ready`), así
/// que si el sistema apaga la ubicación el mapa deja de seguir y vuelve solo al
/// reactivarse.
class LiveMapLayer extends ConsumerWidget {
  const LiveMapLayer({
    super.key,
    required this.mapKey,
    required this.option,
    required this.origin,
    required this.destination,
    required this.hasResults,
    required this.fitPadding,
    required this.extraPolylines,
    required this.extraMarkers,
    required this.onEndpointMoved,
    required this.onEndpointTapped,
    this.onPositionChanged,
  });

  /// El `GlobalKey` del mapa lo posee el `State` de la pantalla (desde ahí se
  /// llaman `zoomIn`/`zoomOut`), por eso viaja como prop y no como `key`.
  final GlobalKey<JourneyResultMapState> mapKey;
  final JourneyOption option;

  /// Extremos ya resueltos por el planeador; `null` = todavía sin marcar.
  final JourneyPoint? origin;
  final JourneyPoint? destination;
  final bool hasResults;
  final EdgeInsets fitPadding;
  final List<MapPolyline> extraPolylines;
  final List<MapMarker> extraMarkers;
  final void Function(bool isOrigin, LatLng point) onEndpointMoved;
  final void Function(bool isOrigin) onEndpointTapped;
  final MapPositionChangedCallback? onPositionChanged;

  /// Mueve LA CÁMARA hacia la posición en vivo (seguimiento propio).
  ///
  /// Zoom: si la vista ya está a nivel calle se conserva; si está lejos
  /// (vista de barrio/ciudad) sube a 16 para que el punto sea útil al momento.
  void _followTo(GlobalKey<JourneyResultMapState> mapKey, LatLng? point) {
    final map = mapKey.currentState;
    if (point == null || map == null) return;
    final zoom = map.currentZoom < 15.5 ? 16.0 : null;
    map.moveTo(point, zoom: zoom);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Última posición conocida: NUNCA se vacía. Es la que dibuja el punto
    // cuando el puck nativo se apaga, así que al mover el mapa tu ubicación no
    // desaparece esperando un fix nuevo ([myLocationProvider], que tarda
    // segundos en fijar).
    final me =
        ref.watch(lastKnownLocationProvider) ??
        ref.watch(myLocationProvider).valueOrNull;
    final locationReady =
        ref.watch(locationControllerProvider).status == LocationStatus.ready;
    final tracking = ref.watch(followLocationProvider) && locationReady;
    // Dueño ÚNICO del GPS: con seguimiento activo el stream propio
    // ([myLocationRealtimeProvider]) es la fuente fresca y manda sobre la
    // semilla; sin seguimiento queda la última posición conocida.
    final livePoint = tracking
        ? ref.watch(myLocationRealtimeProvider).valueOrNull
        : null;
    final shownPoint = livePoint ?? me;
    final initialCenter = shownPoint ?? santaCruzCenter;
    final mapOrigin = origin ?? pointOf(initialCenter);

    // Cámara en el seguimiento: la app la mueve con cada tick del stream.
    // Callback en lugar de watch: mover cámara NO debe reconstruir la capa.
    ref.listen(myLocationRealtimeProvider, (_, next) {
      if (!ref.read(followLocationProvider)) return;
      final point = next.valueOrNull;
      if (point != null) _followTo(mapKey, point);
    });

    // Al empezar o DEJAR de seguir (gesto en el mapa o botón): la semilla
    // de "dónde estás" es la caché del sistema (instantánea). Al empezar
    // además ABORDAMOS la cámara hacia el punto: el follow ya no es nativo,
    // es la app quien mueve el mapa con cada tick del stream propio.
    ref.listen(followLocationProvider, (previous, next) {
      if (previous == next) return;
      ref.read(lastKnownLocationProvider.notifier).refreshFromSystem();
      if (previous == true && next == false) {
        ref.invalidate(myLocationProvider);
      }
      if (next && previous == false) {
        _followTo(mapKey, ref.read(myLocationRealtimeProvider).valueOrNull);
      }
    });

    // El punto propio «mi ubicación» es EL punto, siempre que se sepa dónde
    // estás (dibujado AL TIPO DE LA APP, con seguimiento y sin él): el puck
    // nativo de MapLibre NO se usa más — pide su propio GPS continuo y le
    // robaba BATERÍA y control a la capa [LocationService]. La AURA pulsante
    // no es marcador: viaja en [extraPulses] (la pintan los motores en capas
    // nativas, véase [MapPulse]) para no re-rasterizar.
    final markers = [
      ...extraMarkers,
      if (locationReady && shownPoint != null)
        MapMarker(
          id: 'my-location-last',
          point: shownPoint,
          width: 22,
          height: 22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.primary,
              border: Border.all(color: context.colors.surface, width: 3),
            ),
          ),
        ),
    ];
    final pulses = [
      if (locationReady && shownPoint != null)
        MapPulse(point: shownPoint, color: context.colors.primary),
    ];

    return JourneyResultMap(
      key: mapKey,
      option: option,
      origin: mapOrigin,
      // Sin destino marcado el mapa encuadra sobre el origen (criterio previo).
      destination: destination ?? mapOrigin,
      showControls: false,
      showLegend: false,
      showJourneyLayers: hasResults,
      // En modo exploración se pintan los extremos que el usuario YA fijó: lo
      // que se marca en el selector debe verse antes de planificar.
      showOrigin: hasResults || origin != null,
      showDestination: hasResults || destination != null,
      fitPadding: fitPadding,
      extraPolylines: extraPolylines,
      onOriginMoved: (point) => onEndpointMoved(true, point),
      onDestinationMoved: (point) => onEndpointMoved(false, point),
      // Tocar el pin de origen/destino lo edita: abre el selector encima del
      // punto actual.
      onOriginTap: () => onEndpointTapped(true),
      onDestinationTap: () => onEndpointTapped(false),
      onPositionChanged: onPositionChanged,
      // GPS DE UN SOLO DUEÑO: MapLibre NUNCA pide ubicación nativa (`false`
      // es el default de la fachada; el comentario lo documenta a propósito):
      // su capa enciende un GPS continuo de alta precisión sin control
      // nuestro. Toda la señal —puntual, caché del sistema y stream— sale de
      // [LocationService] (geolocator) y el punto propio la dibuja; la cámara
      // del seguimiento la mueve la app (véase `ref.listen` arriba).
      extraPulses: pulses,
      extraMarkers: markers,
      onTrackingDismissed: () =>
          ref.read(followLocationProvider.notifier).state = false,
    );
  }
}

/// Controles del mapa. Se aíslan por el mismo motivo: lo único que depende del
/// GPS es si el seguimiento está ACTIVO (para pintar el botón encendido).
class LiveMapControls extends ConsumerWidget {
  const LiveMapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onOpenMicros,
    required this.microsActive,
    required this.fullscreen,
    required this.onToggleFullscreen,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final Future<void> Function() onOpenMicros;
  final bool microsActive;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking =
        ref.watch(followLocationProvider) &&
        ref.watch(locationControllerProvider).status == LocationStatus.ready;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // La píldora explícita «Mapa completo»: descubrir el modo full-screen
        // era cazarse con el botoncito de la columna; el rótulo lo nombra.
        if (!fullscreen) MapCompletePill(onTap: onToggleFullscreen),
        const SizedBox(width: 10),
        JourneyMapControls(
          onZoomIn: onZoomIn,
          onZoomOut: onZoomOut,
          onOpenMicros: onOpenMicros,
          microsActive: microsActive,
          tracking: tracking,
          onFollowChanged: (value) =>
              ref.read(followLocationProvider.notifier).state = value,
          fullscreen: fullscreen,
          onToggleFullscreen: onToggleFullscreen,
        ),
      ],
    );
  }
}
