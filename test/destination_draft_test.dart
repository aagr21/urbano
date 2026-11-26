import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/journey/domain/destination_draft.dart';
import 'package:urbano/src/features/journey/domain/journey_place.dart';

/// Política de la hoja «¿A dónde vas?», sin widgets: cada gesto es una
/// transición pura de [DestinationDraft].
void main() {
  const plaza = JourneyPlacePoi(
    name: 'Plaza 24 de Septiembre',
    lat: -17.7838,
    lon: -63.1821,
    subtitle: 'Casco viejo',
  );
  const mall = JourneyPlacePoi(name: 'Ventura Mall', lat: -17.76, lon: -63.19);

  group('arranque y GPS', () {
    test('sin origen arranca ubicando; con origen, no', () {
      expect(DestinationDraft.initial().locating, isTrue);
      expect(DestinationDraft.initial(origin: plaza).locating, isFalse);
    });

    test('el fix fija «Mi ubicación» como origen', () {
      final d = DestinationDraft.initial().gpsResolved(
        lat: -17.78,
        lon: -63.18,
      );
      expect(d.origin, isA<JourneyPlaceLocation>());
      expect(d.originQuery, 'Mi ubicación');
      expect(d.originTag, 'GPS');
      expect(d.locating, isFalse);
      expect(d.gpsOrigin, isNotNull);
    });

    test('un fix tardío NO pisa el origen que el usuario ya eligió', () {
      final d = DestinationDraft.initial()
          .picked(plaza, isOrigin: true)
          .gpsResolved(lat: -17.78, lon: -63.18);
      expect(d.origin, same(plaza));
      expect(d.gpsOrigin, isNotNull, reason: 'queda para «Mi ubicación»');
      expect(d.originIsGpsAt(lat: -17.78, lon: -63.18), isFalse);
    });

    test('sin ubicación el subtítulo lo explica', () {
      final d = DestinationDraft.initial().gpsUnavailable();
      expect(d.locating, isFalse);
      expect(d.originSubtitle, 'Activa tu ubicación o elige en el mapa');
    });

    test('la dirección solo se anota si el origen sigue siendo ese punto', () {
      final gps = DestinationDraft.initial().gpsResolved(
        lat: -17.78,
        lon: -63.18,
      );
      final enriched = gps.addressResolved(
        lat: -17.78,
        lon: -63.18,
        address: 'Calle Libertad',
      );
      expect(
        (enriched.origin! as JourneyPlaceLocation).address,
        'Calle Libertad',
      );
      expect(
        enriched.originQuery,
        'Mi ubicación',
        reason: 'el campo no cambia',
      );

      final moved = gps
          .picked(plaza, isOrigin: true)
          .addressResolved(lat: -17.78, lon: -63.18, address: 'Calle Libertad');
      expect(moved.origin, same(plaza));
    });
  });

  group('escribir y elegir', () {
    test('escribir otra cosa vacía el extremo hasta elegir', () {
      final d = DestinationDraft.initial(destination: plaza)
          .destinationTyped('Plaza 24');
      expect(d.destination, isNull);
      expect(d.destinationQuery, 'Plaza 24');
      expect(d.canPlan, isFalse);
    });

    test('escribir exactamente el nombre conserva el lugar', () {
      final d = DestinationDraft.initial(destination: plaza)
          .destinationTyped('Plaza 24 de Septiembre');
      expect(d.destination, same(plaza));
    });

    test('escribir en el origen lo marca como del usuario', () {
      final d = DestinationDraft.initial().originTyped('x');
      expect(d.originTouched, isTrue);
    });

    test('elegir repone el texto del campo y habilita planificar', () {
      final d = DestinationDraft.initial()
          .picked(mall, isOrigin: true)
          .picked(plaza, isOrigin: false);
      expect(d.originQuery, 'Ventura Mall');
      expect(d.destinationQuery, 'Plaza 24 de Septiembre');
      expect(d.canPlan, isTrue);
    });

    test('«Mi ubicación» vuelve con el último fix', () {
      final d = DestinationDraft.initial()
          .gpsResolved(lat: -17.78, lon: -63.18)
          .picked(plaza, isOrigin: true)
          .usedGps();
      expect(d.origin, isA<JourneyPlaceLocation>());
      expect(d.originTouched, isFalse);
    });

    test('«Mi ubicación» sin fix no hace nada', () {
      final d = DestinationDraft.initial(origin: plaza);
      expect(d.usedGps(), same(d));
    });

    test(
      'wantsGps solo con fix y con texto que es prefijo de «mi ubicación»',
      () {
        final sinFix = DestinationDraft.initial();
        expect(sinFix.wantsGps('mi ub'), isFalse);
        final conFix = sinFix.gpsResolved(lat: -17.78, lon: -63.18);
        expect(conFix.wantsGps('Mi Ub'), isTrue);
        expect(conFix.wantsGps('   '), isFalse);
        expect(conFix.wantsGps('plaza'), isFalse);
      },
    );
  });

  group('invertir y recientes', () {
    test('invertir cruza lugares y textos', () {
      final d = DestinationDraft.initial(
        origin: mall,
        destination: plaza,
      ).swapped();
      expect(d.origin, same(plaza));
      expect(d.destination, same(mall));
      expect(d.originQuery, 'Plaza 24 de Septiembre');
      expect(d.destinationQuery, 'Ventura Mall');
      expect(d.originTouched, isTrue);
    });

    test('invertir con el GPS volviendo arriba lo deja como no tocado', () {
      final d = DestinationDraft.initial(destination: plaza)
          .gpsResolved(lat: -17.78, lon: -63.18)
          .swapped()
          .swapped();
      expect(d.origin, isA<JourneyPlaceLocation>());
      expect(d.originTouched, isFalse);
    });

    test('un viaje guardado repone los dos extremos', () {
      final d = DestinationDraft.initial().tripLoaded(
        origin: mall,
        destination: plaza,
      );
      expect(d.canPlan, isTrue);
      expect(d.locating, isFalse);
    });

    test('el historial usa la última posición solo si falta origen', () {
      const here = JourneyPlaceLocation(lat: -17.7, lon: -63.1);
      final sinOrigen = DestinationDraft.initial().historyLoaded(
        destination: plaza,
        lastKnown: here,
      );
      expect(sinOrigen.origin, same(here));
      expect(sinOrigen.canPlan, isTrue);

      final conOrigen = DestinationDraft.initial(origin: mall)
          .historyLoaded(destination: plaza, lastKnown: here);
      expect(conOrigen.origin, same(mall));
    });
  });

  group('textos', () {
    test('la ubicación del teléfono siempre se llama «Mi ubicación»', () {
      const located = JourneyPlaceLocation(
        lat: 1,
        lon: 2,
        address: 'Calle Libertad',
      );
      expect(DestinationDraft.fieldText(located), 'Mi ubicación');
      expect(DestinationDraft.fieldText(null), '');
      expect(
        DestinationDraft.fieldText(const JourneyPlacePoint(lat: 1, lon: 2)),
        'Punto en el mapa',
      );
    });

    test('un destino «ubicación» muestra su dirección', () {
      const located = JourneyPlaceLocation(
        lat: 1,
        lon: 2,
        address: 'Calle Libertad',
      );
      final d = DestinationDraft.initial(destination: located);
      expect(d.destinationLabel, 'Calle Libertad');
      expect(d.destinationSubtitle, 'Usando la ubicación de tu teléfono');
    });

    test('subtítulo del origen: hito con y sin contexto', () {
      expect(
        DestinationDraft.initial(origin: plaza).originSubtitle,
        'Casco viejo',
      );
      expect(
        DestinationDraft.initial(origin: mall).originSubtitle,
        'Lugar elegido',
      );
    });
  });
}
