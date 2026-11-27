import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:urbano/src/core/theme/app_colors.dart';
import 'package:urbano/src/core/theme/app_theme.dart';
import 'package:urbano/src/core/theme/html_design_tokens.dart';

/// Contraste WCAG entre dos colores opacos.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Los seis colores de la paleta oficial («Paleta de colores Urbano»).
final _palette = <Color>{
  const Color(0xFF35F04F), // Verde luminoso
  const Color(0xFF1BD64C), // Verde brillante
  const Color(0xFF06BD4A), // Verde principal
  const Color(0xFF029E46), // Verde oscuro
  const Color(0xFFFD7502), // Naranja
  const Color(0xFFFEFEFE), // Blanco
};

void main() {
  test('todo color de marca es EXACTAMENTE uno de la paleta', () {
    final light = AppTheme.light().colorScheme;
    final dark = AppTheme.dark().colorScheme;
    final brand = <String, Color>{
      'lime': AppColors.lime,
      'brightGreen': AppColors.brightGreen,
      'brand': AppColors.brand,
      'primary': AppColors.primary,
      'primaryDark': AppColors.primaryDark,
      'fieldMid': AppColors.fieldMid,
      'accent': AppColors.accent,
      'accentDeep': AppColors.accentDeep,
      'greenDeep': AppColors.greenDeep,
      'brandWhite': AppColors.brandWhite,
      'onBrand': AppColors.onBrand,
      'canvasLight': AppColors.canvasLight,
      'surfaceLight': AppColors.surfaceLight,
      'primarySoftDark': AppColors.primarySoftDark,
      'limeSoftDark': AppColors.limeSoftDark,
      'accentSoftDark': AppColors.accentSoftDark,
      'categoryVehicle': AppColors.categoryVehicle,
      'light.primary': light.primary,
      'light.secondary': light.secondary,
      'light.tertiary': light.tertiary,
      'dark.primary': dark.primary,
      'dark.secondary': dark.secondary,
      'dark.tertiary': dark.tertiary,
      'emerald500': HtmlDesignTokens.emerald500,
      'emerald600': HtmlDesignTokens.emerald600,
      'teal950': HtmlDesignTokens.teal950,
      'orange500': HtmlDesignTokens.orange500,
      'orange600': HtmlDesignTokens.orange600,
    };
    for (final MapEntry(:key, :value) in brand.entries) {
      expect(_palette, contains(value), reason: '$key = $value');
    }
    for (final color in urbanoGradient.colors) {
      expect(_palette, contains(color), reason: 'degradado: $color');
    }
  });

  group('paleta del tema oscuro', () {
    final scheme = AppTheme.dark().colorScheme;

    test('el primario es el verde principal y se lee sobre el grafito', () {
      expect(scheme.primary, AppColors.brand);
      expect(_contrast(scheme.primary, scheme.surface), greaterThan(4.5));
      expect(
        _contrast(scheme.primary, scheme.surfaceContainerLowest),
        greaterThan(4.5),
      );
    });

    test('el tema claro conserva el verde de marca', () {
      final light = AppTheme.light().colorScheme;
      expect(light.primary, AppColors.primary);
      expect(AppColors.primary, const Color(0xFF029E46));
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
