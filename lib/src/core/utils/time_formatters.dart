/// Formateadores de tiempo GTFS (`HH:mm:ss`, permitido `> 24:00:00`).
class GtfsTime {
  GtfsTime._();

  static const String empty = '--:--';

  /// `06:07:18` → `6` h `7` min (minutos desde medianoche).
  ///
  /// Soporta horas > 24 (día siguiente en GTFS): `25:00:00` → 1500.
  static int? toMinutes(String? value) {
    final parts = _parts(value);
    if (parts == null) return null;
    return parts.$1 * 60 + parts.$2;
  }

  /// `06:07:18` → `06:07`.
  static String toHm(String? value, {String fallback = empty}) {
    final parts = _parts(value);
    if (parts == null) return fallback;
    return '${parts.$1.toString().padLeft(2, '0')}:'
        '${parts.$2.toString().padLeft(2, '0')}';
  }

  static (int, int)? _parts(String? value) => parseHm(value);

  /// Parser público de `HH:mm[:ss]` de la app (luego del selector de hora
  /// `HH:mm`: `parseHm('08:30')` → `(8, 30)`; malformado → `null`).
  static (int, int)? parseHm(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final split = value.trim().split(':');
    if (split.length < 2) return null;
    final hour = int.tryParse(split[0]);
    final minute = int.tryParse(split[1]);
    if (hour == null || minute == null) return null;
    return (hour, minute);
  }

  /// `(8, 30)` → `08:30` (el formato del [TimeOfDay] selector spindle-hour).
  static String formatHm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Formateadores de presentación (distancias, duraciones, números).
class Fmt {
  Fmt._();

  /// `123.4` → `123 m`; `1500` → `1,5 km`.
  static String distance(double? meters) {
    if (meters == null) return '—';
    if (meters < 1000) return '${meters.round()} m';
    final km = (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');
    return '$km km';
  }

  /// `38` → `38 min`; `65` → `1 h 05 min`; `120` → `2 h`.
  static String duration(int? minutes) {
    if (minutes == null) return '—';
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h h';
    return '$h h ${m.toString().padLeft(2, '0')} min';
  }
}
