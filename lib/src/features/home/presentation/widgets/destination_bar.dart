import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import 'home_navigation.dart';

/// Tarjeta **«Planifica tu viaje»** de la portada: el CTA principal.
///
/// Campo de marca (degradado de verdes) con el ícono del recorrido, el título
/// y la bajada en blanco, y debajo la píldora blanca «¿A dónde vas?» con su
/// botón naranja. Toda la tarjeta es el objetivo táctil y abre la hoja de
/// origen/destino ([openJourneyDestinationSheet]).
///
/// Encima del degradado solo va tinta blanca, en negrita y grande (la regla de
/// la marca: el verde principal no aguanta texto fino blanco).
class DestinationBar extends ConsumerWidget {
  const DestinationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.xl);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.lg,
        0,
      ),
      child: PressScale(
        scale: 0.98,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: urbanoGradient,
            borderRadius: radius,
            boxShadow: AppTheme.softShadow(
              color: AppColors.primaryDark,
              opacity: dark ? 0.35 : 0.28,
              blur: 22,
              dy: 10,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('home-destination'),
              borderRadius: radius,
              splashColor: Colors.white.withValues(alpha: 0.12),
              onTap: () => openJourneyDestinationSheet(context, ref),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.lg + AppSpace.xs,
                  AppSpace.lg + AppSpace.xs,
                  AppSpace.lg,
                  AppSpace.lg + AppSpace.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const SizedBox.square(
                          dimension: 58,
                          child: CustomPaint(painter: _RouteMarkPainter()),
                        ),
                        const SizedBox(width: AppSpace.md + 2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Planifica tu viaje',
                                  maxLines: 1,
                                  style: text.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Encuentra la mejor ruta, combina opciones '
                                'y llega a tu destino.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    const _SearchPill(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora blanca «¿A dónde vas?» con la lupa verde y la flecha naranja.
///
/// Es blanca en ambos temas: va SOBRE el degradado de marca, no sobre el
/// lienzo, así que su tinta (gris oscuro) se mide contra blanco.
class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppTheme.softShadow(
          color: Colors.black,
          opacity: 0.12,
          blur: 12,
          dy: 4,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 26, color: AppColors.primary),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              '¿A dónde vas?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium?.copyWith(
                color: const Color(0xFF5C625E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow(
                color: AppColors.accent,
                opacity: 0.45,
                blur: 12,
                dy: 3,
              ),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 24,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marca del recorrido en blanco: dos pines unidos por un trazo punteado (el
/// ícono de la tarjeta del diseño).
class _RouteMarkPainter extends CustomPainter {
  const _RouteMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = size.shortestSide / 100;
    final white = Paint()..color = Colors.white;
    final hole = Paint()..color = AppColors.brand;

    Path pin(Offset tip, double r) {
      final cy = tip.dy - r * 1.75;
      return Path()
        ..moveTo(tip.dx, tip.dy)
        ..cubicTo(
          tip.dx - r * 0.35,
          cy + r * 1.2,
          tip.dx - r,
          cy + r * 0.62,
          tip.dx - r,
          cy,
        )
        ..arcToPoint(Offset(tip.dx + r, cy), radius: Radius.circular(r))
        ..cubicTo(
          tip.dx + r,
          cy + r * 0.62,
          tip.dx + r * 0.35,
          cy + r * 1.2,
          tip.dx,
          tip.dy,
        )
        ..close();
    }

    canvas
      ..save()
      ..scale(s);
    final dash = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final route = Path()
      ..moveTo(30, 90)
      ..quadraticBezierTo(62, 92, 72, 62);
    for (final metric in route.computeMetrics()) {
      var d = 4.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), dash);
        d += 15;
      }
    }
    const origin = Offset(22, 78);
    const destination = Offset(74, 54);
    canvas
      ..drawPath(pin(origin, 16), white)
      ..drawCircle(Offset(origin.dx, origin.dy - 28), 6.5, hole)
      ..drawPath(pin(destination, 18), white)
      ..drawCircle(Offset(destination.dx, destination.dy - 31.5), 7, hole)
      ..restore();
  }

  @override
  bool shouldRepaint(_RouteMarkPainter oldDelegate) => false;
}
