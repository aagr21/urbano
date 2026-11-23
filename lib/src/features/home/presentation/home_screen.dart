import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import 'widgets/destination_bar.dart';
import 'widgets/home_action_tiles.dart';
import 'widgets/home_header.dart';
import 'widgets/recent_trips.dart';

/// Pantalla principal, ordenada como la portada de una app de viajes:
///
/// 1. Banda oficial (escudo del municipio + «Transporte Oficial») y cabecera
///    de marca sobre el lienzo (logo, lema, menú y ubicación).
/// 2. Los cuatro accesos en retícula 2 × 2: Micros · Viajes · Lugares ·
///    Denuncias.
/// 3. La tarjeta «¿A dónde vas?», que abre el planificador.
/// 4. Tus viajes recientes, con el último destino a un toque.
///
/// La portada termina aquí a propósito: el catálogo completo de líneas vive en
/// el panel de Viaje (acceso **Micros**) y el mapa, en la rama Viaje.
///
/// La navegación entre secciones ya no vive en una barra inferior: la lleva el
/// menú de la cabecera, como en la referencia.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canvas = context.colors.surfaceContainerLowest;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Las secciones entran en cascada con [Reveal]. Cada fila dirige su propio
    // ticker desde que se monta, así que la cascada se repite al reabrir Inicio.
    return Scaffold(
      backgroundColor: canvas,
      body: Stack(
        children: [
          // Lienzo de marca: degradado suave desde la orilla y los anillos de
          // Santa Cruz, ahora presentes también bajo los accesos para que la
          // portada no se lea como una lista de tarjetas sobre blanco.
          Positioned.fill(child: _HomeBackdrop(dark: dark)),
          // Contenido principal.
          ListView(
            padding: EdgeInsets.zero,
            children: const [
              Reveal(slide: 8, child: HomeHeader()),
              Reveal(index: 1, slide: 10, child: HomeActionTiles()),
              Reveal(index: 2, slide: 12, child: DestinationBar()),
              // El historial se oculta solo cuando todavía no hay viajes: el
              // hueco que deja es el respiro entre las acciones y el borde.
              Reveal(index: 3, slide: 10, child: RecentTrips()),
              SizedBox(height: AppSpace.lg),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lienzo de la portada: degradado de marca + anillos de la ciudad.
///
/// El degradado baja desde un verde agua muy diluido (la «orilla») hasta el
/// fondo agrupado de la app, así la banda oficial y la marca quedan dentro de
/// una misma atmósfera. Los anillos se anclan abajo a la derecha —como se leen
/// los anillos cruceños desde el norte— y quedan visibles también bajo los
/// accesos y el historial, que es la zona que antes se veía vacía.
class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canvas = colors.surfaceContainerLowest;
    // En oscuro el verde se apaga: sobre grafito un tinte alto se lee como una
    // losa de color, no como atmósfera.
    final shore = AppColors.tint(
      dark ? colors.primary : AppColors.aqua,
      canvas,
      dark ? 0.10 : 0.16,
    );
    final middle = AppColors.tint(colors.primary, canvas, dark ? 0.04 : 0.05);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [shore, middle, canvas, canvas],
          stops: const [0, 0.24, 0.58, 1],
        ),
      ),
      child: CustomPaint(
        painter: _HomeRingsPainter(
          ink: dark ? AppColors.aqua : AppColors.primary,
          glow: dark ? colors.secondary : AppColors.aqua,
          dark: dark,
        ),
      ),
    );
  }
}

/// Anillos concéntricos, paradas y un halo de orilla sobre el lienzo.
///
/// Es decoración estática (el movimiento de la marca ya lo lleva la trama de la
/// cabecera): aquí solo se busca profundidad, por eso todo va a opacidades
/// bajas y el halo se pinta como un radial muy abierto.
class _HomeRingsPainter extends CustomPainter {
  const _HomeRingsPainter({
    required this.ink,
    required this.glow,
    required this.dark,
  });

  final Color ink;
  final Color glow;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Halo de la orilla: arriba a la izquierda, detrás de la marca.
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 0.03),
      size.width * 0.85,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                glow.withValues(alpha: dark ? 0.10 : 0.18),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.12, size.height * 0.03),
                radius: size.width * 0.85,
              ),
            ),
    );

    // Anillos de la ciudad: centro fuera del lienzo, abajo a la derecha.
    final center = Offset(size.width * 1.02, size.height * 0.86);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final baseAlpha = dark ? 0.10 : 0.085;

    for (var i = 0; i < 6; i++) {
      final radius = size.width * (0.34 + i * 0.21);
      ring
        ..color = ink.withValues(alpha: baseAlpha * (1 - i * 0.13))
        ..strokeWidth = i == 2 ? 2.4 : 1.2;
      canvas.drawCircle(center, radius, ring);

      // Paradas: puntos sobre el anillo que lo leen como línea de micro.
      if (i.isEven) {
        for (var s = 0; s < 3; s++) {
          final angle = 3.4 + s * 0.5 + i * 0.08;
          final point = center + Offset.fromDirection(angle, radius);
          canvas.drawCircle(
            point,
            i == 2 ? 2.6 : 2,
            Paint()
              ..color = ink.withValues(
                alpha: (dark ? 0.18 : 0.14) * (1 - i * 0.1),
              ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HomeRingsPainter old) =>
      old.ink != ink || old.glow != glow || old.dark != dark;
}
