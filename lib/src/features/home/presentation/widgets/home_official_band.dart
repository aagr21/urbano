// Banda oficial de la portada: escudo del Gobierno Autónomo Municipal
// y píldora «Transporte Oficial» (ver HomeHeader).

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Banda oficial de la portada.
///
/// Firma la app como servicio del municipio: escudo a la izquierda y la
/// píldora «Transporte Oficial» a la derecha, sobre una franja clara que
/// separa la cabecera del lienzo de la portada. Va a sangre horizontal; el
/// área del sistema la resuelve [HomeHeader] con su respiro de lienzo.
class HomeOfficialBand extends StatelessWidget {
  const HomeOfficialBand({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Franja de papel: un blanco apenas teñido de aqua que se disuelve hacia
    // abajo, para que la banda oficial no corte el lienzo con una losa dura.
    // En oscuro sigue la superficie del tema, nunca una franja clara.
    final fillTop = dark
        ? colors.surface
        : AppColors.tint(AppColors.aqua, colors.surface, 0.09);
    final fillBottom = dark
        ? colors.surfaceContainerLow
        : AppColors.tint(AppColors.aqua, colors.surface, 0.02);
    final hairline = dark
        ? AppColors.lineDark
        : colors.primary.withValues(alpha: 0.14);

    return DecoratedBox(
      key: const ValueKey('home-official-band'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillTop, fillBottom],
        ),
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg + AppSpace.xs,
          AppSpace.sm,
          AppSpace.lg + AppSpace.xs,
          AppSpace.sm,
        ),
        child: Row(
          children: [
            // El escudo es una imagen: se escala, nunca se redibuja.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Semantics(
                  label:
                      'Gobierno Autónomo Municipal de Santa Cruz de la Sierra',
                  image: true,
                  child: const HomeOfficialSeal(),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            const HomeOfficialPill(),
          ],
        ),
      ),
    );
  }
}

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
      height: 34,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      // El escudo ya viene recortado; se declara su tamaño real para que el
      // layout no dependa del decodificado asíncrono.
      width: 34 * 900 / 370,
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

/// Píldora «Transporte Oficial»: punto aqua, filete de marca y tinta legible
/// sobre el relleno realmente pintado.
class HomeOfficialPill extends StatelessWidget {
  const HomeOfficialPill({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppColors.tint(
      colors.primary,
      colors.surface,
      dark ? 0.18 : 0.07,
    );
    final ink = dark
        ? colors.onSurface
        : AppColors.legible(colors.primary, fill);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dark ? colors.secondary : AppColors.aqua,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpace.sm - 2),
          Text(
            'Transporte Oficial',
            maxLines: 1,
            style: text.labelSmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
