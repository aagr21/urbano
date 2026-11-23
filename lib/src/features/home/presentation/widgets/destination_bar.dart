import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../../journey/application/journey_planner_controller.dart';
import '../../../journey/presentation/widgets/journey_destination_sheet.dart';

/// Tarjeta de destino de la portada: «¿A dónde vas?».
///
/// Es el CTA principal y por eso se pinta como un pequeño hero: degradado de
/// laguna, una trama de anillos y una píldora clara con el gesto («Marca tu
/// destino y listo») dentro. Toda la tarjeta es el objetivo táctil; abre el
/// sheet de origen/destino.
///
/// El texto vive sobre el degradado con tinta clara: el punto más alto del
/// gradiente ([AppColors.fieldMid]) ya garantiza ≥5.6:1 con blanco, así que la
/// tarjeta funciona en claro y en oscuro sin recalcular tintas.
class DestinationBar extends ConsumerWidget {
  const DestinationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.lg);

    void openDestinationSheet() {
      final planner = ref.read(journeyPlannerControllerProvider);
      showJourneyDestinationSheet(
        context: context,
        ref: ref,
        initialOrigin: planner.origin,
        initialDestination: planner.destination,
      );
    }

    // Colores fijos del HTML: degradado oscuro, píldora blanca, botón naranja.
    const bgStart = HtmlDesignTokens.darkBgStart;
    const bgMid = HtmlDesignTokens.darkBgMid;
    const bgEnd = HtmlDesignTokens.darkBgEnd;
    const borderEmerald = HtmlDesignTokens.emerald600;
    const arrowOrange1 = HtmlDesignTokens.orange500;
    const arrowOrange2 = HtmlDesignTokens.orange600;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg + AppSpace.xs,
        AppSpace.lg,
        AppSpace.lg + AppSpace.xs,
        0,
      ),
      child: PressScale(
        scale: 0.98,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgStart, bgMid, bgEnd],
            ),
            borderRadius: radius,
            border: Border.all(
              color: borderEmerald.withValues(alpha: 0.3),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: bgEnd.withValues(alpha: dark ? 0.42 : 0.28),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('home-destination'),
              borderRadius: radius,
              splashColor: Colors.white.withValues(alpha: 0.10),
              onTap: openDestinationSheet,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _HeroTrailPainter()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.md + 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'PLANIFICA TU VIAJE',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall?.copyWith(
                                  color: HtmlDesignTokens.emerald300,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            const _LivePill(),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '¿A dónde vas?',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: AppSpace.sm + 2),
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.md,
                            5,
                            5,
                            5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: Colors.white),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: HtmlDesignTokens.slate500,
                              ),
                              const SizedBox(width: AppSpace.sm),
                              Expanded(
                                child: Text(
                                  'Marca tu destino y listo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyMedium?.copyWith(
                                    color: HtmlDesignTokens.slate700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpace.sm),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [arrowOrange1, arrowOrange2],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x73FF9500),
                                      blurRadius: 12,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 19,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

/// Píldora «En segundos»: colores del HTML (esmeralda sobre el degradado oscuro).
class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
      decoration: BoxDecoration(
        color: HtmlDesignTokens.emerald900.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: HtmlDesignTokens.emerald400.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveDot(color: HtmlDesignTokens.emerald400, size: 5),
          const SizedBox(width: 5),
          Text(
            'En segundos',
            maxLines: 1,
            style: context.text.labelSmall?.copyWith(
              color: HtmlDesignTokens.emerald200,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Trama del hero: anillos y una ruta punteada que sale del borde derecho.
///
/// Colores esmeralda translúcidos del HTML sobre el degradado oscuro.
class _HeroTrailPainter extends CustomPainter {
  const _HeroTrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width * 1.04, size.height * 0.06);

    // Anillos esmeralda del HTML
    for (final (radius, alpha, width) in const [
      (0.52, 0.10, 1.2),
      (0.40, 0.14, 1.4),
      (0.28, 0.18, 1.8),
    ]) {
      canvas.drawCircle(
        center,
        size.width * radius,
        Paint()
          ..color = HtmlDesignTokens.emerald400.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }

    // Ruta punteada sobre el anillo medio.
    final route = Rect.fromCircle(center: center, radius: size.width * 0.40);
    const dash = 5.0;
    const gap = 4.0;
    final metric = (Path()..addArc(route, math.pi * 0.55, math.pi * 0.42))
        .computeMetrics()
        .first;
    var distance = 0.0;
    final paint = Paint()
      ..color = HtmlDesignTokens.emerald200.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    while (distance < metric.length) {
      canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
      distance += dash + gap;
    }

    // Parada final de la ruta.
    final stop =
        center + Offset.fromDirection(math.pi * 0.78, size.width * 0.40);
    canvas.drawCircle(
      stop,
      4,
      Paint()..color = HtmlDesignTokens.emerald300.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      stop,
      7,
      Paint()
        ..color = HtmlDesignTokens.emerald300.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_HeroTrailPainter oldDelegate) => false;
}
