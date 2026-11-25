import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routes/data/route_models.dart';
import '../../routes/data/route_repository.dart';
import '../data/journey_models.dart';

/// Clave estable de las líneas que aparecen en una respuesta de `/journey`:
/// ids de los tramos de micro, sin repetir y ordenados, unidos por coma.
///
/// Es un `String` (no una lista) para que el `family` de
/// [journeyLegRoutesProvider] compare por valor: la misma respuesta (o una
/// nueva con las mismas líneas) reutiliza el mismo elemento y no vuelve a
/// pedir nada.
String journeyLegRoutesKey(Iterable<JourneyOption> options) {
  final ids = <String>{
    for (final option in options)
      for (final leg in option.legs)
        if (leg.isBus && (leg.routeId?.isNotEmpty ?? false)) leg.routeId!,
  }.toList()..sort();
  return ids.join(',');
}

/// Ficha de cada línea de un viaje (foto del micro, trayecto, color), por id.
///
/// `/journey` solo trae `routeId`/`routeShortName`/`routeColor` en cada tramo:
/// la foto y el nombre largo viven en `/routes/:id`. Las llamadas van en
/// paralelo y pasan por la caché del repositorio (3 min), así que reabrir los
/// resultados o cambiar de opción no cuesta red. Una línea que falla
/// simplemente no aparece en el mapa devuelto: la tarjeta cae a su placa de
/// color, nunca a un error.
final journeyLegRoutesProvider = FutureProvider.autoDispose
    .family<Map<String, RouteSummary>, String>((ref, key) async {
      if (key.isEmpty) return const {};
      final repository = ref.watch(routeRepositoryProvider);
      final ids = key.split(',');
      final details = await Future.wait(
        ids.map((id) async {
          try {
            return await repository.detail(id);
          } on Object {
            return null;
          }
        }),
      );
      // Se indexa por el id PEDIDO (el del tramo), no por el que devuelve el
      // detalle: es el que la tarjeta tiene a mano para buscar.
      return {for (var i = 0; i < ids.length; i++) ids[i]: ?details[i]};
    });
