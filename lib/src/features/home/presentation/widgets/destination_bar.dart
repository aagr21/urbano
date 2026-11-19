import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../journey/application/journey_planner_controller.dart';
import '../../../journey/presentation/widgets/journey_destination_sheet.dart';

/// Barra de destino de la portada: «¿A dónde vas?».
///
/// Es un input bonito que abre el sheet de origen/destino (el mismo que
/// abre el acceso «Viajes»), para que el usuario pueda marcar su destino
/// sin tener que ir primero al mapa.
class DestinationBar extends ConsumerWidget {
  const DestinationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.text;
    final radius = BorderRadius.circular(AppRadius.lg);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // En oscuro la barra es un tinte de marca sobre el grafito: el blanco entra
    // en el título, en los íconos y en el filete del borde, no en un relleno
    // claro que rompería la portada.
    final fill = AppColors.tint(
      colors.primary,
      colors.surface,
      dark ? 0.16 : 0.1,
    );
    final square = dark
        ? AppColors.tint(colors.primary, colors.surface, 0.26)
        : colors.surface;
    final ink = dark
        ? colors.onSurface
        : AppColors.legible(colors.primary, square);
    final titleInk = colors.onSurface;
    final subInk = colors.onSurfaceVariant;

    void openDestinationSheet() {
      final planner = ref.read(journeyPlannerControllerProvider);
      showJourneyDestinationSheet(
        context: context,
        ref: ref,
        initialOrigin: planner.origin,
        initialDestination: planner.destination,
      );
    }

    return PressScale(
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg + AppSpace.xs,
          AppSpace.lg,
          AppSpace.lg + AppSpace.xs,
          0,
        ),
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: dark
                  ? AppColors.lineDark
                  : colors.primary.withValues(alpha: 0.12),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('home-destination'),
            borderRadius: radius,
            splashColor: titleInk.withValues(alpha: 0.06),
            onTap: openDestinationSheet,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(
                children: [
                  // Cuadra de superficie: la unidad que abre el viaje.
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: square,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Icon(
                      Icons.directions_bus_filled_rounded,
                      size: 25,
                      color: ink,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '¿A dónde vas?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            height: 1.1,
                            color: titleInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Marca tu destino y listo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            color: subInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: square,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 21,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
