import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animation/motion.dart';
import '../utils/extensions.dart';
import 'location_controller.dart';

/// FAB de ubicación con **estados reales** del sistema.
///
/// | Estado | Icono | Color |
/// | --- | --- | --- |
/// | Servicio (GPS) apagado | `location_off` + punto rojo | error |
/// | Permiso pendiente | `my_location` | primario relleno |
/// | Permiso bloqueado | `gps_off` + punto rojo | error |
/// | Listo (seguir o no) | `my_location` | primario relleno |
///
/// El FAB es **constante** cuando la ubicación está disponible: siempre azul
/// y siempre con el mismo icono, aunque el usuario pulse y la cámara deje de
/// seguir. El feedback de "estoy siguiendo" lo dan el mapa y la cámara, no el
/// botón. Los estados rojos (GPS apagado / permiso bloqueado) sí cambian.
///
/// El estado cambia **solo** si el usuario apaga/enciende el GPS (stream del
/// sistema) o revoca el permiso (al reanudar la app). Al tocar:
///
/// - `ready` → alterna el seguimiento vía [onFollowChanged].
/// - cualquier otro → ejecuta el flujo de [LocationController.activate]
///   (diálogos de "Abrir ajustes" / "Abrir ajustes de la app") y, si quedó
///   activo, empieza a seguir la ubicación.
class LocationFab extends ConsumerStatefulWidget {
  const LocationFab({
    super.key,
    required this.following,
    required this.onFollowChanged,
    this.heroTag = 'location-fab',
  });

  /// `true` si la cámara está siguiendo al usuario.
  final bool following;
  final ValueChanged<bool> onFollowChanged;
  final Object heroTag;
  @override
  ConsumerState<LocationFab> createState() => _LocationFabState();
}

class _LocationFabState extends ConsumerState<LocationFab>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El usuario pudo cambiar permisos o el GPS en ajustes mientras la app
    // estaba en segundo plano: re-consultamos al reanudar.
    if (state == AppLifecycleState.resumed) {
      ref.read(locationControllerProvider.notifier).checkPermission();
    }
  }

  Future<void> _onPressed(LocationState location) async {
    if (location.status == LocationStatus.ready) {
      widget.onFollowChanged(!widget.following);
      return;
    }
    final granted = await ref
        .read(locationControllerProvider.notifier)
        .activate(context);
    if (granted) widget.onFollowChanged(true);
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationControllerProvider);
    final colors = context.colors;
    final IconData icon;
    final String tooltip;
    final bool error;
    switch (location.status) {
      case LocationStatus.serviceOff:
        icon = Icons.location_off_rounded;
        tooltip =
            'La ubicación de tu teléfono está apagada · toca para activarla';
        error = true;
      case LocationStatus.permissionBlocked:
        icon = Icons.gps_off_rounded;
        tooltip = 'Permiso de ubicación bloqueado · toca para abrir ajustes';
        error = true;
      case LocationStatus.permissionPending:
        icon = Icons.my_location_rounded;
        tooltip = 'Usar mi ubicación';
        error = false;
      case LocationStatus.ready:
        icon = Icons.my_location_rounded;
        tooltip = widget.following
            ? 'Dejar de seguir mi ubicación'
            : 'Seguir mi ubicación';
        error = false;
    }
    final background = error ? colors.error : colors.primary;
    final foreground = error ? colors.onError : colors.onPrimary;
    return FloatingActionButton.small(
      heroTag: widget.heroTag,
      tooltip: tooltip,
      backgroundColor: background,
      foregroundColor: foreground,
      onPressed: () => _onPressed(location),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          if (error)
            Positioned(
              right: 0,
              bottom: 0,
              // El punto rojo aparece justo cuando el GPS se apaga o se bloquea
              // el permiso: entra con un pequeño rebote para que el cambio de
              // estado se note sin tener que leer el icono (mismo lenguaje que
              // el punto del botón de micros).
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.2, end: 1),
                duration: Motion.transition,
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: colors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
