import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/deep_link/incoming_link_source.dart';
import '../../../../core/deep_link/map_link_resolver.dart';
import '../../../../core/location/reverse_geocoding.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/location.dart';
import '../../application/incoming_destination.dart';
import '../../application/journey_place_factory.dart';
import '../../domain/journey_place.dart';
import 'journey_destination_sheet.dart';

/// Recibe las ubicaciones que llegan de otras apps (tocar una ubicación en
/// WhatsApp, compartir un lugar desde Google Maps, un enlace `urbano://`) y
/// abre la hoja «¿A dónde vas?» con ese destino puesto y el origen en «Mi
/// ubicación»: al usuario solo le queda tocar «Planificar viaje».
///
/// Vive en el `builder` de `MaterialApp` (encima del `Navigator`, debajo del
/// `ScaffoldMessenger`) y pregunta por enlaces pendientes al montarse y cada
/// vez que la app vuelve a primer plano — que es justo lo que pasa cuando
/// Android la trae desde WhatsApp. La decisión (leer, validar el área, poner
/// nombre) es pura y vive en [resolveIncomingDestination].
class IncomingDestinationGate extends ConsumerStatefulWidget {
  const IncomingDestinationGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncomingDestinationGate> createState() =>
      _IncomingDestinationGateState();
}

class _IncomingDestinationGateState
    extends ConsumerState<IncomingDestinationGate> {
  late final AppLifecycleListener _lifecycle;
  bool _busy = false;

  /// Cuánto se espera la dirección de un punto sin nombre antes de abrir la
  /// hoja con «Ubicación compartida».
  static const _describeBudget = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkPending);
    // Post-frame: abrir la hoja necesita el `Navigator` ya montado.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPending());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _checkPending() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final raw = await ref.read(incomingLinkSourceProvider).takePending();
      if (raw == null || !mounted) return;
      final outcome = await resolveIncomingDestination(
        raw,
        resolver: ref.read(mapLinkResolverProvider),
        describe: (location) async {
          final result = await ref
              .read(
                reverseGeocodeProvider(LatLng(location.lat, location.lon))
                    .future,
              )
              .timeout(_describeBudget);
          return result?.shortFormatted;
        },
      );
      if (!mounted) return;
      switch (outcome) {
        case IncomingDestinationReady(:final destination):
          await _openSheet(destination);
        case IncomingDestinationOutOfArea():
          _tell(
            'Esa ubicación está fuera de Santa Cruz: Urbano solo planifica '
            'viajes en micro dentro de la ciudad.',
          );
        case IncomingDestinationUnreadable():
          _tell('No encontré una ubicación en lo que compartiste.');
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _openSheet(JourneyPlace destination) async {
    final router = ref.read(appRouterProvider)..go('/');
    // Un frame para que Inicio quede al frente antes de subir la hoja.
    await WidgetsBinding.instance.endOfFrame;
    final navigatorContext = router.routerDelegate.navigatorKey.currentContext;
    if (!mounted || navigatorContext == null || !navigatorContext.mounted) {
      return;
    }
    // Si ya había una hoja o un diálogo abierto, el enlace nuevo lo reemplaza.
    Navigator.of(navigatorContext).popUntil((route) => route is PageRoute);

    final lastKnown = ref.read(lastKnownLocationProvider);
    await showJourneyDestinationSheet(
      context: navigatorContext,
      ref: ref,
      initialOrigin: lastKnown == null
          ? null
          : JourneyPlaceFactory.here(
              lat: lastKnown.latitude,
              lon: lastKnown.longitude,
            ),
      initialDestination: destination,
    );
  }

  void _tell(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
