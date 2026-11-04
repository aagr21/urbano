import 'package:flutter/material.dart';

/// Tokens de color de Urbano.
///
/// Identidad "laguna": verde agua sólido como color principal (de la orilla
/// brillante a la laguna profunda), coral como contracolor cálido del
/// atardecer cruceño y neutros grises de Apple: en claro
/// `systemGroupedBackground` (`#F2F2F7`) y en oscuro grafito sobre negro.
/// Regla del equipo sobre fondos oscuros/degradados: solo texto, íconos y
/// bordes claros (blancos o acentos luminosos) encima — nada de oscuros
/// sobre oscuros.
class AppColors {
  AppColors._();

  // ── Modo claro ──────────────────────────────────────────────────────────

  /// Semilla del [ColorScheme] (verde agua profundo).
  static const Color seed = Color(0xFF008C7B);

  /// Verde agua brillante: arranque de los gradientes de marca ("la orilla").
  static const Color aqua = Color(0xFF2AD8C3);

  /// Primario (verde agua sólido, laguna).
  static const Color primary = Color(0xFF008C7B);

  /// Primario profundo para gradientes (fondo de laguna).
  static const Color primaryDark = Color(0xFF00584F);

  /// Punto medio del **campo de marca** con el que abren las secciones
  /// (la portada de Inicio y la de Quejas): la laguna aclarada hacia la
  /// orilla. Vale `tint(primary, primaryDark, 0.55)` y existe como token
  /// porque es el extremo MÁS CLARO del degradado, o sea el peor caso contra
  /// el que se mide la tinta que va encima ([onColor] devuelve blanco, ≥5.6:1).
  /// Si las dos portadas no comparten este punto, dejan de ser la misma marca.
  static const Color fieldMid = Color(0xFF007567);

  /// Acento cálido (coral, atardecer cruceño).
  static const Color accent = Color(0xFFFF5B35);

  /// Acento profundo (para texto/chips sobre claros).
  static const Color accentDeep = Color(0xFFDC4514);

  /// Verde agua legible sobre superficies claras (texto/íconos).
  static const Color aquaDeep = Color(0xFF077A6D);

  /// Tinta / texto principal (casi negro, como el label de iOS).
  static const Color ink = Color(0xFF0F0F12);

  /// Texto secundario claro (gris Apple).
  static const Color inkSoft = Color(0xFF86868B);

  /// Fondo claro de app: el "systemGroupedBackground" de iOS.
  static const Color canvasLight = Color(0xFFF2F2F7);

  /// Superficies de tarjetas en claro (blanco puro).
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Contenedor primario en claro (verde agua).
  static const Color primaryContainerLight = Color(0xFFC4F2E9);
  static const Color onPrimaryContainerLight = Color(0xFF004A42);

  /// Segundo acento (verde agua más claro, para datos vivos) y su contenedor.
  static const Color secondaryContainerLight = Color(0xFFB9F1E5);
  static const Color onSecondaryContainerLight = Color(0xFF00584F);

  /// Contenedor coral en claro.
  static const Color tertiaryContainerLight = Color(0xFFFFE2D2);
  static const Color onTertiaryContainerLight = Color(0xFF8B2B0A);

  /// Contornos en claro: separador de iOS (`#C7C7CC`/`#E5E5EA`).
  static const Color outlineLight = Color(0xFFC7C7CC);
  static const Color outlineVariantLight = Color(0xFFE5E5EA);

  // ── Modo oscuro: grafito de iOS, no azul ────────────────────────────────

  /// Fondo oscuro de app (negro, como el OLED de un iPhone).
  static const Color canvasDark = Color(0xFF000000);

  /// Superficie base en oscuro (tarjetas, hojas, diálogos).
  static const Color surfaceDark = Color(0xFF1C1C1E);

  /// Niveles de `surfaceContainer*` en oscuro, de más bajo a más alto.
  static const Color surfaceContainerLowDark = Color(0xFF161618);
  static const Color surfaceContainerDark = Color(0xFF1C1C1E);
  static const Color surfaceContainerHighDark = Color(0xFF242426);
  static const Color surfaceContainerHighestDark = Color(0xFF2C2C2E);

  /// Texto principal en oscuro.
  static const Color inkDark = Color(0xFFF5F5F7);

  /// Texto secundario en oscuro.
  static const Color inkDarkSoft = Color(0xFF98989D);

  /// Contornos en oscuro (grises de Apple, poco ruido).
  static const Color outlineDark = Color(0xFF48484A);
  static const Color outlineVariantDark = Color(0xFF38383A);

  /// Primario en oscuro (verde agua luminoso para contrastar sobre
  /// superficies oscuras) y su contenedor.
  static const Color primarySoftDark = Color(0xFF4FE3D0);
  static const Color onPrimaryDark = Color(0xFF00352F);
  static const Color primaryContainerDark = Color(0xFF00635A);
  static const Color onPrimaryContainerDark = Color(0xFFC2F5EC);

