import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_shimmer.dart';
import 'route_providers.dart';
import 'widgets/route_full_map.dart';
import 'widgets/route_map_chrome.dart';

/// Mapa de **un sentido** del recorrido, abierto desde «Recorrido completo».
///
/// La pantalla carga el detalle del sentido pedido (el backend devuelve la
/// polilínea de ese `directionId`) y lo entrega a [RouteFullMap], que pinta el
/// trazado a sangre **sin header**: la flecha y la placa de identidad flotan
/// sobre el mapa. La carga y el error conservan esa misma salida flotante para
/// que el gesto de volver nunca desaparezca.
class RouteDirectionMapScreen extends ConsumerWidget {
  const RouteDirectionMapScreen({
    super.key,
    required this.routeId,
    required this.directionId,
  });

  final String routeId;
  final int directionId;

  String get _label => directionId == 0 ? 'ida' : 'vuelta';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = RouteKey(routeId, directionId: directionId);
    final detail = ref.watch(routeDetailProvider(key));

    return detail.when(
      loading: () => Scaffold(
        backgroundColor: context.colors.surfaceContainerHighest,
        body: const Stack(
          fit: StackFit.expand,
          children: [SkeletonList(count: 4), _FloatingBack()],
        ),
      ),
      error: (error, _) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: ErrorView(
                error: error,
                onRetry: () => ref.invalidate(routeDetailProvider(key)),
              ),
            ),
            const _FloatingBack(),
          ],
        ),
      ),
      data: (detail) => RouteFullMap(
        detail: detail,
        routeColor: AppColors.fromHex(detail.color),
        routeKey: key,
        directionLabel: _label,
      ),
    );
  }
}

/// Salida flotante de los estados de carga/error del mapa a sangre.
class _FloatingBack extends StatelessWidget {
  const _FloatingBack();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(AppSpace.md),
          child: MapFloatingBack(),
        ),
      ),
    );
  }
}
