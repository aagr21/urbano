import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import 'complaint_photo.dart';
import 'complaint_photo_viewer.dart';

/// Galería de las fotos de una queja: la elegida arriba, las demás de
/// miniatura, y un toque en la grande abre el visor a pantalla completa.
///
/// Existe porque una queja puede traer hasta 5 adjuntos (`photos` del
/// `POST /complaints`) y el detalle solía pintar `photoUrls.first` con un
/// «N fotos adjuntas» por debajo: las otras N-1 no se veían nunca. Aquí todas
/// son alcanzables: la miniatura cambia la principal y un toque en cualquiera
/// de las dos abre el visor a pantalla completa.
class ComplaintPhotoGallery extends StatefulWidget {
  const ComplaintPhotoGallery({
    super.key,
    required this.urls,
    this.height = 300,
  });

  /// Adjuntos de la queja, en el orden del backend.
  final List<String> urls;

  /// Alto de la foto principal (recorta con cover, no estira).
  final double height;

  @override
  State<ComplaintPhotoGallery> createState() => _ComplaintPhotoGalleryState();
}

class _ComplaintPhotoGalleryState extends State<ComplaintPhotoGallery> {
  int _selected = 0;

  /// Índice realmente visible: defensivo si la lista cambiara de tamaño.
  int get _index => _selected.clamp(0, widget.urls.length - 1);

  bool get _hasMore => widget.urls.length > 1;

  void _openViewer(int from) {
    openComplaintPhotoViewer(context, urls: widget.urls, initialIndex: from);
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final index = _index;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La foto principal se abre a pantalla completa con el mismo gesto que
        // la foto del micro en el panel y en el detalle de línea.
        PressScale(
          child: GestureDetector(
            key: const ValueKey('complaint-photo-main'),
            onTap: () => _openViewer(_index),
            child: Stack(
              children: [
                SizedBox(
                  height: widget.height,
                  width: double.infinity,
                  child: ComplaintPhoto(
                    url: urls[index],
                    radius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                if (_hasMore)
                  Positioned(
                    top: AppSpace.sm,
                    right: AppSpace.sm,
                    child: PhotoScrimPill(
                      label: '${index + 1}/${urls.length}',
                      icon: Icons.photo_library_rounded,
                    ),
                  ),
                Positioned(
                  bottom: AppSpace.sm,
                  right: AppSpace.sm,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const SizedBox.square(
                        dimension: 26,
                        child: Center(
                          child: Icon(
                            Icons.open_in_full_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_hasMore) ...[
          const SizedBox(height: AppSpace.sm),
          _ThumbStrip(
            urls: urls,
            selected: index,
            // Toque simple elige; tocar la que YA está elegida abre el visor
            // en esa foto (el mismo gesto que la red social de referencia).
            onTap: (i) {
              if (i == index) {
                _openViewer(i);
              } else {
                setState(() => _selected = i);
              }
            },
          ),
        ],
      ],
    );
  }
}

/// Miniaturas de los adjuntos, en una fila deslizante.
///
/// Tocan una y esa pasa a ser la foto principal; la que ya lo está se abre a
/// pantalla completa. No hay gesto escondido: un solo toque decide.
class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({
    required this.urls,
    required this.selected,
    required this.onTap,
  });

  final List<String> urls;
  final int selected;
  final ValueChanged<int> onTap;

  /// Lado de la miniatura: 8 px son del respiro interno, 52 de la foto.
  static const double _size = 60;
  static const double _photo = _size - AppSpace.xs * 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, i) {
          final active = i == selected;
          return PressScale(
            child: GestureDetector(
              key: ValueKey('complaint-photo-thumb-$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: Motion.quick,
                curve: Motion.standard,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  // La elegida se marca con el borde del tema (no con un color
                  // suelto) para que se lea en claro y en oscuro.
                  border: Border.all(
                    color: active
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: 0.6),
                    width: active ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xs),
                  child: Opacity(
                    opacity: active ? 1 : 0.72,
                    child: ComplaintPhoto(
                      url: urls[i],
                      width: _photo,
                      height: _photo,
                      radius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
