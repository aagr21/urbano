// Escudo del Gobierno Autónomo Municipal de Santa Cruz de la Sierra
// (cabecera de Inicio, ver HomeHeader).

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Escudo oficial en PNG (fondo transparente).
///
/// En claro cae directamente sobre la franja; en oscuro el trazo negro del
/// escudo se perdería contra el grafito, así que se monta en una placa blanca
/// —el único blanco duro del archivo, y está justificado: la imagen es fija y
/// no puede recolorearse por tema—.
class HomeOfficialSeal extends StatelessWidget {
  const HomeOfficialSeal({super.key});

  static const String _asset = 'assets/images/gobierno-santa-cruz.png';

  /// Cuánto asoma la placa blanca alrededor del escudo en oscuro. El vertical
  /// tiene que caber en el respiro de la banda (`AppSpace.sm`).
  static const Offset _plateInset = Offset(AppSpace.xs + 2, 3);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final image = Image.asset(
      _asset,
      height: 56,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      // El escudo ya viene recortado; se declara su tamaño real para que el
      // layout no dependa del decodificado asíncrono.
      width: 56 * 900 / 370,
    );
    if (!dark) return image;
    // La placa se pinta POR FUERA de la caja del escudo (dentro del respiro de
    // la banda), no como relleno: con `padding` la banda crecía 6 dp en oscuro
    // y toda la portada bajaba un pelín respecto de claro. Así el escudo mide
    // y está exactamente donde en claro.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -_plateInset.dx,
          right: -_plateInset.dx,
          top: -_plateInset.dy,
          bottom: -_plateInset.dy,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
        image,
      ],
    );
  }
}
