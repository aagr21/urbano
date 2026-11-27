import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/deep_link/map_link_resolver.dart';
import 'package:urbano/src/core/deep_link/shared_location.dart';
import 'package:urbano/src/features/journey/application/incoming_destination.dart';
import 'package:urbano/src/features/journey/domain/journey_place.dart';

class _FakeResolver implements MapLinkResolver {
  _FakeResolver(this.result);

  final String? result;
  final calls = <Uri>[];

  @override
  Future<String?> resolve(Uri shortLink) async {
    calls.add(shortLink);
    return result;
  }
}

void main() {
  group('parseSharedLocation', () {
    test('geo: de WhatsApp con nombre entre paréntesis', () {
      expect(
        parseSharedLocation(
          'geo:-17.7833,-63.1821?q=-17.7833,-63.1821(Plaza 24 de Septiembre)',
        ),
        const SharedLocation(
          lat: -17.7833,
          lon: -63.1821,
          label: 'Plaza 24 de Septiembre',
        ),
      );
    });

    test('geo:0,0 con la consulta codificada', () {
      expect(
        parseSharedLocation('geo:0,0?q=-17.79%2C-63.17(Mercado%20Los%20Pozos)'),
        const SharedLocation(
          lat: -17.79,
          lon: -63.17,
          label: 'Mercado Los Pozos',
        ),
      );
    });

    test('geo: con zoom y sin nombre', () {
      expect(
        parseSharedLocation('geo:-17.75,-63.2?z=16'),
        const SharedLocation(lat: -17.75, lon: -63.2),
      );
    });

    test('geo:0,0 con solo una dirección escrita no es una ubicación', () {
      expect(parseSharedLocation('geo:0,0?q=Calle+Junin+123'), isNull);
    });

    test('Google Maps ?q=lat,lon', () {
      expect(
        parseSharedLocation('https://maps.google.com/?q=-17.7833,-63.1821'),
        const SharedLocation(lat: -17.7833, lon: -63.1821),
      );
    });

    test('Google Maps api=1 query y destination', () {
      expect(
        parseSharedLocation(
          'https://www.google.com/maps/search/?api=1&query=-17.8,-63.15',
        ),
        const SharedLocation(lat: -17.8, lon: -63.15),
      );
      expect(
        parseSharedLocation(
          'https://www.google.com/maps/dir/?api=1&destination=-17.8,-63.15',
        ),
        const SharedLocation(lat: -17.8, lon: -63.15),
      );
    });

    test('Google Maps place: el pin !3d!4d gana a la cámara @', () {
      expect(
        parseSharedLocation(
          'https://www.google.com/maps/place/Ventura+Mall/@-17.7700,-63.1900,17z/'
          'data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d-17.7712!4d-63.1955',
        ),
        const SharedLocation(
          lat: -17.7712,
          lon: -63.1955,
          label: 'Ventura Mall',
        ),
      );
    });

    test('Google Maps solo con @ (centro de cámara)', () {
      expect(
        parseSharedLocation('https://www.google.com/maps/@-17.77,-63.19,15z'),
        const SharedLocation(lat: -17.77, lon: -63.19),
      );
    });

    test('Apple Maps, OSM y Waze', () {
      expect(
        parseSharedLocation('https://maps.apple.com/?ll=-17.78,-63.18&q=Casa'),
        const SharedLocation(lat: -17.78, lon: -63.18, label: 'Casa'),
      );
      expect(
        parseSharedLocation(
          'https://www.openstreetmap.org/?mlat=-17.78&mlon=-63.18#map=17',
        ),
        const SharedLocation(lat: -17.78, lon: -63.18),
      );
      expect(
        parseSharedLocation(
          'https://waze.com/ul?ll=-17.78,-63.18&navigate=yes',
        ),
        const SharedLocation(lat: -17.78, lon: -63.18),
      );
    });

    test('urbano://destino', () {
      expect(
        parseSharedLocation(
          'urbano://destino?lat=-17.78&lon=-63.18&nombre=Cine Center',
        ),
        const SharedLocation(lat: -17.78, lon: -63.18, label: 'Cine Center'),
      );
    });

    test('texto compartido con el enlace en medio', () {
      expect(
        parseSharedLocation(
          'Te espero acá 👉 https://maps.google.com/?q=-17.7833,-63.1821. ¡Apúrate!',
        ),
        const SharedLocation(lat: -17.7833, lon: -63.1821),
      );
    });

    test('par de coordenadas suelto', () {
      expect(
        parseSharedLocation('-17.7833, -63.1821'),
        const SharedLocation(lat: -17.7833, lon: -63.1821),
      );
    });

    test('textos sin ubicación y coordenadas imposibles', () {
      expect(parseSharedLocation(null), isNull);
      expect(parseSharedLocation('   '), isNull);
      expect(parseSharedLocation('hola, ¿cómo estás?'), isNull);
      expect(parseSharedLocation('https://example.com/?q=-17.7,-63.1'), isNull);
      expect(parseSharedLocation('geo:0,0'), isNull);
      expect(parseSharedLocation('geo:95,10'), isNull);
    });
  });

  test('findShortMapLink reconoce solo los enlaces cortos de Google Maps', () {
    expect(
      findShortMapLink('Mirá: https://maps.app.goo.gl/AbC123'),
      Uri.parse('https://maps.app.goo.gl/AbC123'),
    );
    expect(
      findShortMapLink('https://goo.gl/maps/xyz'),
      Uri.parse('https://goo.gl/maps/xyz'),
    );
    expect(findShortMapLink('https://goo.gl/otra-cosa'), isNull);
    expect(findShortMapLink('https://maps.google.com/?q=-17,-63'), isNull);
  });

  test('isInsideServiceArea: Santa Cruz sí, La Paz no', () {
    expect(
      isInsideServiceArea(const SharedLocation(lat: -17.7833, lon: -63.1821)),
      isTrue,
    );
    expect(
      isInsideServiceArea(const SharedLocation(lat: -16.5, lon: -68.15)),
      isFalse,
    );
  });

  group('resolveIncomingDestination', () {
    test('con nombre en el enlace no pide la dirección', () async {
      var described = 0;
      final outcome = await resolveIncomingDestination(
        'geo:0,0?q=-17.78,-63.18(Cine Center)',
        resolver: _FakeResolver(null),
        describe: (_) async {
          described++;
          return 'Otra cosa';
        },
      );
      expect(described, 0);
      final place = (outcome as IncomingDestinationReady).destination;
      expect(place, isA<JourneyPlacePoi>());
      expect(place.label, 'Cine Center');
      expect(place.pointOrNull, (lat: -17.78, lon: -63.18));
    });

    test('sin nombre usa la dirección inversa', () async {
      final outcome = await resolveIncomingDestination(
        'geo:-17.78,-63.18',
        resolver: _FakeResolver(null),
        describe: (_) async => 'Av. Cañoto, Centro',
      );
      expect(
        (outcome as IncomingDestinationReady).destination.label,
        'Av. Cañoto, Centro',
      );
    });

    test('sin nombre ni dirección: «Ubicación compartida»', () async {
      final outcome = await resolveIncomingDestination(
        'geo:-17.78,-63.18',
        resolver: _FakeResolver(null),
        describe: (_) async => throw Exception('sin red'),
      );
      final place = (outcome as IncomingDestinationReady).destination;
      expect(place, isA<JourneyPlacePoint>());
      expect(place.label, sharedLocationFallbackLabel);
    });

    test('enlace corto: se resuelve y se lee la URL larga', () async {
      final resolver = _FakeResolver(
        'https://www.google.com/maps/place/Plaza/@-17.78,-63.18,17z',
      );
      final outcome = await resolveIncomingDestination(
        'https://maps.app.goo.gl/AbC123',
        resolver: resolver,
      );
      expect(resolver.calls, [Uri.parse('https://maps.app.goo.gl/AbC123')]);
      expect((outcome as IncomingDestinationReady).destination.label, 'Plaza');
    });

    test('enlace corto sin red: ilegible', () async {
      final outcome = await resolveIncomingDestination(
        'https://maps.app.goo.gl/AbC123',
        resolver: _FakeResolver(null),
      );
      expect(outcome, isA<IncomingDestinationUnreadable>());
    });

    test('fuera de Santa Cruz no abre la hoja', () async {
      final outcome = await resolveIncomingDestination(
        'geo:-16.5,-68.15',
        resolver: _FakeResolver(null),
      );
      expect(outcome, isA<IncomingDestinationOutOfArea>());
    });
  });
}
