import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Mosaico de fotos adjuntas al formulario de queja.
///
/// Muestra las fotos seleccionadas con botón de quitar y un slot para
/// añadir más. Cuando no hay fotos, el botón ocupa todo el ancho.
/// [onAdd] es `null` mientras se envía: el mosaico se apaga pero no
/// desaparece.
class ComplaintPhotoPicker extends StatelessWidget {
  const ComplaintPhotoPicker({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> photos;

  /// `null` mientras se envía: el mosaico se apaga pero no desaparece.
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canAdd = photos.length < 5;
    // Sin fotos, el botón es una zona ancha de «añadir»; con fotos, se vuelve
    // la última pieza del mosaico. El gesto de añadir no cambia de sitio.
    final wide = photos.isEmpty;
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (var index = 0; index < photos.length; index++)
          SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.file(
                      File(photos[index].path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpace.xs,
                  right: AppSpace.xs,
                  child: IconButton(
                    onPressed: () => onRemove(index),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Quitar foto',
                    style: IconButton.styleFrom(
                      // Pastilla sobre la foto: `inverseSurface` se invierte con
                      // el tema en vez de fijar negro/blanco.
                      backgroundColor: colors.inverseSurface.withValues(
                        alpha: 0.72,
                      ),
                      foregroundColor: colors.onInverseSurface,
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (canAdd)
          SizedBox(
            width: wide ? double.infinity : 86,
            height: wide ? 92 : 86,
            child: Material(
              color: AppColors.tint(colors.primary, colors.surface, 0.07),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.tint(
                        colors.primary,
                        colors.outlineVariant,
                        0.55,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 24,
                        color: colors.primary,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        wide
                            ? 'Añadir fotos · ${photos.length} de 5'
                            : 'Añadir',
                        textAlign: TextAlign.center,
                        style: context.text.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
