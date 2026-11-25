import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/complaints/presentation/complaints_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/journey/presentation/journey_planner_screen.dart';
import '../../features/journey/presentation/map_picker_screen.dart';
import '../../features/nearby/domain/nearby_micros.dart';
import '../../features/nearby/presentation/nearby_micros_screen.dart';
import '../../features/routes/presentation/micros_screen.dart';
import '../../features/routes/presentation/route_detail_screen.dart';
import '../../features/routes/presentation/route_direction_map_screen.dart';
import '../animation/motion.dart';
import '../widgets/empty_state.dart';

/// Router central de Urbano.
final appRouterProvider = Provider<GoRouter>((_) => _router);

GoRouter get _router => GoRouter(
  initialLocation: '/',
  // La pestaña "Mapa" se fusionó con "Viaje": `/map` redirige por
  // seguridad a la pantalla-mapa única. El catálogo completo de líneas vive
  // ahora en `/micros` (pantalla propia, no en el panel de Viaje) y el detalle
  // en `/routes/:id`; el mapa de un sentido se abre en `/routes/:id/map`.
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
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/complaints',
              name: 'complaints',
              builder: (context, state) => const ComplaintsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/micros',
      name: 'micros',
      builder: (context, state) => const MicrosScreen(),
    ),
    // Antes que `/routes/:id`: el mapa de un sentido es una pantalla propia
    // (ida/vuelta) que se empuja desde el detalle.
    GoRoute(
      path: '/routes/:id/map',
      name: 'route-map',
      builder: (context, state) {
        final direction =
            int.tryParse(state.uri.queryParameters['direction'] ?? '') ?? 0;
        return RouteDirectionMapScreen(
          routeId: state.pathParameters['id'] ?? '',
          directionId: direction,
        );
      },
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
    // «Micros cerca»: líneas que pasan cerca de un punto (acceso Lugares).
    // Pantalla propia a sangre, encima del shell; la consulta viaja en la URL.
    GoRoute(
      path: '/nearby',
      name: 'nearby',
      builder: (context, state) {
        final query = NearbyQuery.fromParams(state.uri.queryParameters);
        if (query == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.wrong_location_outlined,
              title: 'Falta el punto',
              message: 'Elige un lugar desde Lugares para ver los micros.',
            ),
          );
        }
        return NearbyMicrosScreen(query: query);
      },
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

/// Navegador del shell (Inicio · Viaje · Denuncias) **sin barra inferior**.
///
/// El rediseño de la portada se parece al de una app de viajes: logo, ubicación
/// y accesos arriba. Se llega a Viaje y Denuncias por los accesos de Inicio y se
/// vuelve con la flecha de Viaje o con «atrás». Las tres ramas siguen montadas
/// como antes
/// (`StatefulShellRoute.indexedStack`), así el mapa del planner nunca se
/// reconstruye al cambiar de sección.
class UrbanoShell extends ConsumerWidget {
  const UrbanoShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Atrás del sistema en las ramas de Viaje/Denuncias: vuelve a Inicio en
    // vez de cerrar la app. Inicio conserva el comportamiento nativo (salir),
    // porque es la raíz y no tiene a dónde retroceder.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || shell.currentIndex == 0) return;
        context.go('/');
      },
      child: Scaffold(
        body: _TabSwitch(index: shell.currentIndex, child: shell),
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

  /// Abre el **catálogo completo de micros** en su propia pantalla.
  static void openMicrosCatalog(BuildContext context) {
    context.push('/micros');
  }

  static String routeDetail(String routeId, {String? from}) {
    final path = '/routes/${Uri.encodeComponent(routeId)}';
    return from == null ? path : '$path?from=${Uri.encodeComponent(from)}';
  }

  /// «Micros cerca» de un punto (la consulta completa viaja en la URL).
  static String nearby(NearbyQuery query) =>
      Uri(path: '/nearby', queryParameters: query.toParams()).toString();

  /// Mapa de un sentido concreto del recorrido (`0` = ida, `1` = vuelta).
  static String routeMap(String routeId, {required int directionId}) =>
      '/routes/${Uri.encodeComponent(routeId)}/map?direction=$directionId';
}
