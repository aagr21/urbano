import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../journey/application/journey_providers.dart';

/// Acceso destacado: Planificar viaje (mapa + planeador fusionados).
///
/// Es la acción principal del home, así que se monta **sobre el pie de la
/// portada** como una hoja clara: el contraste contra el verde profundo la
/// levanta y el ojo cae en ella antes que en cualquier otra cosa. La identidad
/// se queda en las piezas chicas —el riel verde agua del borde superior, la
/// cuadra del ícono con el degradado de laguna y la píldora de la flecha—, así
/// que la tarjeta suma marca sin plantar un segundo bloque verde.
///
/// Al pie corre el **corredor**: una línea de paradas con una unidad que lo
/// cruza una sola vez al entrar (una pasada, sin bucle: es un gesto de llegada,
/// no decoración eterna).
///
/// La entrada en cascada la decide el home (`Reveal`); aquí solo vive el
/// feedback de pulsado, que es lo que falta en toda tarjeta con `InkWell`.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: PressScale(scale: 0.98, child: _PlanActionCard()),
    );
  }
}

class _PlanActionCard extends ConsumerWidget {
  const _PlanActionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.text;
    // Hoja del tema (clara en claro, grafito en oscuro) levantada con la sombra
    // de la laguna: se despega del campo verde sin pedir un color propio.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppTheme.softShadow(
          color: AppColors.primaryDark,
          opacity: 0.18,
          blur: 22,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          // «Viajar» no solo cambia de pestaña: deja la bandera para que el
          // planeador despliegue el panel de origen/destino al llegar (ver
          // [pendingPlannerPanelProvider]).
          onTap: () {
            ref.read(pendingPlannerPanelProvider.notifier).state = true;
            context.go('/journey');
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Riel de marca: la misma orilla verde agua que cierra la
              // portada, ahora bordeando la hoja.
              SizedBox(
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.aqua,
                        colors.primary,
                        AppColors.tint(colors.primary, colors.surface, 0.2),
                      ],
                    ),
                  ),
                ),
              ),
              Stack(
                children: [
                  // Corredor de paradas al pie, con la unidad cruzando una vez.
                  Positioned.fill(
                    child: _Corridor(
                      ink: AppColors.tint(colors.primary, colors.surface, 0.3),
                      bus: colors.primary,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      AppSpace.md,
                      AppSpace.md,
                      AppSpace.md + AppSpace.xs,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.input,
                            ),
                            boxShadow: AppTheme.softShadow(
                              color: AppColors.primary,
                              opacity: 0.3,
                              blur: 12,
                              dy: 4,
                            ),
                          ),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            // Sobre el degradado de laguna la tinta se mide.
                            color: AppColors.onColor(AppColors.fieldMid),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Viajar',
                                style: text.titleMedium?.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Marca tu destino y listo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: colors.onPrimary,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Corredor del pie de la tarjeta: paradas + una unidad que lo recorre.
///
/// La unidad sólo existe mientras dura la pasada (`Ambient.cycles: 1`): al
/// terminar queda el corredor en reposo, que es textura y no un bucle más.
class _Corridor extends StatelessWidget {
  const _Corridor({required this.ink, required this.bus});

  final Color ink;
  final Color bus;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Ambient(
      cycles: 1,
      period: const Duration(milliseconds: 1600),
      builder: (context, t, phase, _) => CustomPaint(
        painter: _CorridorPainter(progress: t, ink: ink, bus: bus),
      ),
    ),
  );
}

class _CorridorPainter extends CustomPainter {
  const _CorridorPainter({
    required this.progress,
    required this.ink,
    required this.bus,
  });

  /// 0..1 de la pasada de la unidad.
  final double progress;

  /// Color del corredor y sus paradas (ya medido contra la superficie).
  final Color ink;

  /// Tinte de la unidad que lo cruza.
  final Color bus;

  /// Alto reservado al pie, dentro del padding inferior de la tarjeta.
  static const double _laneInset = 9;

  /// Fracciones del ancho donde hay parada.
  static const List<double> _stops = [0.12, 0.38, 0.64, 0.9];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final y = size.height - _laneInset;
    const left = AppSpace.md;
    final right = size.width - AppSpace.md;

    // Línea punteada: el corredor se lee como recorrido, no como borde.
    final dash = Paint()
      ..color = ink.withValues(alpha: 0.45)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dashWidth = 5.0;
    const dashGap = 5.0;
    for (var x = left; x < right; x += dashWidth + dashGap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashWidth, right), y),
        dash,
      );
    }

    // Paradas.
    final stop = Paint()..color = ink.withValues(alpha: 0.75);
    for (final fraction in _stops) {
      canvas.drawCircle(Offset(left + (right - left) * fraction, y), 1.9, stop);
    }

    // Unidad: entra desde la izquierda, se desvanece al llegar al final.
    final x = left + (right - left) * Curves.easeInOut.transform(progress);
    final fade = math.sin(math.pi * progress).clamp(0.0, 1.0);
    if (fade <= 0.01) return;
    canvas.drawCircle(
      Offset(x, y),
      6,
      Paint()..color = bus.withValues(alpha: 0.22 * fade),
    );
    canvas.drawCircle(
      Offset(x, y),
      3,
      Paint()..color = bus.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(_CorridorPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ink != ink ||
      oldDelegate.bus != bus;
}
