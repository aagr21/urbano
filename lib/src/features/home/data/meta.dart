/// `GET /meta` — identidad del dataset importado + invariantes del planner.
///
/// El cliente consume [version]/[publisher]/fechas para mostrarse en
/// "Acerca de" (y poder detectar cuando el backend re-importa el feed);
/// [limits] se parsea aunque la UI aún no lo use: es parte del contrato
/// (ver `docs/api-contract.md`) y congelarlo aquí evita re-pensarlo después.
class MetaInfo {
  const MetaInfo({
    required this.version,
    required this.publisher,
    required this.lang,
    required this.startDate,
    required this.endDate,
    required this.limits,
  });

  factory MetaInfo.fromJson(Map<String, dynamic> json) {
    final feed = json['feed'] is Map<String, dynamic>
        ? json['feed'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final limits = json['limits'] is Map<String, dynamic>
        ? json['limits'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return MetaInfo(
      version: feed['version'] as String? ?? '',
      publisher: feed['publisher'] as String? ?? '',
      lang: feed['lang'] as String? ?? '',
      startDate: feed['startDate'] as String? ?? '',
      endDate: feed['endDate'] as String? ?? '',
      limits: limits.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
    );
  }

  final String version;
  final String publisher;
  final String lang;

  /// Vigencia del dataset en el formato GTFS `YYYYMMDD`.
  final String startDate;
  final String endDate;

  /// Invariantes del planner (`maxResults`, `walkRadiusM`, …). El snapshot
  /// del servidor; la app no replica estos números.
  final Map<String, int> limits;

  /// `20261006` → `2026-10-06`. Vacío si el feed no declara la fecha.
  String prettyDate(String yyyymmdd) {
    if (yyyymmdd.length != 8) return yyyymmdd;
    final y = yyyymmdd.substring(0, 4);
    final m = yyyymmdd.substring(4, 6);
    final d = yyyymmdd.substring(6, 8);
    return '$y-$m-$d';
  }

  /// «v1.0 · 2026-10-06 → 2027-10-06», o «Versión no declarada» si el feed
  /// no trae `feed_version`.
  String get summary {
    final v = version.isEmpty ? 'sin versión' : 'v$version';
    if (startDate.isEmpty || endDate.isEmpty) return v;
    return '$v · ${prettyDate(startDate)} → ${prettyDate(endDate)}';
  }
}
