import 'package:material_ui/material_ui.dart';

/// Tokens de color de Urbano.
///
/// Paleta oficial de la marca (manual «Paleta de colores Urbano»), **sin tonos
/// inventados**: verde luminoso `#35F04F`, brillante `#1BD64C`, principal
/// `#06BD4A`, oscuro `#029E46`, naranja `#FD7502` y blanco `#FEFEFE`. Todo
/// verde, naranja o blanco de la app es uno de esos seis (o uno de ellos con
/// transparencia sobre la superficie, vía [tint]). Fuera de la paleta solo
/// quedan los neutros: tinta y grises de texto, y el grafito del modo oscuro.
///
/// Regla del equipo sobre fondos oscuros/degradados: solo texto, íconos y
/// bordes claros (blancos o acentos luminosos) encima — nada de oscuros sobre
/// oscuros. Los verdes y el naranja de la marca son claros (el principal da
/// 2,5:1 contra blanco): como texto van en negrita y a tamaño de título o
/// etiqueta, igual que en las piezas de la marca.
class AppColors {
  AppColors._();

  // ── Marca ───────────────────────────────────────────────────────────────

  /// Semilla del [ColorScheme] (verde principal).
  static const Color seed = Color(0xFF06BD4A);

  /// Verde luminoso: arranque de los degradados de marca.
  static const Color lime = Color(0xFF35F04F);

  /// Verde brillante: segundo paso del degradado.
  static const Color brightGreen = Color(0xFF1BD64C);

  /// Verde principal de la marca (rellenos, íconos grandes, el wordmark).
  static const Color brand = Color(0xFF06BD4A);

  /// Primario del tema claro: el **verde oscuro** de la paleta. Es el verde
  /// más profundo que sigue siendo de la marca; aguanta texto en negrita
  /// blanco encima (3,5:1) y se lee como acento sobre el lienzo.
  static const Color primary = Color(0xFF029E46);

  /// Fin del degradado de marca: el verde oscuro de la paleta (= [primary]).
  static const Color primaryDark = Color(0xFF029E46);

  /// Punto medio del **campo de marca** con el que abren las secciones
  /// (la portada de Inicio, la splash y la de Quejas). Es el extremo contra
  /// el que se mide la tinta blanca que va encima.
  static const Color fieldMid = Color(0xFF06BD4A);

  /// Naranja de la marca (el pin de destino del logo).
  static const Color accent = Color(0xFFFD7502);

  /// Naranja como tinta (texto/íconos): el mismo naranja de la paleta.
  static const Color accentDeep = Color(0xFFFD7502);

  /// Verde como tinta (texto/íconos): el verde oscuro de la paleta.
  static const Color greenDeep = Color(0xFF029E46);

  /// Blanco de la marca.
  static const Color brandWhite = Color(0xFFFEFEFE);

  /// Tinta SOBRE el campo de marca (degradado de verdes): siempre blanca, como
  /// en todas las piezas de la marca. No se decide con [onColor]: contra el
  /// verde principal el negro mide más, y eso pintaba letra oscura sobre la
  /// portada verde. Va en negrita y a tamaño de título o etiqueta, nunca en
  /// cuerpo fino.
  static const Color onBrand = brandWhite;

  /// Tinta / texto principal (casi negro, como el label de iOS).
  static const Color ink = Color(0xFF111413);

  /// Texto secundario claro (gris de la marca, el del lema del logo).
  static const Color inkSoft = Color(0xFF6B6F6C);

  /// Fondo claro de app: el blanco de la marca.
  static const Color canvasLight = Color(0xFFFEFEFE);

  /// Superficies de tarjetas en claro: el blanco de la marca (se separan del
  /// lienzo por filete y sombra).
  static const Color surfaceLight = Color(0xFFFEFEFE);

  /// Contenedor primario en claro (verde muy diluido).
  static const Color primaryContainerLight = Color(0xFFD3F8DC);
  static const Color onPrimaryContainerLight = Color(0xFF029E46);