  /// Acentos vivos en oscuro.
  static const Color accentSoftDark = Color(0xFFFF9166);
  static const Color aquaSoftDark = Color(0xFF3BE0CE);

  /// Error.
  static const Color danger = Color(0xFFE5484D);

  /// Verde éxito.
  static const Color success = Color(0xFF059669);

  // ── Acentos vivos del feed de quejas ─────────────────────────────────────
  //
  // Un matiz por motivo de reporte: así el feed se escanea de un vistazo y
  // cada tarjeta tiene identidad propia. Son acentos para **teñir**, no para
  // pintar planos: se diluyen sobre la superficie del tema con [tint] y las
  // letras, íconos y bordes que los usan pasan por [legible]. Así el mismo
  // acento funciona en claro y en oscuro sin dejar letra oscura sobre fondo
  // oscuro (la regla de arriba de este archivo).

  /// Estado del micro (celeste).
  static const Color categoryVehicle = Color(0xFF0EA5E9);

  /// Trato del conductor (violeta).
  static const Color categoryDriver = Color(0xFF8B5CF6);

  /// Desvío de ruta (ámbar).
  static const Color categoryDeviation = Color(0xFFF59E0B);

  /// Frecuencia u horario (índigo).
  static const Color categorySchedule = Color(0xFF6366F1);

  /// Seguridad (rojo). Es un rojo **de categoría**, distinto de [danger]/
  /// `colors.error`, que sigue reservado para errores de formulario y de red.
  static const Color categorySafety = Color(0xFFEF4444);

  /// Otro reporte (pizarra).
  static const Color categoryOther = Color(0xFF64748B);

  /// Acento de la categoría de una queja (las claves son las del backend:
  /// `vehicle`, `driver_treatment`, `route_deviation`, `schedule`, `safety`).
  static Color categoryAccent(String category) => switch (category) {
    'vehicle' => categoryVehicle,
    'driver_treatment' => categoryDriver,
    'route_deviation' => categoryDeviation,
    'schedule' => categorySchedule,
    'safety' => categorySafety,
    _ => categoryOther,
  };

  /// Tinte de [accent] sobre [surface] para rellenos suaves (chips, raíles).
  ///
  /// Existe en un solo lugar para que ninguna tarjeta pinte un `Color.lerp`
  /// propio con su propio alfa: el fondo medido en los tests de contraste es
  /// siempre éste.
  static Color tint(Color accent, Color surface, [double alpha = 0.16]) =>
      Color.lerp(surface, accent, alpha)!;

  /// Convierte un hex GTFS (`D35400`, con o sin `#`) a [Color].
  static Color fromHex(
    String? hex, {
    Color fallback = const Color(0xFF64748B),
  }) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 3) {
      value = value.split('').map((c) => '$c$c').join();
    }
    if (value.length != 6) return fallback;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return fallback;
    return Color(0xFF000000 | parsed);
  }

  /// Texto con buen contraste sobre [background] (usa [preferred] si es
  /// legible, que en GTFS es `textColor`).
  static Color onColor(Color background, {Color? preferred}) {
    if (preferred != null && _contrast(preferred, background) >= 3) {
      return preferred;
    }
    return _contrast(Colors.black, background) >=
            _contrast(Colors.white, background)
        ? Colors.black
        : Colors.white;
  }

  /// Versión **legible** de [color] cuando se usa como texto, ícono o borde
  /// sobre [background]: mueve su brillo (conservando tono y saturación) hacia
  /// el lado que sube el contraste hasta alcanzar [minContrast].
  ///
  /// Los colores de línea vienen del GTFS y pueden ser muy oscuros (`2C3E50`)
  /// o muy claros (`F1C40F`); pintarlos tal cual sobre la superficie del tema
  /// deja letra oscura sobre fondo oscuro (o clara sobre clara). Cualquier
  /// tinte que pinte letras, íconos o bordes pasa por aquí; para un relleno
  /// **sólido** con su propio texto, usa mejor [onColor].
  static Color legible(
    Color color,
    Color background, {
    double minContrast = 4.5,
  }) {
    if (_contrast(color, background) >= minContrast) return color;
    final hsl = HSLColor.fromColor(color);
    // Fondo oscuro → hay que ACLARAR el color; fondo claro → oscurecerlo.
    final step = background.computeLuminance() < 0.5 ? 0.05 : -0.05;
    var best = color;
    for (var i = 1; i <= 24; i++) {
      final candidate = hsl
          .withLightness((hsl.lightness + step * i).clamp(0.04, 0.98))
          .toColor();
      best = candidate;
      if (_contrast(candidate, background) >= minContrast) return candidate;
    }
    return best;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance() + 0.05;
    final lb = b.computeLuminance() + 0.05;
    return la > lb ? la / lb : lb / la;
  }
}
