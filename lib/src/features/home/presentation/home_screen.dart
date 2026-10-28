import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animation/motion.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/widgets/section_header.dart';
import 'widgets/featured_map_card.dart';
import 'widgets/home_header.dart';
import 'widgets/micros_strip.dart';
import 'widgets/quick_actions.dart';
import 'widgets/search_results.dart';
import 'widgets/service_card.dart';

/// Pantalla principal: buscador + planificar + servicio de hoy + micros
/// (por color) + mapa.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

    // Las secciones entran en cascada con [Reveal]. Cada fila dirige su propio
    // ticker desde que se monta, así que al salir del modo búsqueda —que
    // remonta la rama— la cascada vuelve a sonar sin código extra.
    return Scaffold(
      body: SafeArea(
        bottom: false,
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
              const Reveal(index: 1, slide: 12, child: QuickActions()),
              const Reveal(index: 2, slide: 12, child: ServiceCard()),
              Reveal(
                index: 3,
                slide: 10,
                child: SectionHeader(
                  'Tus micros',
                  subtitle: 'Cada línea lleva su color',
                  actionLabel: 'Ver todas',
                  onAction: () => UrbanoRoutes.openAllMicros(context, ref),
                ),
              ),
              // La tirilla de micros coloreados; el catálogo completo vive en
              // "Ver todas" (panel de la pestaña Viaje).
              const MicrosStrip(),
              const Reveal(index: 4, slide: 16, child: FeaturedMapCard()),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }
}
