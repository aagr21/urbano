import 'package:flutter/foundation.dart' show immutable;

/// Ubicación que llegó de afuera (WhatsApp, Google Maps, un enlace
/// `urbano://`): un punto y, si el enlace lo traía, el nombre del lugar.
@immutable
class SharedLocation {
  const SharedLocation({required this.lat, required this.lon, this.label});

  final double lat;
  final double lon;

  /// Nombre que venía en el enlace (`geo:…(Nombre)`, `/maps/place/Nombre/`,
  /// `?q=Nombre` de Apple…), o `null` si solo había coordenadas.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is SharedLocation &&
      other.lat == lat &&
      other.lon == lon &&
      other.label == label;

  @override
  int get hashCode => Object.hash(lat, lon, label);

  @override
  String toString() => 'SharedLocation($lat, $lon, $label)';
}

/// Caja generosa del área metropolitana de Santa Cruz de la Sierra
/// (incluye Warnes, Cotoca, La Guardia y El Torno). Fuera de ella Urbano no
/// tiene micros: el enlace se rechaza con un aviso en vez de planificar en
/// vano.
const ({double minLat, double maxLat, double minLon, double maxLon})
sharedLocationServiceArea = (
  minLat: -18.15,
  maxLat: -17.45,
  minLon: -63.50,
  maxLon: -62.95,
);

/// `true` si el punto cae dentro de [sharedLocationServiceArea].
bool isInsideServiceArea(SharedLocation location) =>
    location.lat >= sharedLocationServiceArea.minLat &&
    location.lat <= sharedLocationServiceArea.maxLat &&
    location.lon >= sharedLocationServiceArea.minLon &&
    location.lon <= sharedLocationServiceArea.maxLon;

/// Enlace corto de Google Maps (`maps.app.goo.gl/…`, `goo.gl/maps/…`) que hay
/// que seguir por la red antes de poder leer coordenadas, o `null` si el texto
/// no trae ninguno.
Uri? findShortMapLink(String raw) {
  for (final uri in _uris(raw)) {
    final host = uri.host.toLowerCase();
    if (host == 'maps.app.goo.gl') return uri;
    if (host == 'goo.gl' && uri.path.startsWith('/maps')) return uri;
  }
  return null;
}

/// Lee una ubicación de lo que mandó otra app: una URI `geo:` (lo que dispara
/// WhatsApp al tocar una ubicación), un enlace de Google/Apple/OSM/Waze, un
/// `urbano://destino?lat=&lon=&nombre=` o un texto compartido que contenga
/// cualquiera de ellos o un par «lat, lon» suelto.
///
/// Devuelve `null` cuando no hay coordenadas legibles (por ejemplo, un enlace
/// corto todavía sin resolver o un `geo:0,0?q=Calle+X` que solo trae una
/// dirección escrita).
SharedLocation? parseSharedLocation(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  if (text.isEmpty) return null;
  // Una URI `geo:`/`urbano:` entera puede traer espacios sin codificar en el
  // nombre (`(Plaza 24)`): se lee completa antes de partir el texto.
  if (RegExp(r'^(geo:|urbano://)', caseSensitive: false).hasMatch(text)) {
    final whole = Uri.tryParse(text.replaceAll(' ', '%20'));
    final hit = whole == null ? null : _fromUri(whole);
    if (hit != null) return hit;
  }
  for (final uri in _uris(text)) {
    final hit = _fromUri(uri);
    if (hit != null) return hit;
  }
  // Par suelto («-17.7833, -63.1821») fuera de los enlaces: los números de
  // una URL desconocida no cuentan como ubicación.
  final pair = _coordPair.firstMatch(text.replaceAll(_linkInText, ' '));
  return pair == null ? null : _point(pair.group(1), pair.group(2));
}

// ── Internos ───────────────────────────────────────────────────────────────

/// Un par de coordenadas decimales separado por coma (con o sin espacio).
final _coordPair = RegExp(r'(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)');

/// Pin exacto de un lugar de Google Maps: `!3d<lat>!4d<lon>`.
final _googlePin = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)');

/// Centro de cámara de Google Maps: `/@<lat>,<lon>,17z`.
final _googleAt = RegExp(r'/@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');

/// Enlaces dentro del texto, en orden de aparición.
final _linkInText = RegExp(r'''(?:geo:|urbano://|https?://)[^\s<>"']+''');

Iterable<Uri> _uris(String text) sync* {
  for (final match in _linkInText.allMatches(text)) {
    // WhatsApp y los mensajeros suelen pegar un punto o paréntesis al final.
    final cleaned = match.group(0)!.replaceFirst(RegExp(r'[.,;!?]+$'), '');
    final uri = Uri.tryParse(cleaned);
    if (uri != null) yield uri;
  }
}

SharedLocation? _fromUri(Uri uri) => switch (uri.scheme.toLowerCase()) {
  'geo' => _fromGeo(uri),
  'urbano' => _fromUrbano(uri),
  'http' || 'https' => _fromWeb(uri),
  _ => null,
};