  /// Segundo acento (verde vivo, para datos vivos) y su contenedor.
  static const Color secondaryContainerLight = Color(0xFFC8F5D2);
  static const Color onSecondaryContainerLight = Color(0xFF029E46);

  /// Contenedor naranja en claro.
  static const Color tertiaryContainerLight = Color(0xFFFFE6D3);
  static const Color onTertiaryContainerLight = Color(0xFFFD7502);

  /// Contornos en claro: separador de iOS (`#C7C7CC`/`#E5E5EA`).
  static const Color outlineLight = Color(0xFFC7C7CC);
  static const Color outlineVariantLight = Color(0xFFE5E5EA);

  // ── Modo oscuro: gris grafito, nunca negro y nunca azul ─────────────────
  //
  // El pedido del usuario fue explícito: el negro (#000 y sus cercanías) se
  // veía «muy oscuro»; el fondo oscuro debe leerse GRIS oscuro. Toda la
  // escalera se levanta junta conservando pasos de ~5-6 puntos, así las
  // superficies siguen jerarquizadas sobre el lienzo.

  /// Fondo oscuro de app: grafito grisáceo, no negro.
  static const Color canvasDark = Color(0xFF1A1A1E);

  /// Superficie base en oscuro (tarjetas, hojas, diálogos).
  static const Color surfaceDark = Color(0xFF27272C);

  /// Niveles de `surfaceContainer*` en oscuro, de más bajo a más alto.
  static const Color surfaceContainerLowDark = Color(0xFF212126);
  static const Color surfaceContainerDark = Color(0xFF27272C);
  static const Color surfaceContainerHighDark = Color(0xFF2E2E34);
  static const Color surfaceContainerHighestDark = Color(0xFF36363C);

  /// Texto principal en oscuro.
  static const Color inkDark = Color(0xFFF5F5F7);

  /// Texto secundario en oscuro (levanta con la escalera: ~5:1 sobre
  /// `surfaceDark` y ~6:1 sobre `canvasDark`).
  static const Color inkDarkSoft = Color(0xFFB4B4BC);

  /// Contornos en oscuro: **blanco en alfa**, no gris. La regla de la casa es
  /// que el blanco del modo oscuro entre por la tipografía, los íconos y los
  /// bordes; pintar superficie blanca entera convierte la app en otra cosa.
  /// El alfa deja que el filete se lea sobre cualquier escalón del grafito.
  static const Color outlineDark = Color(0x66FFFFFF);
  static const Color outlineVariantDark = Color(0x2EFFFFFF);

  /// Filete fino de tarjeta en oscuro (el mismo blanco, más discreto).
  static const Color lineDark = Color(0x29FFFFFF);

  /// Filete de foco/identidad en oscuro: un paso más que [lineDark] para
  /// separar la tarjeta del lienzo sin dibujar un borde duro.
  static const Color lineStrongDark = Color(0x47FFFFFF);

  /// Primario en oscuro: el verde principal de la paleta (5,9:1 contra
  /// `surfaceDark`).
  static const Color primarySoftDark = Color(0xFF06BD4A);
  static const Color onPrimaryDark = Color(0xFFFEFEFE);
  static const Color primaryContainerDark = Color(0xFF029E46);
  static const Color onPrimaryContainerDark = Color(0xFFFEFEFE);

  /// Acentos en oscuro: los mismos de la paleta.
  static const Color accentSoftDark = Color(0xFFFD7502);
  static const Color limeSoftDark = Color(0xFF35F04F);

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

  /// Estado del micro (el naranja de la marca, como en el diseño de Quejas).
  static const Color categoryVehicle = Color(0xFFFD7502);

  /// Trato del conductor (violeta).
  static const Color categoryDriver = Color(0xFF8B5CF6);

  /// Desvío de ruta (amarillo: se separa del naranja de «estado del micro»).
  static const Color categoryDeviation = Color(0xFFEAB308);

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
