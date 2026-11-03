import 'journey_place.dart';

/// Parámetros de una consulta al planeador.
class JourneyQuery {
  const JourneyQuery({
    required this.origin,
    required this.destination,
    this.time,
    this.maxResults = 3,
  });

  final JourneyPlace origin;
  final JourneyPlace destination;
  final String? time;
  final int maxResults;

  JourneyPoint get originPoint => origin.pointOrNull!;

  JourneyPoint get destinationPoint => destination.pointOrNull!;

  @override
  bool operator ==(Object other) =>
      other is JourneyQuery &&
      other.origin.label == origin.label &&
      other.destination.label == destination.label &&
      other.originPoint == originPoint &&
      other.destinationPoint == destinationPoint &&
      other.time == time &&
      other.maxResults == maxResults;

  @override
  int get hashCode => Object.hash(
    origin.label,
    destination.label,
    originPoint,
    destinationPoint,
    time,
    maxResults,
  );
}
