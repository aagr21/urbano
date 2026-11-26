import 'package:latlong2/latlong.dart';

import '../data/journey_models.dart';

/// Geometría de una opción de viaje para el mapa, sin colores ni widgets:
/// qué puntos encuadrar y por dónde van las caminatas (explícitas, de
/// compatibilidad y de transbordo). El estilo vive en `journey_map_layers`.
abstract final class JourneyMapGeometry {
  /// Distancia (m) por debajo de la cual el fin de un micro y el inicio del
  /// siguiente se consideran el mismo punto (no hay hueco que dibujar).
  static const double transferGapMinMeters = 1;

  /// Separación máxima (m) entre el extremo de una caminata y el trazado del
  /// micro para coserlos. Más allá, el hueco es real y no se inventa un salto.
  static const double walkJoinMaxMeters = 60;

  static const _distance = Distance();

  /// Todos los puntos que el encuadre debe abarcar: pines, paradas y trazos.
  static List<LatLng> fitPoints(
    JourneyOption option,
    LatLng origin,
    LatLng destination,
  ) => [
    origin,
    destination,
    ?option.walkToStop?.position,
    ?option.walkFromStop?.position,
    for (final stop in option.stopRefs) ?stop.position,
    for (final leg in option.legs) ...?leg.mapPoints,
  ];

  /// Trazos punteados de caminata de la opción, ya cosidos al micro vecino:
  /// - con tramos a pie explícitos: su geometría por calle (OTP) o, si falta,
  ///   la recta entre extremos conocidos ([straightWalkSegment]);
  /// - sin ellos (compatibilidad): origen → subida y bajada → destino;
  /// - más los transbordos sin tramo a pie ([transferConnectors]).
  static List<List<LatLng>> walkPaths(
    JourneyOption option,
    LatLng origin,
    LatLng destination,
  ) {
    final legs = option.legs;
    final paths = <List<LatLng>>[];
    if (option.walkLegs.isEmpty) {
      final walkTo = option.walkToStop?.position;
      if (walkTo != null) {
        paths.add(joinWalkToBus([origin, walkTo], legs, -1));
      }
      final walkFrom = option.walkFromStop?.position;
      if (walkFrom != null) {
        paths.add(joinWalkToBus([walkFrom, destination], legs, legs.length));
      }
    } else {
      for (var i = 0; i < legs.length; i++) {
        final leg = legs[i];
        if (!leg.isWalk) continue;
        final geometry = leg.geometry;
        final base = (geometry != null && geometry.length >= 2)
            ? geometry
            : straightWalkSegment(option, legs, i, origin, destination);
        if (base == null || base.length < 2) continue;
        paths.add(joinWalkToBus(base, legs, i));
      }
    }
    return [...paths, ...transferConnectors(legs)];
  }

  /// Caminatas implícitas de los transbordos: para cada par de micros
  /// CONSECUTIVOS sin un tramo a pie explícito entre ellos, la línea
  /// fin-del-primero → parada de transbordo → inicio-del-segundo. Cada
  /// `shape` se recorta proyectando la parada sobre su propia línea, así que
  /// entre ambos quedaba un hueco sin dibujar.
  static List<List<LatLng>> transferConnectors(List<JourneyLeg> legs) {
    final connectors = <List<LatLng>>[];
    JourneyLeg? prevBus;
    for (final leg in legs) {
      if (leg.isWalk) {
        prevBus = null;
        continue;
      }
      if (!leg.isBus) continue;
      final previous = prevBus;
      prevBus = leg;
      if (previous == null) continue;

      final end = previous.mapPoints?.last ?? previous.toStop?.position;
      final start = leg.mapPoints?.first ?? leg.fromStop?.position;
      if (end == null || start == null) continue;
      final stop = previous.toStop?.position ?? leg.fromStop?.position;
      final points = <LatLng>[end];
      if (stop != null &&
          _distance(stop, end) >= transferGapMinMeters &&
          _distance(stop, start) >= transferGapMinMeters) {
        points.add(stop);
      }
      points.add(start);
      if (points.length == 2 && _distance(end, start) < transferGapMinMeters) {
        continue;
      }
      connectors.add(points);
    }
    return connectors;
  }

  /// Estira la caminata hasta el trazado del micro vecino.
  ///
  /// El `shape` de GTFS circula por el eje de la calzada y la parada está en
  /// la acera: en una avenida de doble calzada quedan 10-20 m entre el final
  /// de la caminata y el dibujo del micro, y se lee como "me hace cruzar la
  /// avenida". El trazado del micro **no se mueve** (es la verdad de por
  /// dónde pasa); lo que se estira es la caminata.
  ///
  /// [index] es la posición de la caminata en [legs]; `-1` y `legs.length`
  /// sirven para las caminatas de compatibilidad (sin tramo explícito).
  static List<LatLng> joinWalkToBus(
    List<LatLng> points,
    List<JourneyLeg> legs,
    int index,
  ) {
    if (points.length < 2) return points;
    final joined = List<LatLng>.of(points);
    for (var j = index + 1; j < legs.length; j++) {
      if (!legs[j].isBus) continue;
      final start = legs[j].mapPoints?.first;
      if (start != null && _distance(joined.last, start) <= walkJoinMaxMeters) {
        joined[joined.length - 1] = start;
      }
      break;
    }
    for (var j = index - 1; j >= 0; j--) {
      if (!legs[j].isBus) continue;
      final end = legs[j].mapPoints?.last;
      if (end != null && _distance(joined.first, end) <= walkJoinMaxMeters) {
        joined[0] = end;
      }
      break;
    }
    return joined;
  }

  /// Extremos de una caminata sin geometría:
  /// - acceso (antes del primer micro): pin origen → parada de subida;
  /// - egreso (después del último micro): parada de bajada → pin destino;
  /// - transferencia a pie: bajada del micro anterior → subida del siguiente
  ///   (o, sin paradas, los extremos de los trazados: nunca queda un hueco).
  static List<LatLng>? straightWalkSegment(
    JourneyOption option,
    List<JourneyLeg> legs,
    int index,
    LatLng origin,
    LatLng destination,
  ) {
    final leg = legs[index];
    JourneyLeg? prevBus;
    for (var j = index - 1; j >= 0; j--) {
      if (legs[j].isBus) {
        prevBus = legs[j];
        break;
      }
    }
    JourneyLeg? nextBus;
    for (var j = index + 1; j < legs.length; j++) {
      if (legs[j].isBus) {
        nextBus = legs[j];
        break;
      }
    }

    final LatLng? start;
    final LatLng? end;
    if (prevBus == null) {
      start = origin;
      end =
          nextBus?.fromStop?.position ??
          option.walkToStop?.position ??
          leg.toStop?.position;
    } else if (nextBus == null) {
      start =
          prevBus.toStop?.position ??
          option.walkFromStop?.position ??
          leg.fromStop?.position;
      end = destination;
    } else {
      start =
          prevBus.toStop?.position ??
          leg.fromStop?.position ??
          prevBus.mapPoints?.last;
      end =
          nextBus.fromStop?.position ??
          leg.toStop?.position ??
          nextBus.mapPoints?.first;
    }
    if (start == null || end == null) return null;
    return [start, end];
  }
}
