import 'package:flutter/material.dart';

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
/// 3. La barra «¿A dónde vas?», que abre el planificador.
/// 4. Tus viajes recientes, con el último destino a un toque.
///
/// La portada termina aquí a propósito: el banner vivo, la tirilla de micros y
/// el mini mapa se retiraron para que las cuatro piezas de arriba quepan en una
/// sola pantalla, sin scroll. El catálogo completo de líneas vive en el panel
/// de Viaje (acceso **Micros**) y el mapa, en la rama Viaje.
///
/// La navegación entre secciones ya no vive en una barra inferior: la lleva el
/// menú de la cabecera, como en la referencia.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lienzo de la portada: un baño de aqua que baja desde la cabecera y se
    // apaga hacia el historial. Las tarjetas blancas y la barra teñida son las
    // que levantan el contenido; el tinte de fondo es el que hace que Inicio
    // se lea como la portada de marca y no como una lista más. En oscuro el
    // baño es de primario, no de aqua: el tono brillante se vuelve neón.
    final canvas = context.colors.surfaceContainerLowest;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final wash = dark
        ? AppColors.tint(context.colors.primary, canvas, 0.14)
        : AppColors.tint(AppColors.aqua, canvas, 0.15);

    // Las secciones entran en cascada con [Reveal]. Cada fila dirige su propio
    // ticker desde que se monta, así que la cascada se repite al reabrir Inicio.
    return Scaffold(
      backgroundColor: canvas,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [wash, AppColors.tint(wash, canvas, 0.55), canvas],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: ListView(
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
      ),
    );
  }
}
