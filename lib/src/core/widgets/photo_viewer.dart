import 'package:flutter/material.dart';

import '../animation/motion.dart';
import '../theme/app_theme.dart';
import '../utils/extensions.dart';
import 'route_photo.dart';

/// Tag de Hero de la foto de un micro.
///
/// Lleva el ORIGEN delante (`panel`, `detail`…) porque la app puede tener la
/// misma línea montada en dos ramas del shell a la vez (Inicio y Viaje): dos
/// `Hero` con el mismo tag en la misma ruta lanzan «multiple heroes that share
/// the same tag». Mismo patrón que la insignia de ruta (`route-badge-…`).
String photoHeroTag(String source, String id) => 'micro-photo-$source-$id';

/// Abre la foto de un micro a pantalla completa con un **vuelo compartido**
/// desde la miniatura: la imagen se despega de la tarjeta, se agranda hasta
/// llenar la pantalla y sus esquinas se enderezan mientras el fondo se oscurece.
///
/// El [tag] tiene que ser el MISMO que el del `Hero` que envuelve la miniatura
/// (ver [photoHeroTag]); el vuelo lo pinta [PhotoViewerScreen].
Future<void> openPhotoViewer(
  BuildContext context, {
  required String url,
  required String tag,
  String? title,
  String? subtitle,
  Color? accent,
  double sourceRadius = AppRadius.md,
}) {
  final reduced = Motion.reduced(context);
  final navigator = Navigator.of(context);
  return navigator.push<void>(
    PageRouteBuilder<void>(
      // No opaca: durante el vuelo se sigue viendo (atenuado) el panel de
      // debajo, que es lo que da la sensación de «salir de la tarjeta».
      opaque: false,
      transitionDuration: reduced ? Duration.zero : Motion.transition,
      reverseTransitionDuration: reduced ? Duration.zero : Motion.release,
      pageBuilder: (_, _, _) => PhotoViewerScreen(
        url: url,
        tag: tag,
        title: title,
        subtitle: subtitle,
        accent: accent,
        sourceRadius: sourceRadius,
      ),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        // El velo entra rápido y sale suave; el movimiento lo pone el Hero.
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: child,
      ),
    ),
  );
}

/// Foto del micro a pantalla completa.
///
/// El vuelo de entrada lo hace el [Hero] (tag = [tag]); esta pantalla solo
/// aporta el fondo oscuro, el gesto de pellizcar para acercar y el pie con el
/// nombre de la línea. Se cierra tocando la foto, con la ✕ o con el gesto de
/// atrás del sistema.
class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({
    super.key,
    required this.url,
    required this.tag,
    this.title,
    this.subtitle,
    this.accent,
    this.sourceRadius = AppRadius.md,
  });

  final String url;
  final String tag;

  /// Radio de la miniatura de la que sale el vuelo (se endereza hasta 0).
  final double sourceRadius;

  /// Nombre de la línea (pie de la foto).
  final String? title;

  /// Línea secundaria del pie (p. ej. «Foto del micro»).
  final String? subtitle;

  /// Tinte de la línea: la rayita del pie.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    // Velo oscuro: deja pasar un 8% de la escena de abajo (el panel) para que
    // la foto se sienta encima y no en otra app.
    final veil = Colors.black.withValues(alpha: 0.92);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(color: veil),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // La foto COMPLETA, centrada sobre el velo: la caja del `Hero`
              // mide lo que la foto (aspecto intrínseco), así que nunca se
              // recorta al abrir ni queda un zoom forzado. El `InteractiveViewer`
              // solo AMPLÍA desde ese tamaño (mínimo 1×): el pellizco y el
              // arrastre quedan disponibles en cuanto se acerca, y el tap —
              // sin movimiento — cierra.
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  // Al acercar, arrastrar mueve la foto dentro del encuadre.
                  child: Center(
                    child: Hero(
                      tag: tag,
                      // Esquinas que se enderezan durante el vuelo (ver
                      // [_flightShuttle]).
                      flightShuttleBuilder: _flightShuttle,
                      child: RoutePhoto(url: url, radius: BorderRadius.zero),
                    ),
                  ),
                ),
              ),
              // ✕ sobre un disco oscuro: legible sobre cualquier foto.
              Positioned(
                top: AppSpace.sm,
                right: AppSpace.md,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.38),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ),
              if (title != null || subtitle != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.72),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: accent ?? colors.primary,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(
                                  child: Text(
                                    title!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    // Texto claro sobre el velo del pie: la
                                    // foto puede ser clara y el degradado ya
                                    // garantiza el contraste.
                                    style: text.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                subtitle!,
                                style: text.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vuelo: la foto vuela con las esquinas de la tarjeta (12) que se enderezan
  /// hasta cero, así el aterrizaje no es un rectángulo duro.
  Widget _flightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final hero = toHeroContext.widget as Hero;
    final radius = sourceRadius * (1 - animation.value);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: hero.child,
    );
  }
}
