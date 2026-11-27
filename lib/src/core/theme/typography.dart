import 'package:material_ui/material_ui.dart';

/// Tipografía de Urbano.
///
/// Toda la app corre en **Montserrat**, la tipografía de la marca (manual de
/// identidad: Montserrat Bold para títulos y Montserrat Regular para el
/// cuerpo). Es una geométrica ancha: los títulos van apenas apretados y el
/// cuerpo con su espaciado natural para que siga leyéndose cómoda en textos
/// largos. Se declara en `pubspec.yaml` bajo `flutter.fonts`, así que la app la
/// resuelve por `fontFamily` sin `google_fonts` ni descargas de red.
class AppTypography {
  AppTypography._();

  /// Familia de la marca, empaquetada en pesos 400..800 (ver `pubspec.yaml`).
  static const String family = 'Montserrat';

  static const FontWeight display = FontWeight.w800;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight semiBold = FontWeight.w600;

  /// Aplica Montserrat (con jerarquía de pesos) sobre [base].
  ///
  /// El cuerpo y las etiquetas van con tracking 0: Material 3 les suma
  /// 0,25–0,5 px pensando en Roboto, y Montserrat ya es ancha de por sí.
  static TextTheme apply(TextTheme base) {
    // `copyWith` con `letterSpacing: null` conserva el del estilo base; solo se
    // fuerza cuando el rol lo pide.
    TextStyle heading(
      TextStyle? style, {
      FontWeight weight = bold,
      double? letterSpacing,
      double? height,
    }) => (style ?? const TextStyle()).copyWith(
      fontFamily: family,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );

    return base.copyWith(
      displayLarge: heading(
        base.displayLarge,
        weight: display,
        letterSpacing: -1.2,
        height: 1.05,
      ),
      displayMedium: heading(
        base.displayMedium,
        weight: display,
        letterSpacing: -0.8,
        height: 1.08,
      ),
      displaySmall: heading(
        base.displaySmall,
        weight: display,
        letterSpacing: -0.5,
        height: 1.1,
      ),
      headlineLarge: heading(
        base.headlineLarge,
        letterSpacing: -0.4,
        height: 1.15,
      ),
      headlineMedium: heading(
        base.headlineMedium,
        letterSpacing: -0.3,
        height: 1.15,
      ),
      headlineSmall: heading(
        base.headlineSmall,
        letterSpacing: -0.2,
        height: 1.2,
      ),
      titleLarge: heading(base.titleLarge, letterSpacing: -0.1, height: 1.25),
      titleMedium: heading(base.titleMedium, letterSpacing: -0.1),
      titleSmall: heading(base.titleSmall, letterSpacing: -0.05),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: family,
        letterSpacing: 0,
        height: 1.45,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: family,
        letterSpacing: 0,
        height: 1.45,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: family,
        letterSpacing: 0,
        height: 1.35,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: family,
        fontWeight: semiBold,
        letterSpacing: 0,
        height: 1.3,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: family,
        fontWeight: semiBold,
        letterSpacing: 0,
        height: 1.3,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: family,
        fontWeight: semiBold,
        letterSpacing: 0.1,
        height: 1.3,
      ),
    );
  }
}
