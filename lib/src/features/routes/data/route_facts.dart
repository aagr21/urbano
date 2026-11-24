import '../../../core/utils/time_formatters.dart';

/// Datos de ciudad que no cambian de línea a línea.
///
/// La tarifa oficial del transporte urbano de Santa Cruz de la Sierra se
/// repite en el catálogo de micros y en las opciones de viaje; vive aquí para
/// que no se escriba con valores distintos en cada pantalla.
const String kOfficialFareLabel = 'Bs 3.50';

/// Estado del servicio de un sentido según su primera y última salida.
enum ServicePhase {
  /// Todavía no salió el primer micro del día.
  beforeStart,

  /// Entre la primera y la última salida.
  running,

  /// Ya salió el último micro.
  ended,
}

/// Ventana de servicio de un sentido (`firstDeparture`–`lastDeparture` GTFS).
///
/// Es una lectura **de horario**, no de tiempo real: dice si a esta hora el
/// feed programa salidas, no dónde está el micro. Las horas GTFS pueden pasar
/// de `24:00:00` (servicio que cruza la medianoche) y eso se respeta.
class ServiceWindow {
  const ServiceWindow._(this.startMinutes, this.endMinutes);

  /// `null` si el feed no declara alguna de las dos horas.
  static ServiceWindow? from(String? first, String? last) {
    final start = GtfsTime.toMinutes(first);
    final end = GtfsTime.toMinutes(last);
    if (start == null || end == null || end <= start) return null;
    return ServiceWindow._(start, end);
  }

  /// Minutos desde la medianoche (pueden superar 1440).
  final int startMinutes;
  final int endMinutes;

  /// Duración del servicio en minutos.
  int get spanMinutes => endMinutes - startMinutes;

  /// Fase a la hora local [now] (la app se usa en Santa Cruz, `America/La_Paz`).
  ServicePhase phaseAt(DateTime now) {
    final minute = now.hour * 60 + now.minute;
    // Un servicio que cruza la medianoche sigue vivo de madrugada.
    if (endMinutes > 1440 && minute + 1440 <= endMinutes) {
      return ServicePhase.running;
    }
    if (minute < startMinutes) return ServicePhase.beforeStart;
    if (minute <= endMinutes) return ServicePhase.running;
    return ServicePhase.ended;
  }

  /// `06:00` / `22:00` normalizados a reloj (25:10 → 01:10).
  String get startLabel => _clock(startMinutes);
  String get endLabel => _clock(endMinutes);

  /// `16 h de servicio`, `15 h 30 min de servicio`.
  String get spanLabel => '${Fmt.duration(spanMinutes)} de servicio';

  static String _clock(int minutes) {
    final m = minutes % 1440;
    return GtfsTime.formatHm(m ~/ 60, m % 60);
  }
}
