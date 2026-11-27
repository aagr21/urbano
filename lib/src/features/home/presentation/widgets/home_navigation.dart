import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/router/app_router.dart';
import '../../../journey/application/journey_planner_controller.dart';
import '../../../journey/presentation/widgets/journey_destination_sheet.dart';
import '../../../nearby/presentation/nearby_search_sheet.dart';

/// Abre la hoja «¿A dónde vas?» con los extremos que tenga el planificador.
///
/// La comparten la tarjeta «Planifica tu viaje» y el acceso **Viajes**: el
/// viaje se arma SOLO desde la portada (ver `showJourneyDestinationSheet`).
Future<void> openJourneyDestinationSheet(BuildContext context, WidgetRef ref) {
  final planner = ref.read(journeyPlannerControllerProvider);
  return showJourneyDestinationSheet(
    context: context,
    ref: ref,
    initialOrigin: planner.origin,
    initialDestination: planner.destination,
  );
}

/// «Lugares»: abre la hoja «¿Qué micro pasa cerca?» y, si el usuario busca,
/// empuja la vista `/nearby`. La comparten el acceso de Inicio y la pestaña
/// Lugares de la barra inferior (que no es una rama: es esta acción).
Future<void> openPlacesSearch(BuildContext context) async {
  final query = await showNearbySearchSheet(context);
  if (query == null || !context.mounted) return;
  await context.push(UrbanoRoutes.nearby(query));
}
