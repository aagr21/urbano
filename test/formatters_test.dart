import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/theme/app_colors.dart';
import 'package:urbano/src/core/utils/time_formatters.dart';

import 'helpers/contrast.dart';

void main() {
  group('GtfsTime', () {
    test('toHm recorta los segundos', () {
      expect(GtfsTime.toHm('06:07:18'), '06:07');
      expect(GtfsTime.toHm('22:00:00'), '22:00');
      expect(GtfsTime.toHm('09:05:59'), '09:05');
    });

    test('toHm con fallback para nulos/inválidos', () {
      expect(GtfsTime.toHm(null), GtfsTime.empty);
      expect(GtfsTime.toHm(''), GtfsTime.empty);
      expect(GtfsTime.toHm('basura'), GtfsTime.empty);
    });

    test('soporta horas GTFS > 24 (día siguiente)', () {
      expect(GtfsTime.toHm('25:00:00'), '25:00');
      expect(GtfsTime.toMinutes('25:00:00'), 1500);
    });

    test('toMinutes', () {
      expect(GtfsTime.toMinutes('06:00:00'), 360);
      expect(GtfsTime.toMinutes('00:00:00'), 0);
      expect(GtfsTime.toMinutes('06:07:18'), 367);
      expect(GtfsTime.toMinutes(null), isNull);
    });

    test('diffMinutes', () {
      expect(GtfsTime.diffMinutes('06:00:00', '06:38:00'), 38);
      expect(GtfsTime.diffMinutes(null, '06:00:00'), isNull);
    });

    test('range', () {
      expect(GtfsTime.range('06:00:00', '22:00:00'), '06:00 – 22:00');
      expect(GtfsTime.range(null, null), '--:-- – --:--');
    });
  });

  group('Fmt', () {
    test('distance en metros y kilómetros', () {
      expect(Fmt.distance(0), '0 m');
      expect(Fmt.distance(80), '80 m');
      expect(Fmt.distance(123.4), '123 m');
      expect(Fmt.distance(999), '999 m');
      expect(Fmt.distance(1500), '1,5 km');
      expect(Fmt.distance(null), '—');
    });

    test('duration en minutos y horas', () {
      expect(Fmt.duration(0), '0 min');
      expect(Fmt.duration(38), '38 min');
      expect(Fmt.duration(59), '59 min');
      expect(Fmt.duration(60), '1 h');
      expect(Fmt.duration(65), '1 h 05 min');
      expect(Fmt.duration(120), '2 h');
      expect(Fmt.duration(null), '—');
    });

    test('headway en segundos', () {
      expect(Fmt.headway(300), 'cada 5 min');
      expect(Fmt.headway(60), 'cada min');
      expect(Fmt.headway(0), '—');
      expect(Fmt.headway(null), '—');
    });

    test('number con separador es-BO', () {
      expect(Fmt.number(31461), '31.461');
      expect(Fmt.number(154), '154');
      expect(Fmt.number(null), '—');
    });

    test('greeting según la hora', () {
      expect(Fmt.greeting(DateTime(2026, 10, 14, 8)), 'Buenos días');
      expect(Fmt.greeting(DateTime(2026, 10, 14, 15)), 'Buenas tardes');
      expect(Fmt.greeting(DateTime(2026, 10, 14, 21)), 'Buenas noches');
    });
  });

  group('AppColors', () {
    test('fromHex parsea hex GTFS con y sin #', () {
      expect(AppColors.fromHex('D35400').toARGB32(), 0xFFD35400);
      expect(AppColors.fromHex('#0284C7').toARGB32(), 0xFF0284C7);
      expect(AppColors.fromHex('F5A').toARGB32(), 0xFFFF55AA);
      expect(AppColors.fromHex(null).toARGB32(), 0xFF64748B);
      expect(AppColors.fromHex('zzz').toARGB32(), 0xFF64748B);
    });

    test('onColor elige texto legible', () {
      // Sobre gris medio, el blanco GTFS pasa el contraste mínimo (3:1).
      expect(
        AppColors.onColor(
          const Color(0xFF7F8C8D),
          preferred: const Color(0xFFFFFFFF),
        ).toARGB32(),
        0xFFFFFFFF,
      );
      // Sobre ámbar, negro tiene mejor contraste que blanco.
      expect(AppColors.onColor(const Color(0xFFF59E0B)), Colors.black);
      expect(AppColors.onColor(const Color(0xFF075985)), Colors.white);
    });

    test('legible adapta el tinte al fondo que tiene detrás', () {
      // Línea casi negra del GTFS (`2C3E50`) sobre la superficie de grafito del
      // tema oscuro: letra oscura sobre fondo oscuro, así que hay que aclararla.
      const nearBlack = Color(0xFF2C3E50);
      final onDark = AppColors.legible(nearBlack, AppColors.surfaceDark);
      expect(
        colorContrast(onDark, AppColors.surfaceDark),
        greaterThanOrEqualTo(4.5),
      );
      // Sobre una superficie clara ese mismo tinte ya es legible: se respeta
      // intacto (no se toca lo que ya funciona).
      expect(AppColors.legible(nearBlack, AppColors.surfaceLight), nearBlack);
      // Y un amarillo brillante se OSCURECE sobre fondo claro: la otra mitad de
      // la misma regla (nada de letras claras sobre claras).
      const amber = Color(0xFFF1C40F);
      final onLight = AppColors.legible(amber, AppColors.surfaceLight);
      expect(onLight.computeLuminance(), lessThan(amber.computeLuminance()));
      expect(
        colorContrast(onLight, AppColors.surfaceLight),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
