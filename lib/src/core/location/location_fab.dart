import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animation/motion.dart';
import '../theme/app_theme.dart';
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
  });

  /// `true` si la cámara está siguiendo al usuario.
  final bool following;
  final ValueChanged<bool> onFollowChanged;
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
    // Botón circular del MISMO diámetro que el resto de la columna de
    // controles del mapa ([AppControl.mapButton]) — antes era un
    // `FloatingActionButton.small` (40 px, ícono 24) y se veía distinto al
    // lado de los zoom. La superficie elevada + borde también son la misma
    // familia; el relleno (primary/error) es su señal de estado.
    return PressScale(
      scale: 0.92,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: foreground.withValues(alpha: 0.35)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          width: AppControl.mapButton,
          height: AppControl.mapButton,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _onPressed(location),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Tooltip(
                    message: tooltip,
                    child: Icon(icon, size: 20, color: foreground),
                  ),
                  if (error)
                    Positioned(
                      right: 3,
                      bottom: 3,
                      // El punto rojo aparece justo cuando el GPS se apaga o se
                      // bloquea el permiso: entra con un pequeño rebote para que
                      // el cambio de estado se note sin tener que leer el icono
                      // (mismo lenguaje que el punto del botón de micros).
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
            ),
          ),
        ),
      ),
    );
  }
}
