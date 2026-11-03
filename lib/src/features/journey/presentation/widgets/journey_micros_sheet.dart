import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animation/motion.dart';
import '../../../routes/data/route_models.dart';
import '../../application/micros_panel_controller.dart';
import 'micros_panel.dart';

/// Panel de **micros**: un cajón que se desliza de izquierda a derecha sobre
/// el mapa (no un bottom sheet). Lista **todas** las líneas del sistema con
/// buscador; cada línea es una tarjeta con su insignia y dos botones
/// independientes —**Ida** y **Vuelta**— que dibujan/borran ese recorrido
/// sobre el mapa.
///
/// El trabajo hecho aquí **persiste** mientras la app esté abierta: búsqueda,
/// scroll, listado descargado y headsign consultados viven en
/// [journeyMicrosSessionProvider] (y el resto del estado de trabajo en
/// [microsPanelProvider]), así que cerrar y reabrir el panel devuelve
/// exactamente el mismo estado (y abre al instante, sin volver a pagar
/// `/routes`). Para refrescar el catálogo hay "jalar para actualizar".
///
/// Este archivo es solo la PUERTA de entrada (catálogo + ruta); el cajón y sus
/// secciones viven en `micros_panel.dart` y sus widgets.
Future<void> showJourneyMicrosPanel(
  BuildContext context, {
  required WidgetRef ref,
  required Future<void> Function(RouteSummary micro, int directionId)
  onToggleDirection,
  required VoidCallback onClearAll,
  void Function(List<({double lat, double lon})> points)? onFramePlaces,
}) async {
  // Abre sesión (borrador de lugares y toggles que quedaron en vuelo) y
  // descarga el catálogo si aún no está: con el listado ya en la sesión no se
  // toca la red.
  final panel = ref.read(microsPanelProvider.notifier)..startSession();
  await panel.ensureCatalog();

  if (!context.mounted) return;

  await Navigator.of(context).push(
    _microsPanelRoute(
      onToggleDirection: onToggleDirection,
      onClearAll: onClearAll,
      onFramePlaces: onFramePlaces,
    ),
  );
}

/// Ruta del cajón: transparente, descartable por el scrim y con entrada desde
/// la izquierda. Se identifica por [RouteSettings.name] para que la pantalla
/// Viaje saque cualquier panel viejo antes de abrir uno nuevo (reabrir «Ver
/// todas» con el cajón a medio cerrar nunca debe apilar dos paneles).
PageRouteBuilder<void> _microsPanelRoute({
  required Future<void> Function(RouteSummary micro, int directionId)
  onToggleDirection,
  required VoidCallback onClearAll,
  void Function(List<({double lat, double lon})> points)? onFramePlaces,
}) => PageRouteBuilder<void>(
  opaque: false,
  barrierDismissible: true,
  barrierLabel: 'Cerrar panel de micros',
  settings: const RouteSettings(name: 'journey-micros-panel'),
  barrierColor: Colors.black.withValues(alpha: 0.45),
  transitionDuration: const Duration(milliseconds: 280),
  reverseTransitionDuration: Motion.release,
  // El panel es chrome de la app (es una RUTA montada en el `Overlay` del
  // Navigator, fuera del mapa): se pinta siempre con el tema de la app, el
  // mismo que ve el resto de la pantalla Viaje.
  pageBuilder: (_, _, _) => MicrosPanel(
    onToggleDirection: onToggleDirection,
    onClearAll: onClearAll,
    onFramePlaces: onFramePlaces,
  ),
  // Entrada desde la izquierda: el panel se desliza hacia adentro mientras el
  // scrim (barrera oscura) se funde con la misma curva.
  transitionsBuilder: (_, animation, _, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // Entra deslizándose desde la izquierda y con un leve crecimiento
    // (0.94 → 1) anclado al borde izquierdo: se "despliega" sobre el mapa.
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: ScaleTransition(
        alignment: Alignment.centerLeft,
        scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
        child: child,
      ),
    );
  },
);
