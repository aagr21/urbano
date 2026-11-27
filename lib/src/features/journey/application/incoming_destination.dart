import '../../../core/deep_link/map_link_resolver.dart';
import '../../../core/deep_link/shared_location.dart';
import '../domain/journey_place.dart';

/// Qué hacer con un enlace que otra app le pasó a Urbano.
sealed class IncomingDestination {
  const IncomingDestination();
}

/// Hay destino: se abre la hoja «¿A dónde vas?» con él puesto.
class IncomingDestinationReady extends IncomingDestination {
  const IncomingDestinationReady(this.destination);

  final JourneyPlace destination;
}

/// El punto está fuera del área metropolitana: Urbano no tiene micros ahí.
class IncomingDestinationOutOfArea extends IncomingDestination {
  const IncomingDestinationOutOfArea();
}

/// No se pudo leer una ubicación (texto cualquiera, dirección sin
/// coordenadas, enlace corto sin red).
class IncomingDestinationUnreadable extends IncomingDestination {
  const IncomingDestinationUnreadable();
}

/// Nombre del destino cuando el enlace no traía ninguno ni hubo dirección.
const String sharedLocationFallbackLabel = 'Ubicación compartida';

/// Traduce el enlace entrante a una decisión. [describe] pone nombre a un
/// punto sin etiqueta (dirección inversa); si falla o tarda, el destino se
/// llama [sharedLocationFallbackLabel] y la hoja abre igual.
Future<IncomingDestination> resolveIncomingDestination(
  String raw, {
  required MapLinkResolver resolver,
  Future<String?> Function(SharedLocation location)? describe,
}) async {
  final location = await readSharedLocation(raw, resolver);
  if (location == null) return const IncomingDestinationUnreadable();
  if (!isInsideServiceArea(location)) {
    return const IncomingDestinationOutOfArea();
  }
  var address = location.label;
  if (address == null && describe != null) {
    try {
      address = await describe(location);
    } catch (_) {
      // La dirección es un extra: el punto ya basta para planificar.
    }
  }
  return IncomingDestinationReady(sharedDestinationPlace(location, address));
}

/// El destino que ve la hoja: el nombre del enlace (o la dirección) arriba y
/// «Ubicación compartida» como contexto, para que se sepa de dónde salió.
JourneyPlace sharedDestinationPlace(SharedLocation location, String? address) {
  final name = address?.trim();
  if (name == null || name.isEmpty) {
    return JourneyPlacePoint(
      lat: location.lat,
      lon: location.lon,
      address: sharedLocationFallbackLabel,
    );
  }
  return JourneyPlacePoi(
    name: name,
    lat: location.lat,
    lon: location.lon,
    subtitle: sharedLocationFallbackLabel,
  );
}
