import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../data/route_models.dart';

/// Tarjeta de una línea — estilo de micros.html.
///
/// Badge cuadrado con color GTFS, nombre de línea, píldora de frecuencia,
/// botón de favorito, mini micro SVG, extremos de ruta, paradas clave
/// y botón "Ver recorrido".
class MicroCard extends StatelessWidget {
  const MicroCard({super.key, required this.route, required this.onTap});

  final RouteSummary route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.fromHex(route.color);
    final stripe = AppColors.legible(
      accent,
      dark ? HtmlDesignTokens.slate800 : HtmlDesignTokens.white,
    );
    final hairline = dark
        ? HtmlDesignTokens.slate700
        : HtmlDesignTokens.slate200.withValues(alpha: 0.7);

    return PressScale(
      scale: 0.99,
      child: Container(
        decoration: BoxDecoration(
          color: dark ? HtmlDesignTokens.slate800 : HtmlDesignTokens.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: hairline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Stack(
              children: [
                // Left colored stripe
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: stripe,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(AppRadius.xl),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    AppSpace.md,
                    AppSpace.md,
                    AppSpace.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: frequency + favorite
                      Row(
                        children: [
                          // Frequency pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: HtmlDesignTokens.emerald50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: HtmlDesignTokens.emerald100,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: HtmlDesignTokens.emerald500,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'En frecuencia',
                                  style: text.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: HtmlDesignTokens.emerald700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Favorite button
                          Icon(
                            Icons.star_border_rounded,
                            size: 18,
                            color: dark
                                ? HtmlDesignTokens.slate500
                                : HtmlDesignTokens.slate300,
                          ),
                        ],
                      ),
                      const Divider(
                        height: 16,
                        color: HtmlDesignTokens.slate100,
                      ),
                      // Body: mini bus + endpoints + key stops
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mini bus illustration
                          Container(
                            width: 64,
                            height: 56,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.tint(
                                accent,
                                dark
                                    ? HtmlDesignTokens.slate700
                                    : HtmlDesignTokens.slate50,
                                0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.tint(
                                  accent,
                                  dark
                                      ? HtmlDesignTokens.slate600
                                      : HtmlDesignTokens.slate200,
                                  0.5,
                                ),
                              ),
                            ),
                            child: Center(child: _MiniBusSvg(color: accent)),
                          ),
                          const SizedBox(width: 14),
                          // Endpoints + key stops
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Endpoints
                                if (route.longName.isNotEmpty)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          route.longName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: text.labelMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: dark
                                                ? HtmlDesignTokens.slate200
                                                : HtmlDesignTokens.slate800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 6),
                                // Extremos de ruta: origen → destino
                                // (mismo formato que el detalle del recorrido)
                                if (route.keyStops != null &&
                                    route.keyStops!.length >= 2)
                                  Row(
                                    children: [
                                      // Origen
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.tint(
                                              accent,
                                              dark
                                                  ? HtmlDesignTokens.slate700
                                                  : HtmlDesignTokens.slate50,
                                              0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.pill,
                                            ),
                                            border: Border.all(
                                              color: AppColors.tint(
                                                accent,
                                                dark
                                                    ? HtmlDesignTokens.slate600
                                                    : HtmlDesignTokens.slate200,
                                                0.35,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.trip_origin_rounded,
                                                size: 14,
                                                color: accent,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  _shortStopName(
                                                    route.keyStops!.first,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: text.labelSmall
                                                      ?.copyWith(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: dark
                                                            ? HtmlDesignTokens
                                                                  .slate200
                                                            : HtmlDesignTokens
                                                                  .slate700,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Flecha de avance
                                      Icon(
                                        Icons.double_arrow_rounded,
                                        size: 16,
                                        color: accent.withValues(alpha: 0.55),
                                      ),
                                      const SizedBox(width: 6),
                                      // Destino
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.tint(
                                              accent,
                                              dark
                                                  ? HtmlDesignTokens.slate700
                                                  : HtmlDesignTokens.slate50,
                                              0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.pill,
                                            ),
                                            border: Border.all(
                                              color: AppColors.tint(
                                                accent,
                                                dark
                                                    ? HtmlDesignTokens.slate600
                                                    : HtmlDesignTokens.slate200,
                                                0.35,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons
                                                    .location_searching_rounded,
                                                size: 14,
                                                color: accent,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  _shortStopName(
                                                    route.keyStops!.last,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: text.labelSmall
                                                      ?.copyWith(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: dark
                                                            ? HtmlDesignTokens
                                                                  .slate200
                                                            : HtmlDesignTokens
                                                                  .slate700,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(
                        height: 1,
                        color: HtmlDesignTokens.slate100,
                      ),
                      const SizedBox(height: 10),
                      // Footer: ida/vuelta pill + "Ver recorrido"
                      Row(
                        children: [
                          // Ida y vuelta pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: HtmlDesignTokens.slate100.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 14,
                                  color: HtmlDesignTokens.slate400,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Ida y vuelta',
                                  style: text.labelSmall?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: HtmlDesignTokens.slate500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // "Ver recorrido" button
                          PressScale(
                            scale: 0.97,
                            child: InkWell(
                              onTap: onTap,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: HtmlDesignTokens.emerald50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Ver recorrido',
                                      style: text.labelSmall?.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: HtmlDesignTokens.emerald700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '→',
                                      style: text.labelSmall?.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: HtmlDesignTokens.emerald700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Acorta nombres largos de paradas extrayendo el tramo principal
  /// (equivalente al `_street()` del detalle del recorrido).
  static String _shortStopName(String name) {
    if (name.isEmpty) return name;
    // "Avenida Los Pinos esquina Calle Las Palmeras" → "Av. Los Pinos"
    // "Calle El Nogal esquina Calle Los Sauces" → "Calle El Nogal"
    final parts = name.split(' esquina ');
    if (parts.length >= 2) return parts[0];
    // Truncar si sigue muy largo
    if (name.length > 30) {
      final words = name.split(' ');
      if (words.length > 3) return '${words.take(3).join(' ')}…';
    }
    return name;
  }
}

/// Mini micro SVG simplificado para las tarjetas de ruta.
class _MiniBusSvg extends StatelessWidget {
  const _MiniBusSvg({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final glass = AppColors.onColor(color);
    return SizedBox(
      width: 48,
      height: 26,
      child: CustomPaint(
        painter: _MiniBusPainter(
          body: color,
          glass: glass,
          wheel: Color.lerp(color, AppColors.ink, 0.78)!,
        ),
      ),
    );
  }
}

class _MiniBusPainter extends CustomPainter {
  const _MiniBusPainter({
    required this.body,
    required this.glass,
    required this.wheel,
  });

  final Color body;
  final Color glass;
  final Color wheel;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 44;
    canvas.scale(s, s);

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, 38, 17),
        const Radius.circular(3),
      ),
      Paint()..color = body,
    );

    // Windows
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 6, 5),
        const Radius.circular(1),
      ),
      Paint()..color = glass.withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 4, 5, 5),
        const Radius.circular(1),
      ),
      Paint()..color = glass.withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(19, 4, 5, 5),
        const Radius.circular(1),
      ),
      Paint()..color = glass.withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 4, 5, 5),
        const Radius.circular(1),
      ),
      Paint()..color = glass.withValues(alpha: 0.9),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(33, 4, 5, 5),
        const Radius.circular(1),
      ),
      Paint()..color = glass.withValues(alpha: 0.9),
    );

    // Stripe
    canvas.drawRect(
      const Rect.fromLTWH(2, 11, 38, 3),
      Paint()..color = wheel.withValues(alpha: 0.18),
    );

    // Headlight
    canvas.drawCircle(
      const Offset(4, 15),
      1,
      Paint()..color = HtmlDesignTokens.amber200,
    );
    // Taillight
    canvas.drawCircle(
      const Offset(38, 15),
      1,
      Paint()..color = HtmlDesignTokens.red500,
    );

    // Wheels
    canvas.drawCircle(const Offset(10, 19), 3, Paint()..color = wheel);
    canvas.drawCircle(
      const Offset(10, 19),
      1.2,
      Paint()..color = glass.withValues(alpha: 0.85),
    );
    canvas.drawCircle(const Offset(32, 19), 3, Paint()..color = wheel);
    canvas.drawCircle(
      const Offset(32, 19),
      1.2,
      Paint()..color = glass.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_MiniBusPainter old) =>
      old.body != body || old.glass != glass || old.wheel != wheel;
}
