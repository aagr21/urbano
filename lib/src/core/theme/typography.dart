import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografía de Urbano.
///
/// Todo corre en **Inter**, la cara más cercana a SF Pro que traemos
/// empaquetada: se ve "de iPhone" sin cambiar de herramienta. La singularidad
/// de marca queda en el wordmark (`wordmark`), que sí usa Plus Jakarta Sans.
/// Las fuentes viven en `assets/fonts`, así que no hay descargas en runtime.
class AppTypography {
  AppTypography._();

  static const FontWeight display = FontWeight.w800;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight semiBold = FontWeight.w600;

  /// Aplica Inter (apretado, con jerarquía de pesos) sobre [base].
  static TextTheme apply(TextTheme base) {
    TextStyle heading(
      TextStyle? style, {
      FontWeight weight = bold,
      double? letterSpacing,
    }) => GoogleFonts.inter(
      textStyle: style,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );

    return base.copyWith(
      displayLarge: heading(
        base.displayLarge,
        weight: display,
        letterSpacing: -1.4,
      ),
      displayMedium: heading(
        base.displayMedium,
        weight: display,
        letterSpacing: -0.9,
      ),
      displaySmall: heading(
        base.displaySmall,
        weight: display,
        letterSpacing: -0.6,
      ),
      headlineLarge: heading(
        base.headlineLarge,
        weight: display,
        letterSpacing: -0.5,
      ),
      headlineMedium: heading(
        base.headlineMedium,
        weight: display,
        letterSpacing: -0.4,
      ),
      headlineSmall: heading(
        base.headlineSmall,
        weight: display,
        letterSpacing: -0.3,
      ),
      titleLarge: heading(
        base.titleLarge,
        weight: display,
        letterSpacing: -0.2,
      ),
      titleMedium: heading(base.titleMedium),
      titleSmall: heading(base.titleSmall),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: semiBold,
        letterSpacing: 0.2,
      ),
      labelMedium: base.labelMedium?.copyWith(fontWeight: semiBold),
      labelSmall: base.labelSmall?.copyWith(fontWeight: semiBold),
    );
  }

  /// El logotipo "Urbano": Plus Jakarta Sans ExtraBold (la única excepción
  /// tipográfica de la app, para que la marca tenga voz propia).
  static TextStyle wordmark(TextStyle? style) => GoogleFonts.plusJakartaSans(
    textStyle: style,
    fontWeight: display,
    letterSpacing: -0.35,
  );
}
