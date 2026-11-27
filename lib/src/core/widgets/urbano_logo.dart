import 'package:material_ui/material_ui.dart';

import '../config/env.dart';
import '../theme/typography.dart';

/// Logotipo oficial de Urbano: la palabra con su recorrido y el pin naranja.
///
/// El dibujo es un PNG generado por `tools/make-brand-logo.sh` desde
/// `tools/brand_logo.py` (Montserrat ExtraBold + trazo + pin): la app y la
/// splash nativa de Android usan exactamente el mismo archivo. Dos variantes:
/// verde sobre lienzos (claro o grafito) y [onBrand] = blanca, para ir encima
/// del degradado verde.
///
/// El lema «Muévete por Santa Cruz» va como **texto** debajo (no dentro del
/// PNG) para que cambie de tinta con el tema y siga siendo accesible.
class UrbanoLogo extends StatelessWidget {
  const UrbanoLogo({
    super.key,
    this.height = 40,
    this.onBrand = false,
    this.showTagline = true,
    this.taglineColor,
  });

  /// Alto del dibujo (sin el lema).
  final double height;

  /// Variante blanca, para el degradado de marca.
  final bool onBrand;

  final bool showTagline;

  /// Tinta del lema; por defecto blanco sobre la marca y gris en el lienzo.
  final Color? taglineColor;

  /// Relación de aspecto del PNG (900 × 224 en el SVG de origen).
  static const double aspect = 900 / 224;

  static const String greenAsset = 'assets/images/urbano-logo.png';
  static const String whiteAsset = 'assets/images/urbano-logo-blanco.png';

  @override
  Widget build(BuildContext context) {
    final width = height * aspect;
    final theme = Theme.of(context);
    // El gris del lema del manual de marca en claro; en oscuro, la tinta
    // secundaria del tema (el gris de la marca se perdería en el grafito).
    final ink =
        taglineColor ??
        (onBrand
            ? Colors.white
            : theme.brightness == Brightness.dark
            ? theme.colorScheme.onSurfaceVariant
            : const Color(0xFF4A4D4B));
    return Semantics(
      label: '${Env.appName}. ${Env.tagline}',
      container: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            onBrand ? whiteAsset : greenAsset,
            width: width,
            height: height,
            fit: BoxFit.contain,
          ),
          if (showTagline)
            SizedBox(
              width: width * 0.86,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  Env.tagline,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontWeight: FontWeight.w700,
                    fontSize: height * 0.36,
                    height: 1.2,
                    color: ink,
                    // La splash no tiene `Material` encima: sin esto hereda
                    // el subrayado amarillo de depuración.
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
