import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/motion.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/section_header.dart';
import 'widgets/featured_map_card.dart';
import 'widgets/home_header.dart';
import 'widgets/micros_strip.dart';
import 'widgets/quick_actions.dart';
import 'widgets/search_results.dart';
import 'widgets/service_card.dart';

/// Pantalla principal: buscador + planificar + servicio de hoy + micros
/// (por color) + mapa.
///
/// La página se lee como **una sola pieza de marca**: la portada verde entra a
/// sangre, la tarjeta de Viajar monta sobre su pie, el lienzo sigue teñido de
/// verde agua y la tirilla de micros vive en su propia banda. Antes eran cuatro
/// bloques sueltos flotando sobre un gris plano, que es lo que la hacía ver
/// apagada.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Cuánto monta la tarjeta de Viajar sobre el pie de la portada. El hueco se
  /// descuenta después con un `SizedBox`: el `Transform` mueve el dibujo, no la
  /// caja del layout.
  static const double _ctaOverlap = AppSpace.lg;

  final _controller = TextEditingController();
  final _debouncer = Debouncer();

  /// Query ya debounced que dispara la búsqueda.
  String _activeQuery = '';
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final text = _controller.text;
    final hasText = text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    _debouncer.run(() {
      if (!mounted) return;
      setState(() => _activeQuery = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final searching = _activeQuery.isNotEmpty;
    final colors = context.colors;
    final canvas = colors.surfaceContainerLowest;

    // Las secciones entran en cascada con [Reveal]. Cada fila dirige su propio
    // ticker desde que se monta, así que al salir del modo búsqueda —que
    // remonta la rama— la cascada vuelve a sonar sin código extra.
    return Scaffold(
      // Lienzo teñido: la marca se prolonga por debajo de la portada y se apaga
      // hacia el final, en vez de cortar contra un gris uniforme.
      backgroundColor: canvas,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.tint(colors.primary, canvas, 0.1),
              canvas,
              canvas,
            ],
            stops: const [0, 0.42, 1],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Reveal(slide: 8, child: HomeHeader(controller: _controller)),
            if (searching)
              Reveal(
                // Cambiar de consulta remonta los resultados: entran otra vez.
                key: ValueKey('search-$_activeQuery'),
                index: 1,
                slide: 10,
                child: SearchResults(query: _activeQuery),
              )
            else ...[
              // Monta sobre el pie de la portada: la acción principal sale de
              // la marca, no flota en el lienzo.
              Transform.translate(
                offset: const Offset(0, -_ctaOverlap),
                child: const Reveal(index: 1, slide: 12, child: QuickActions()),
              ),
              // El hueco del layout ya gastó `_ctaOverlap` en la parte que la
              // tarjeta monta: se le devuelve para que el aire real sean 24 px.
              const SizedBox(height: AppSpace.sm),
              const Reveal(index: 2, slide: 12, child: ServiceCard()),
              const Reveal(index: 3, slide: 10, child: _MicrosSection()),
              const SizedBox(height: AppSpace.xl),
              const Reveal(index: 4, slide: 16, child: FeaturedMapCard()),
              const SizedBox(height: AppSpace.xxl),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sección "Tus micros": encabezado + tirilla dentro de **una banda teñida**.
///
/// Antes el título flotaba sobre el lienzo y la tirilla caía debajo como algo
/// aparte. La banda (verde agua al 7 % con filos de marca) las une y hace que el
/// ojo lea un bloque, no dos piezas sueltas.
class _MicrosSection extends ConsumerWidget {
  const _MicrosSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final fill = AppColors.tint(
      colors.primary,
      colors.surfaceContainerLowest,
      0.09,
    );
    final edge = AppColors.tint(colors.primary, colors.outlineVariant, 0.55);
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.xl),
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.lg),
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          top: BorderSide(color: edge),
          bottom: BorderSide(color: edge),
        ),
      ),
      child: Column(
        children: [
          SectionHeader(
            'Tus micros',
            subtitle: 'Cada línea lleva su color',
            actionLabel: 'Ver todas',
            onAction: () => UrbanoRoutes.openAllMicros(context, ref),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.md,
            ),
          ),
          // La tirilla conserva su alto y su padding horizontal: la banda es
          // full-bleed para que el carrusel se corte en el borde de la pantalla.
          const MicrosStrip(),
        ],
      ),
    );
  }
}
