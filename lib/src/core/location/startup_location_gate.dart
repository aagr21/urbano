import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'location_controller.dart';

/// Puerta de arranque de la app: pide el permiso de ubicación pendiente (el
/// diálogo nativo "Mientras uses la app"; el escalado a "siempre" lo hace el
/// usuario después desde Ajustes) y activa el auto-follow si quedó concedido.
///
/// - Corre **una sola vez por sesión de app** ([_requested]), no en cada
///   rebuild ni en hot restart de widgets.
/// - Sin diálogos intrusivos: si el GPS está apagado o el permiso bloqueado,
///   NO insiste al arrancar — el flujo completo con diálogos sigue vivo en
///   `LocationController.activate` vía el botón `LocationFab`.
/// - La sincronización dinámica es gratis: [LocationController] ya escucha el
///   stream del sistema, así que encender el GPS pasa el estado a `ready` y el
///   mapa activa `myLocationEnabled`/`followMyLocation` solo.
class StartupLocationGate extends ConsumerStatefulWidget {
  const StartupLocationGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupLocationGate> createState() =>
      _StartupLocationGateState();

  /// Reinicia el guard de "ya se pidió en esta sesión" (solo tests).
  @visibleForTesting
  static void debugReset() => _requested = false;

  static bool _requested = false;
}

class _StartupLocationGateState extends ConsumerState<StartupLocationGate> {
  @override
  void initState() {
    super.initState();
    // Guard estático: sobrevive a rebuilds del MaterialApp (y evita pedir el
    // permiso dos veces si el árbol se recrea con otra key).
    if (StartupLocationGate._requested) return;
    StartupLocationGate._requested = true;
    // Post-frame: [LocationController.requestPermission] muestra el diálogo
    // nativo del sistema; necesita el árbol (Navigator) ya montado.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupFlow());
  }

  Future<void> _runStartupFlow() async {
    final controller = ref.read(locationControllerProvider.notifier);
    await controller.checkPermission();
    if (!mounted) return;

    final state = ref.read(locationControllerProvider);
    // Solo pedimos cuando el permiso está "denied" (se puede pedir). Con
    // `deniedForever` o GPS apagado no insistimos: el FAB cubre ese flujo.
    if (state.status == LocationStatus.permissionPending) {
      await controller.requestPermission();
    }
    if (!mounted) return;

    // Con permiso concedido el mapa arranca siguiendo la ubicación en vivo
    // (si el GPS está apagado, lo hará en cuanto el usuario lo encienda).
    ref.read(followLocationProvider.notifier).state = ref
        .read(locationControllerProvider)
        .hasPermission;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
