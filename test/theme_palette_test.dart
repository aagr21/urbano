import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_colors.dart';
import 'package:urbano/src/core/theme/app_theme.dart';

/// Contraste WCAG entre dos colores opacos.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('paleta del tema oscuro', () {
    final scheme = AppTheme.dark().colorScheme;

    test('el primario está apagado: ya no es un verde neón', () {
      final hsl = HSLColor.fromColor(scheme.primary);
      expect(
        hsl.saturation,
        lessThan(0.55),
        reason:
            'el aqua saturado (#4FE3D0) deslumbraba en OLED; el primario '
            'oscuro debe quedarse en un verde agua sereno',
      );
      // Sigue siendo el acento vivo: legible como texto/ícono sobre el tema.
      expect(_contrast(scheme.primary, scheme.surface), greaterThan(4.5));
      expect(
        _contrast(scheme.primary, scheme.surfaceContainerLowest),
        greaterThan(4.5),
      );
    });

    test('el secundario acompaña al primario en vez de brillar más', () {
      final primary = HSLColor.fromColor(scheme.primary);
      final secondary = HSLColor.fromColor(scheme.secondary);
      expect(secondary.saturation, lessThan(0.6));
      expect(
        secondary.saturation,
        lessThanOrEqualTo(primary.saturation + 0.1),
        reason:
            'la cabecera se pinta con primary → secondary; si el segundo '
            'salta de saturación, el degradado vuelve a encender',
      );
    });

    test('el tema claro conserva el verde de marca', () {
      final light = AppTheme.light().colorScheme;
      expect(light.primary, const Color(0xFF008C7B));
    });
  });

  group('el blanco del tema oscuro', () {
    final scheme = AppTheme.dark().colorScheme;

    test('las letras son blancas y se leen sobre el grafito', () {
      // El blanco del modo oscuro entra por la tipografía: nada de texto gris
      // apagado que desaparezca sobre la tarjeta.
      expect(scheme.onSurface.computeLuminance(), greaterThan(0.8));
      expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(12));
      expect(
        _contrast(scheme.onSurface, scheme.surfaceContainerLowest),
        greaterThan(12),
      );
    });

    test('las letras secundarias no bajan del mínimo legible', () {
      expect(
        _contrast(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onSurfaceVariant, scheme.surfaceContainerLowest),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('los bordes son blanco translúcido, nunca gris', () {
      const borders = [
        AppColors.lineDark,
        AppColors.lineStrongDark,
        AppColors.outlineDark,
        AppColors.outlineVariantDark,
      ];
      for (final line in borders) {
        expect(line.r, 1, reason: 'el filete $line debe ser blanco puro');
        expect(line.g, 1);
        expect(line.b, 1);
        expect(line.a, greaterThan(0.1));
        expect(line.a, lessThanOrEqualTo(0.5));
      }
      // El borde tiene que verse sobre la tarjeta: se mide ya compuesto.
      final painted = Color.alphaBlend(AppColors.lineDark, scheme.surface);
      expect(_contrast(painted, scheme.surface), greaterThan(1.25));
    });

    test('los acentos teñidos sobre el grafito conservan su contraste', () {
      const accents = [
        AppColors.primarySoftDark,
        AppColors.accentDeep,
        AppColors.accentSoftDark,
        AppColors.categoryVehicle,
        AppColors.categoryDriver,
        AppColors.categoryDeviation,
        AppColors.categorySchedule,
        AppColors.categorySafety,
      ];
      for (final accent in accents) {
        final fill = AppColors.tint(accent, scheme.surface, 0.12);
        final ink = AppColors.legible(accent, fill);
        expect(
          _contrast(ink, fill),
          greaterThanOrEqualTo(4.5),
          reason: 'el acento $accent debe seguir legible sobre su tinte',
        );
      }
    });
  });
}
