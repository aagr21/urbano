import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Foto adjunta a una queja, servida desde el blob (`photoUrls` del feed).
///
/// Es la pieza común de la galería del detalle y del visor a pantalla completa
/// para que los dos recorten, carguen y fallen IGUAL. La imagen se desvanece
/// cuando llega su primer frame y, si el enlace falla, queda un hueco del tema
/// con su ícono — nunca negro/blanco fijos, que en modo claro parecen un error.
class ComplaintPhoto extends StatelessWidget {
  const ComplaintPhoto({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.placeholderSurface,
    this.placeholderInk,
  });

  final String url;
  final double? width;
  final double? height;

  /// Ajuste dentro de la caja: [BoxFit.cover] para miniaturas y la foto
  /// principal, [BoxFit.contain] en el visor (la prueba se ve completa).
  final BoxFit fit;

  /// Esquinas del recorte. `null` = cápsula de escala [AppRadius.sm].
  final BorderRadius? radius;

  /// Relleno e ícono del hueco mientras carga / si el enlace falla. En el post
  /// son superficies del tema; en el visor se pintan sobre el velo oscuro, así
  /// que quien llama pasa claros translúcidos (un gris del tema claro sería una
  /// banda luminosa encima de la pantalla negra).
  final Color? placeholderSurface;
  final Color? placeholderInk;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(AppRadius.sm),
      child: ColoredBox(
        color: placeholderSurface ?? colors.surfaceContainerHighest,
        child: Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          frameBuilder: _fadeIn,
          // Mismo gesto que la tarjeta del feed: el hueco se pinta con tokens
          // del tema y su ícono, no con un color a mano.
          errorBuilder: (_, _, _) => Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 22,
              color: placeholderInk ?? colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  /// Aparición suave cuando llega el primer frame decodificado.
  static Widget _fadeIn(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSync,
  ) {
    if (wasSync) return child;
    return AnimatedOpacity(
      duration: Motion.release,
      curve: Curves.easeOut,
      opacity: frame == null ? 0 : 1,
      child: child,
    );
  }
}

/// Pastilla compacta que flota sobre una foto (contador, «ver todas»).
///
/// `inverseSurface` en vez de negro + blanco: se lee igual en tema claro
/// (oscura) y en oscuro (clara), que es la regla de la casa para lo que va
/// ENCIMA de una imagen.
class PhotoScrimPill extends StatelessWidget {
  const PhotoScrimPill({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.inverseSurface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: colors.onInverseSurface),
              const SizedBox(width: AppSpace.xs),
            ],
            Text(
              label,
              style: TextStyle(
                color: colors.onInverseSurface,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
