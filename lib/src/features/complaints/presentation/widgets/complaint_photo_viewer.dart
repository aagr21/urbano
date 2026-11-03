import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import 'complaint_photo.dart';

/// Abre TODAS las fotos de una queja a pantalla completa.
///
/// Entra en la foto [initialIndex] que se estaba mirando (la principal del
/// detalle o la miniatura tocada del feed) y deja pasar el resto con el gesto
/// horizontal. Se cierra tocando la foto, con la ✕ o con atrás del sistema.
Future<void> openComplaintPhotoViewer(
  BuildContext context, {
  required List<String> urls,
  required int initialIndex,
}) {
  final navigator = Navigator.of(context);
  final reduced = Motion.reduced(context);
  return navigator.push<void>(
    PageRouteBuilder<void>(
      // No opaca: el velo se posa sobre el post, así la foto se siente encima
      // de la queja y no en otra app.
      opaque: false,
      transitionDuration: reduced ? Duration.zero : Motion.transition,
      reverseTransitionDuration: reduced ? Duration.zero : Motion.release,
      pageBuilder: (_, _, _) =>
          ComplaintPhotoViewerScreen(urls: urls, initialIndex: initialIndex),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        // Entra rápido, sale suave: el fundido del velo hace de transición.
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

/// Visor de las adjuntos de una queja: una foto por página, deslizables.
///
/// Es la respuesta a «solo se ve la primera»: ninguna pantalla de la app puede
/// mostrar `photoUrls[0]` y dar el resto por contado. Cada página se puede
/// pellizcar para acercar (prueba de un reporte: hay que poder leer la patente),
/// el contador dice «qué foto de cuántas» y los puntos refuerzan que hay más.
class ComplaintPhotoViewerScreen extends StatefulWidget {
  const ComplaintPhotoViewerScreen({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<ComplaintPhotoViewerScreen> createState() =>
      _ComplaintPhotoViewerScreenState();
}

class _ComplaintPhotoViewerScreenState
    extends State<ComplaintPhotoViewerScreen> {
  late final PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    // `viewportFraction` < 1: asoma la foto siguiente, así el gesto de deslizar
    // se descubre solo sin escribir un «desliza» en pantalla.
    _pages = PageController(viewportFraction: 0.92, initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final total = urls.length;
    final colors = context.colors;
    final text = context.text;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          // Velo de visor: deja pasar apenas la escena de abajo. Es un fondo de
          // medio (como el del visor de fotos del micro), no una superficie del
          // tema, así que se mide igual en claro y en oscuro.
          color: Colors.black.withValues(alpha: 0.94),
        ),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: _close,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: total,
                  onPageChanged: (page) => setState(() => _index = page),
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                    ),
                    // La foto COMPLETA, sin recorte: es una prueba, lo que va
                    // fuera del encuadre es justamente lo que puede faltar.
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: ComplaintPhoto(
                          url: urls[index],
                          fit: BoxFit.contain,
                          radius: BorderRadius.circular(AppRadius.tile),
                          // El hueco NO pinta una superficie: sobre el velo,
                          // el letterbox debe ser el velo mismo.
                          placeholderSurface: Colors.transparent,
                          placeholderInk: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpace.sm,
                left: AppSpace.md,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: _close,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.38),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ),
              if (total > 1)
                Positioned(
                  top: AppSpace.sm,
                  right: AppSpace.md,
                  child: PhotoScrimPill(
                    label: '${_index + 1} de $total',
                    icon: Icons.photo_library_rounded,
                  ),
                ),
              if (total > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpace.lg,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < total; i++)
                          AnimatedContainer(
                            key: ValueKey('complaint-photo-dot-$i'),
                            duration: Motion.quick,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpace.xs,
                            ),
                            width: i == _index ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              // Puntos sobre la foto: claro sobre medio oscuro,
                              // nunca un gris del tema que desaparecería.
                              color: Colors.white.withValues(
                                alpha: i == _index ? 0.95 : 0.38,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (total == 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpace.lg,
                  child: Center(
                    child: Text(
                      'Foto de la queja',
                      style: text.bodySmall?.copyWith(
                        color: colors.onInverseSurface,
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
}