/// `geo:lat,lon`, `geo:lat,lon?z=16`, `geo:0,0?q=lat,lon(Nombre)`.
SharedLocation? _fromGeo(Uri uri) {
  // `Uri` no separa la consulta de una URI opaca de forma fiable en todas las
  // variantes que mandan las apps, así que se lee a mano.
  final body = uri.toString().substring('geo:'.length);
  final queryStart = body.indexOf('?');
  final path = queryStart < 0 ? body : body.substring(0, queryStart);
  final query = queryStart < 0 ? '' : body.substring(queryStart + 1);

  final q = _queryParam(query, 'q');
  if (q != null) {
    final label = _labelInParens(q);
    final pair = _coordPair.firstMatch(q);
    final fromQ = pair == null
        ? null
        : _point(pair.group(1), pair.group(2), label: label);
    if (fromQ != null) return fromQ;
  }
  // El `;u=35` (incertidumbre) y demás parámetros van tras `;`.
  final coords = path.split(';').first.split(',');
  if (coords.length < 2) return null;
  return _point(coords[0], coords[1]);
}

/// `urbano://destino?lat=-17.78&lon=-63.18&nombre=Plaza`.
SharedLocation? _fromUrbano(Uri uri) {
  final params = uri.queryParameters;
  return _point(
    params['lat'],
    params['lon'] ?? params['lng'],
    label: params['nombre'] ?? params['label'],
  );
}

SharedLocation? _fromWeb(Uri uri) {
  final host = uri.host.toLowerCase();
  final params = uri.queryParameters;

  if (host.contains('google.') || host == 'maps.google.com') {
    final full = Uri.decodeFull(uri.toString());
    final name = _googlePlaceName(uri);
    final pin = _googlePin.firstMatch(full);
    if (pin != null) {
      final hit = _point(pin.group(1), pin.group(2), label: name);
      if (hit != null) return hit;
    }
    for (final key in const ['q', 'query', 'destination', 'daddr', 'll']) {
      final value = params[key];
      final pair = value == null ? null : _coordPair.firstMatch(value);
      if (pair != null) {
        final hit = _point(pair.group(1), pair.group(2), label: name);
        if (hit != null) return hit;
      }
    }
    final at = _googleAt.firstMatch(full);
    return at == null ? null : _point(at.group(1), at.group(2), label: name);
  }

  if (host == 'maps.apple.com') {
    final label = params['q'];
    final ll = params['ll'] ?? params['sll'] ?? params['daddr'];
    final pair = _coordPair.firstMatch(ll ?? label ?? '');
    final named = label != null && !_coordPair.hasMatch(label) ? label : null;
    return pair == null
        ? null
        : _point(pair.group(1), pair.group(2), label: named);
  }

  if (host.endsWith('openstreetmap.org') || host == 'osm.org') {
    return _point(params['mlat'], params['mlon']);
  }

  if (host.endsWith('waze.com')) {
    final pair = _coordPair.firstMatch(params['ll'] ?? '');
    return pair == null ? null : _point(pair.group(1), pair.group(2));
  }

  return null;
}

/// Nombre de `/maps/place/<Nombre>/@…`, con `+` como espacio.
String? _googlePlaceName(Uri uri) {
  final segments = uri.pathSegments;
  final index = segments.indexOf('place');
  if (index < 0 || index + 1 >= segments.length) return null;
  final name = segments[index + 1].replaceAll('+', ' ').trim();
  if (name.isEmpty || _coordPair.hasMatch(name)) return null;
  return name;
}

/// Lee un parámetro de una consulta cruda, tolerando `%2C`, `+` y paréntesis
/// sin codificar (lo que de verdad mandan WhatsApp y Google Maps).
String? _queryParam(String query, String key) {
  for (final part in query.split('&')) {
    final eq = part.indexOf('=');
    if (eq < 0 || part.substring(0, eq).toLowerCase() != key) continue;
    final value = part.substring(eq + 1).replaceAll('+', ' ');
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    }
  }
  return null;
}

/// `lat,lon(Nombre del lugar)` → `Nombre del lugar`.
String? _labelInParens(String q) {
  final open = q.indexOf('(');
  final close = q.lastIndexOf(')');
  if (open < 0 || close <= open) return null;
  final label = q.substring(open + 1, close).trim();
  return label.isEmpty ? null : label;
}

SharedLocation? _point(String? latText, String? lonText, {String? label}) {
  final lat = double.tryParse(latText?.trim() ?? '');
  final lon = double.tryParse(lonText?.trim() ?? '');
  if (lat == null || lon == null) return null;
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  // `geo:0,0` es el «sin coordenadas» del estándar, no un punto en el golfo
  // de Guinea.
  if (lat == 0 && lon == 0) return null;
  final cleanLabel = label?.trim();
  return SharedLocation(
    lat: lat,
    lon: lon,
    label: cleanLabel == null || cleanLabel.isEmpty ? null : cleanLabel,
  );
}
