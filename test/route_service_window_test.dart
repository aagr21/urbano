import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/routes/data/route_facts.dart';
import 'package:urbano/src/features/routes/data/route_models.dart';
import 'package:urbano/src/features/routes/presentation/widgets/route_detail_hero.dart';
import 'package:urbano/src/features/routes/presentation/widgets/route_direction_picker.dart';

DateTime _at(int hour, int minute) => DateTime(2026, 11, 24, hour, minute);

RouteDirection _dir(int id, String headsign) => RouteDirection(
  directionId: id,
  headsign: headsign,
  tripId: 't$id',
  firstDeparture: '06:00:00',
  lastDeparture: '22:00:00',
  headwaySeconds: 600,
  stopCount: 40,
);

RouteDetail _detail(List<RouteDirection> directions) => RouteDetail(
  id: '101',
  shortName: '101',
  longName: 'Angostura · El Mechero',
  color: '0F766E',
  textColor: 'FFFFFF',
  description: '',
  type: 3,
  directionsCount: directions.length,
  stopCount: 80,
  tripCount: 2,
  bbox: const [],
  directions: directions,
  shape: null,
);

void main() {
  group('ServiceWindow', () {
    test('sin horas o con horas invertidas no hay ventana', () {
      expect(ServiceWindow.from(null, '22:00:00'), isNull);
      expect(ServiceWindow.from('22:00:00', '06:00:00'), isNull);
    });

    test('fases del día en un servicio 06:00–22:00', () {
      final w = ServiceWindow.from('06:00:00', '22:00:00')!;
      expect(w.phaseAt(_at(5, 59)), ServicePhase.beforeStart);
      expect(w.phaseAt(_at(6, 0)), ServicePhase.running);
      expect(w.phaseAt(_at(22, 0)), ServicePhase.running);
      expect(w.phaseAt(_at(22, 1)), ServicePhase.ended);
      expect(w.spanLabel, '16 h de servicio');
    });

    test('un servicio que cruza la medianoche sigue vivo de madrugada', () {
      final w = ServiceWindow.from('05:30:00', '25:10:00')!;
      expect(w.endLabel, '01:10');
      expect(w.phaseAt(_at(0, 30)), ServicePhase.running);
      expect(w.phaseAt(_at(2, 0)), ServicePhase.beforeStart);
      expect(w.phaseAt(_at(23, 50)), ServicePhase.running);
    });

    test('la cabecera lo dice en lenguaje de pasajero', () {
      final d = _dir(0, 'Centro');
      expect(
        RouteDetailHero.statusLabel(d, _at(12, 0)),
        'En servicio hasta las 22:00',
      );
      expect(
        RouteDetailHero.statusLabel(d, _at(4, 0)),
        'Todavía no sale · primer micro a las 06:00',
      );
      expect(
        RouteDetailHero.statusLabel(d, _at(23, 0)),
        'Ya no pasa hoy · vuelve a las 06:00',
      );
    });
  });

  group('directionEndpoints', () {
    test('desde = headsign del sentido contrario, hasta = el propio', () {
      final detail = _detail([_dir(0, 'Centro'), _dir(1, 'El Mechero')]);
      expect(directionEndpoints(detail, 0), ('El Mechero', 'Centro'));
      expect(directionEndpoints(detail, 1), ('Centro', 'El Mechero'));
    });

    test('headsigns genéricos o un solo sentido no inventan extremos', () {
      expect(
        directionEndpoints(_detail([_dir(0, 'Ida'), _dir(1, 'Vuelta')]), 0),
        isNull,
      );
      expect(directionEndpoints(_detail([_dir(0, 'Centro')]), 0), isNull);
    });
  });
}
