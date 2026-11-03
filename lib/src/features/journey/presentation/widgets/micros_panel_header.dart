import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import 'micros_panel_motion.dart';

/// Encabezado del panel: insignia de bus con el degradado de marca (que
/// respira cuando hay recorridos dibujados) + título + subtítulo animado con
/// el conteo.
class MicrosPanelHeader extends StatelessWidget {
  const MicrosPanelHeader({
    super.key,
    required this.lineCount,
    required this.activeCount,
    required this.animation,
  });

  /// Líneas conocidas en el catálogo (subtítulo cuando no hay nada dibujado).
  final int lineCount;

  /// Recorridos (ida/vuelta) dibujados AHORA en el mapa.
  final int activeCount;

  /// Tramo de la entrada del panel que le toca a esta sección.
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final alive = activeCount > 0;
    return microsRise(
      animation,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Row(
          children: [
            _MicrosBadge(alive: alive),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Micros',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _MicrosSubtitle(
                    text: text,
                    colors: colors,
                    activeCount: activeCount,
                    lineCount: lineCount,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Insignia del encabezado: cuadro de marca que se redondea y respira (halo +
/// bus flotando) cuando hay recorridos en el mapa.
class _MicrosBadge extends StatelessWidget {
  const _MicrosBadge({required this.alive});

  final bool alive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // El ícono del bus se arma una sola vez: con recorridos activos entra
    // flotando («hay unidades rodando ahora mismo en el mapa», sin una palabra
    // de más); sin ellos queda quieto y sin ticker.
    final busIcon = Icon(
      Icons.directions_bus_rounded,
      size: 24,
      color: colors.onPrimary,
    );
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Halo que respira bajo la insignia: SOLO con recorridos en el mapa
          // (así el panel entero se ve «encendido»).
          if (alive)
            Positioned.fill(
              child: Ambient(
                period: const Duration(milliseconds: 1900),
                builder: (_, _, phase, _) => Transform.scale(
                  scale: 1 + 0.3 * phase,
                  child: Opacity(
                    opacity: 0.45 * (1 - phase),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: Motion.morph,
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              // Degradado de marca: la insignia deja de ser un cuadro gris y
              // pasa a ser el punto de color del encabezado.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primary,
                  Color.lerp(colors.primary, colors.secondary, 0.8)!,
                ],
              ),
              borderRadius: BorderRadius.circular(
                alive ? AppRadius.md : AppRadius.input,
              ),
              border: Border.all(
                color: colors.onPrimary.withValues(alpha: 0.24),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: alive ? 0.45 : 0.22),
                  blurRadius: alive ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: AnimatedScale(
                duration: Motion.transition,
                curve: Curves.easeOutBack,
                scale: alive ? 1.08 : 1,
                // Con recorridos dibujados el bus flota dentro de su insignia.
                child: alive
                    ? Bob(
                        amplitude: 2.5,
                        period: const Duration(milliseconds: 1500),
                        child: busIcon,
                      )
                    : busIcon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtítulo: conteo de recorridos en el mapa (píldora con punto vivo) o
/// número de líneas disponibles.
class _MicrosSubtitle extends StatelessWidget {
  const _MicrosSubtitle({
    required this.text,
    required this.colors,
    required this.activeCount,
    required this.lineCount,
  });

  final TextTheme text;
  final ColorScheme colors;
  final int activeCount;
  final int lineCount;

  @override
  Widget build(BuildContext context) {
    final alive = activeCount > 0;
    // Mancha del subtítulo «en vivo»: tinte de marca lo bastante suave como
    // para que la tinta calculada encima conserve el contraste de la casa.
    final tintWash = Color.lerp(colors.surface, colors.primary, 0.14)!;
    final liveInk = AppColors.legible(colors.primary, tintWash);
    final subtitle = alive
        ? '$activeCount recorridos en el mapa'
        : '$lineCount líneas · elige ida o vuelta';

    return AnimatedSwitcher(
      duration: Motion.morph,
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.45),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: alive
          // Con recorridos en el mapa el conteo se vuelve una píldora de color
          // con su punto vivo al lado.
          ? Container(
              key: ValueKey(subtitle),
              padding: const EdgeInsets.fromLTRB(6, 2, 9, 2),
              decoration: BoxDecoration(
                color: tintWash,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.32),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiveDot(color: liveInk, size: 6),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: liveInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Text(
              subtitle,
              key: ValueKey(subtitle),
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
    );
  }
}
