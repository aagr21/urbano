import 'package:flutter/material.dart';

import '../animation/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/extensions.dart';

/// Bloque con shimmer de **barrido** (placeholder de carga).
///
/// En vez de un pulso de opacidad (el mismo gris parpadeando, que se lee como
/// "espera muerta"), un destello tintado con aqua de marca recorre el bloque
/// en diagonal: la espera se lee «está pasando algo», igual que los
/// esqueletos de iOS. El destello sale y entra por los bordes, así el
/// `repeat()` del bucle no tiene salto visible. El controlador propio es la
/// excepción sancionada del kit (sin `flutter_animate`) y con «reducir
/// animaciones» del sistema el bloque queda estático, sin barrido.
class LoadingShimmer extends StatefulWidget {
  const LoadingShimmer({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
    this.child,
  });

  final double? width;
  final double height;
  final double radius;
  final Widget? child;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `MediaQuery` no se puede leer en `initState`; además el bucle se arranca
    // una sola vez para no reiniciar la fase en cada re-layout.
    if (_started) return;
    _started = true;
    if (!Motion.reduced(context)) {
      _controller.repeat();
    } else {
      // Destello clavado al centro: bloque estático con el mismo tinte, sin
      // barrido ni parpadeo.
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = colors.surfaceContainerHighest;
    final tint = isDark ? AppColors.aquaSoftDark : AppColors.aqua;
    final highlight = Color.lerp(base, tint, 0.28)!;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // El destello viaja de fuera-del-borde-izquierdo a
            // fuera-del-borde-derecho; en `t = 0` y `t = 1` el bloque se pinta
            // entero con el color base, así el reinicio del bucle es invisible.
            final cx = -1.6 + 3.2 * _controller.value;
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(cx - 0.6, -0.25),
                  end: Alignment(cx + 0.6, 0.25),
                  colors: [base, highlight, base],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}

/// Esqueleto de tarjeta genérica (listas de rutas/paradas).
///
/// Mismo lenguaje que las tarjetas reales: superficie plana, sin bordes —
/// la separación la da el fondo del canvas, no un contorno que la app no usa.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.leading = 44});

  final double leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          LoadingShimmer(
            width: leading,
            height: leading,
            radius: AppRadius.input,
          ),
          const SizedBox(width: AppSpace.lg),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingShimmer(width: double.infinity, height: 14),
                SizedBox(height: AppSpace.sm),
                LoadingShimmer(width: 140, height: 12),
                SizedBox(height: AppSpace.xs + 2),
                LoadingShimmer(width: 90, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de esqueletos para estados de carga.
///
/// Usa un [ListView] con `shrinkWrap` en vez de un `Column`: así se adapta
/// al espacio real del padre (Expanded, body del Scaffold o dentro de otra
/// lista) y **nunca** produce "bottom overflowed" cuando no caben las tarjetas.
///
/// Cada tarjeta entra con [Reveal] escalonado por posición: el esqueleto no
/// aparece de golpe, y al llegar el dato real la transición carga→contenido
/// conserva la misma coreografía (la lista real también entra en cascada).
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 6,
    this.spacing = AppSpace.md,
    this.leading = 44,
    this.padding = const EdgeInsets.all(AppSpace.lg),
  });

  final int count;
  final double spacing;
  final double leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(top: index == 0 ? 0 : spacing),
        child: Reveal(
          index: index,
          slide: 8,
          child: SkeletonCard(leading: leading),
        ),
      ),
    );
  }
}
