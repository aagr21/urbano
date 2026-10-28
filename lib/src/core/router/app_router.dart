import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/info/presentation/info_screen.dart';
import '../../features/journey/presentation/journey_planner_screen.dart';
import '../../features/journey/presentation/journey_providers.dart';
import '../../features/journey/presentation/map_picker_screen.dart';
import '../../features/routes/presentation/route_detail_screen.dart';
import '../animation/motion.dart';
import '../widgets/empty_state.dart';

/// Router central de Urbano.
final appRouterProvider = Provider<GoRouter>((_) => _router);

GoRouter get _router => GoRouter(
  initialLocation: '/',
  // La pestaña "Mapa" se fusionó con "Viaje": `/map` redirige por
  // seguridad a la pantalla-mapa única. La pestaña "Rutas" se retiró:
  // el listado de micros con direcciones ida/vuelta vive en el panel
  // izquierdo de `/journey`; `/routes/:id` (detalle) se conserva para
  // los accesos del home.
  redirect: (context, state) =>
      state.matchedLocation == '/map' ? '/journey' : null,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => UrbanoShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/journey',
              name: 'journey',
              builder: (context, state) => const JourneyPlannerScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/routes/:id',
      name: 'route-detail',
      builder: (context, state) => RouteDetailScreen(
        routeId: state.pathParameters['id'] ?? '',
        // El prefijo del Hero viaja en la URL: el badge de la lista a la que se
        // entró es el que vuela hasta la AppBar (`?from=home` ↔ `home-<id>`).
        heroPrefix: state.uri.queryParameters['from'] ?? 'routes',
      ),
    ),
    GoRoute(
      path: '/journey/pick',
      name: 'journey-pick',
      builder: (context, state) {
        final params = state.uri.queryParameters;
        final lat = double.tryParse(params['lat'] ?? '');
        final lon = double.tryParse(params['lon'] ?? '');
        return MapPickerScreen(
          title: params['title'] ?? 'Punto en el mapa',
          initial: lat != null && lon != null ? (lat: lat, lon: lon) : null,
        );
      },
    ),
    GoRoute(
      path: '/info',
      name: 'info',
      builder: (context, state) => const InfoScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Urbano')),
    body: EmptyState(
      icon: Icons.route_rounded,
      title: 'Pantalla no encontrada',
      message: 'La ruta "${state.uri.toString()}" no existe.',
      actionLabel: 'Volver al inicio',
      onAction: () => context.go('/'),
    ),
  ),
);

/// Navegador con barra inferior de 2 secciones (Inicio · Viaje).
/// La pestaña "Cerca" (paradas cercanas) se retiró junto con las paradas, y
/// la pestaña "Rutas" se fusionó en el panel de micros de `/journey`.
class UrbanoShell extends ConsumerWidget {
  const UrbanoShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  /// Índice de la pestaña Viaje dentro del shell (branches: Inicio · Viaje).
  static const _journeyTabIndex = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // En pantalla completa del mapa (solo en la pestaña Viaje) se esconde la
    // barra inferior: el provider vive compartido con la pantalla del planner.
    final fullscreen =
        shell.currentIndex == _journeyTabIndex &&
        ref.watch(mapFullscreenProvider);
    return Scaffold(
      body: _TabSwitch(index: shell.currentIndex, child: shell),
      bottomNavigationBar: fullscreen
          ? null
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_horiz_rounded),
                  selectedIcon: Icon(Icons.swap_horiz_rounded),
                  label: 'Viaje',
                ),
              ],
            ),
    );
  }
}

/// Fundido corto al cambiar de pestaña.
///
/// El `IndexedStack` que arma `StatefulShellRoute.indexedStack` intercambia la
/// rama visible de inmediato y **no se puede sustituir**: es lo que mantiene el
/// mapa montado entre Inicio y Viaje. Por eso la transición no toca el árbol de
/// las ramas (nada se remonta ni se reconstruye): se anima el cuerpo completo
/// cuando cambia [index], que es justo el frame en que el `IndexedStack` ya
/// muestra la otra pantalla.
class _TabSwitch extends StatefulWidget {
  const _TabSwitch({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TabSwitch> createState() => _TabSwitchState();
}

class _TabSwitchState extends State<_TabSwitch>
    with SingleTickerProviderStateMixin {
  /// Nace en 1: la primera pestaña no debe animar, eso ya lo hace la
  /// transición de página.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.base,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _TabSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    // Con «reducir animaciones» el cuerpo se queda en 1: cambio seco.
    if (Motion.reduced(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Motion.entrance);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Helpers de navegación con ids codificados (contienen espacios).
class UrbanoRoutes {
  UrbanoRoutes._();

  /// Lleva al usuario al **panel de micros de Viaje**, el listado completo de
  /// líneas (la antigua ruta `/routes` desapareció al fusionar la pestaña
  /// «Rutas» en `/journey`: apuntar ahí caía en el `errorBuilder`).
  ///
  /// Se cambia de rama primero y el panel se abre después: la bandera se
  /// consume en el `build` del planeador, de modo que el cajón nunca se
  /// superpone al home.
  static void openAllMicros(BuildContext context, WidgetRef ref) {
    ref.read(pendingMicrosPanelProvider.notifier).state = true;
    context.go('/journey');
  }

  static String routeDetail(String routeId, {String? from}) {
    final path = '/routes/${Uri.encodeComponent(routeId)}';
    return from == null ? path : '$path?from=${Uri.encodeComponent(from)}';
  }
}
