import 'package:material_ui/material_ui.dart';

/// Tipografía de Urbano.
///
/// Todo corre en **Inter**, la cara más cercana a SF Pro que traemos
/// empaquetada: se ve "de iPhone" sin cambiar de herramienta. La singularidad
/// de marca queda en el wordmark (`wordmark`) y en los títulos destacados
/// (`display`/`headline`) que usan **Outfit** para dar carácter geométrico
/// moderno a los encabezados. Las dos familias se declaran en `pubspec.yaml`
/// bajo `flutter.fonts`, así que la app las resuelve por `fontFamily` sin
/// `google_fonts` ni descargas de red.
class AppTypography {
  AppTypography._();

  /// Familia Inter, empaquetada en pesos 400..800 (ver `pubspec.yaml`).
  static const String _inter = 'Inter';

  /// Outfit, para wordmark y títulos destacados (400..800 empaquetados).
  static const String _wordmarkFamily = 'Outfit';

  static const FontWeight display = FontWeight.w800;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight semiBold = FontWeight.w600;

  /// Aplica Inter (apretado, con jerarquía de pesos) sobre [base].
  ///
  /// Los títulos display/headline usan Outfit para dar carácter geométrico
  /// moderno; el cuerpo y labels usan Inter para legibilidad.
  static TextTheme apply(TextTheme base) {
    // `copyWith` con `letterSpacing: null` conserva el del estilo base, igual que
    // hacía `GoogleFonts.inter`; solo se fuerza cuando el rol lo pide.
    TextStyle heading(
      TextStyle? style, {
      FontWeight weight = bold,
      double? letterSpacing,
      double? height,
      String? fontFamily,
    }) => (style ?? const TextStyle()).copyWith(
      fontFamily: fontFamily ?? _inter,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );

    return base.copyWith(
      // Display y headline usan Outfit para carácter geométrico moderno.
      displayLarge: heading(
        base.displayLarge,
        weight: display,
        letterSpacing: -1.4,
        height: 1.05,
        fontFamily: _wordmarkFamily,
      ),
      displayMedium: heading(
        base.displayMedium,
        weight: display,
        letterSpacing: -0.9,
        height: 1.08,
        fontFamily: _wordmarkFamily,
      ),
      displaySmall: heading(
        base.displaySmall,
        weight: display,
        letterSpacing: -0.6,
        height: 1.1,
        fontFamily: _wordmarkFamily,
      ),
      headlineLarge: heading(
        base.headlineLarge,
        weight: display,
        letterSpacing: -0.5,
        height: 1.15,
        fontFamily: _wordmarkFamily,
      ),
      headlineMedium: heading(
        base.headlineMedium,
        weight: display,
        letterSpacing: -0.4,
        height: 1.15,
        fontFamily: _wordmarkFamily,
      ),
      headlineSmall: heading(
        base.headlineSmall,
        weight: display,
        letterSpacing: -0.3,
        height: 1.2,
        fontFamily: _wordmarkFamily,
      ),
      // Title usa Inter con mejor legibilidad.
      titleLarge: heading(
        base.titleLarge,
        weight: display,
        letterSpacing: -0.1,
        height: 1.25,
      ),
      titleMedium: heading(base.titleMedium, letterSpacing: -0.05),
      titleSmall: heading(base.titleSmall),
      // Body con mejor line-height para lectura cómoda.
      bodyLarge: base.bodyLarge?.copyWith(fontFamily: _inter, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(fontFamily: _inter, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(fontFamily: _inter, height: 1.4),
      // Labels con mejor jerarquía visual.
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: _inter,
        fontWeight: semiBold,
        letterSpacing: 0.1,
        height: 1.3,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: _inter,
        fontWeight: semiBold,
        height: 1.3,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: _inter,
        fontWeight: semiBold,
        height: 1.3,
      ),
    );
  }

  /// El logotipo «Urbano»: Outfit Bold apretado (la misma familia de los
  /// títulos, así la marca habla como el resto de la app). El bicolor
  /// «Urb» + «ano» lo arma `HomeWordmark`.
  static TextStyle wordmark(TextStyle? style) =>
      (style ?? const TextStyle()).copyWith(
        fontFamily: _wordmarkFamily,
        fontWeight: bold,
        letterSpacing: -0.6,
      );
}
