import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routes/data/route_models.dart';
import '../../routes/data/route_repository.dart';
import '../data/complaint_repository.dart';
import 'passenger_controller.dart';

/// Catálogo completo de micros (se paginas), usado para poner nombre y color a
/// la línea de cada queja. Se carga una vez y se comparte entre feed y detalle.
final complaintRoutesProvider = FutureProvider<List<RouteSummary>>((ref) async {
  final repository = ref.watch(routeRepositoryProvider);
  const pageSize = 100;
  final allRoutes = <RouteSummary>[];
  var page = 1;
  var total = 0;
  do {
    final result = await repository.list(page: page, limit: pageSize);
    allRoutes.addAll(result.items);
    total = result.meta.safeTotal;
    page++;
  } while (allRoutes.length < total && allRoutes.isNotEmpty);
  return allRoutes;
});

/// Etiquetas e íconos según la categoría GTFS de la queja.
String categoryLabelOf(String category) => switch (category) {
  'vehicle' => 'Estado del micro',
  'driver_treatment' => 'Trato del conductor',
  'route_deviation' => 'Desvío de ruta',
  'schedule' => 'Frecuencia u horario',
  'safety' => 'Seguridad',
  _ => 'Otro reporte',
};

IconData categoryIconOf(String category) => switch (category) {
  'vehicle' => Icons.directions_bus_rounded,
  'driver_treatment' => Icons.person_rounded,
  'route_deviation' => Icons.alt_route_rounded,
  'schedule' => Icons.schedule_rounded,
  'safety' => Icons.shield_rounded,
  _ => Icons.more_horiz_rounded,
};

/// Tiempo relativo corto ("Hace 5 min"), reutilizado por tarjeta y detalle.
String relativeDateLabel(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return 'Ahora';
  if (difference.inHours < 1) return 'Hace ${difference.inMinutes} min';
  if (difference.inDays < 1) return 'Hace ${difference.inHours} h';
  return 'Hace ${difference.inDays} d';
}

/// Orden estable de los motivos en el filtro del feed (el mismo del formulario).
const List<String> complaintCategoryOrder = [
  'vehicle',
  'driver_treatment',
  'route_deviation',
  'schedule',
  'safety',
  'other',
];

/// Motivo elegido en el filtro del feed; `null` = todos.
///
/// Es provider y no `State` de la pantalla: al volver del detalle de una queja
/// el filtro sigue puesto (y se comparte con quien abra el feed desde otro
/// sitio), igual que la sesión del panel de micros.
final complaintCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Reportes con al menos una queja, en el orden de [complaintCategoryOrder].
///
/// El filtro solo ofrece motivos que existen: una fila de chips gris con
/// "Seguridad (0)" es ruido, no información.
final reportedCategoriesProvider = Provider<List<String>>((ref) {
  final items =
      ref.watch(complaintsFeedProvider).valueOrNull ??
      const <ComplaintSummary>[];
  return [
    for (final category in complaintCategoryOrder)
      if (items.any((item) => item.category == category)) category,
  ];
});

/// Feed ya filtrado por motivo, conservando carga y error.
///
/// Se deriva aquí para que la pantalla solo pinte: `AsyncListView` recibe este
/// valor y no necesita `itemCount`, porque su longitud es la de lo visible.
final visibleComplaintsProvider = Provider<AsyncValue<List<ComplaintSummary>>>((
  ref,
) {
  final feed = ref.watch(complaintsFeedProvider);
  final filter = ref.watch(complaintCategoryFilterProvider);
  if (filter == null) return feed;
  return switch (feed) {
    AsyncData(:final value) => AsyncData(
      value.where((item) => item.category == filter).toList(growable: false),
    ),
    _ => feed,
  };
});

/// Cifras de la comunidad (reportes, apoyos, comentarios) para la cabecera.
///
/// Siempre sobre el feed COMPLETO: el filtro cambia lo que se lista, no lo que
/// la comunidad ha dicho.
final complaintsStatsProvider =
    Provider<({int reports, int supports, int comments})>((ref) {
      final items =
          ref.watch(complaintsFeedProvider).valueOrNull ??
          const <ComplaintSummary>[];
      return (
        reports: items.length,
        supports: items.fold(0, (sum, item) => sum + item.likeCount),
        comments: items.fold(0, (sum, item) => sum + item.commentCount),
      );
    });

/// Estado del feed de quejas con interacciones sociales. Compartido entre la
/// pantalla de lista y el detalle, así un like o un comentario hecho en
/// cualquiera de las dos actualiza los contadores de la otra sin recargar.
class ComplaintsFeedController extends AsyncNotifier<List<ComplaintSummary>> {
  /// Quejas con una llamada de «apoyo» en vuelo. Sirve para ignorar toques
  /// repetidos sobre la misma queja mientras el servidor responde: sin esto, un
  /// doble toque rápido aplicaba DOS +1 optimistas y el contador «saltaba» a 2.
  final Set<String> _pendingLikes = <String>{};

  @override
  Future<List<ComplaintSummary>> build() async {
    // `read` (no `watch`): cambiar el apodo no debe volver a pedir el feed; la
    // clave de dispositivo es estable y es lo único que influye en `likedByMe`.
    final identity = await ref.read(passengerControllerProvider.future);
    return ref
        .read(complaintRepositoryProvider)
        .list(deviceKey: identity.deviceKey);
  }

  Future<void> reload() async {
    // El RefreshIndicator ya muestra su spinner y `AsyncListView` conserva los
    // datos antiguos mientras llega la respuesta, así que no hace falta pasar
    // por un estado de carga que volvería a pintar el esqueleto de toda la lista.
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<ComplaintSummary>> _fetch() async {
    final identity = await ref.read(passengerControllerProvider.future);
    return ref
        .read(complaintRepositoryProvider)
        .list(deviceKey: identity.deviceKey);
  }

  /// Alterna el «apoyo» de forma optimista (el corazón responde al toque) y
  /// consolida con el contador que devuelve el servidor. Si la llamada falla,
  /// revierte el cambio. Se apoya siempre en el item VIVO del feed (no en la
  /// referencia posiblemente anticuada que llegó del build) y bloquea toques
  /// concurrentes sobre la misma queja para no inflar el contador.
  Future<void> toggleLike(ComplaintSummary complaint) async {
    final live =
        state.valueOrNull?.firstWhere(
          (item) => item.id == complaint.id,
          orElse: () => complaint,
        ) ??
        complaint;
    // Contención y marcado sincrónicos (no hay `await` entre ellos), así dos
    // toques en el mismo frame no pasan los dos la barrera.
    if (_pendingLikes.contains(live.id)) return;
    _pendingLikes.add(live.id);

    final identity = await ref.read(passengerControllerProvider.future);
    final wasLiked = live.likedByMe;
    final nextLiked = !wasLiked;
    _patch(
      live.id,
      (item) => item.copyWith(
        likedByMe: nextLiked,
        likeCount: (item.likeCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 31),
      ),
    );
    try {
      final likeCount = await ref
          .read(complaintRepositoryProvider)
          .setLiked(
            complaintId: live.id,
            deviceKey: identity.deviceKey,
            liked: nextLiked,
          );
      _patch(
        live.id,
        (item) => item.copyWith(likeCount: likeCount, likedByMe: nextLiked),
      );
    } catch (_) {
      _patch(
        live.id,
        (item) => item.copyWith(likedByMe: wasLiked, likeCount: live.likeCount),
      );
      rethrow;
    } finally {
      _pendingLikes.remove(live.id);
    }
  }

  /// Suma un comentario al contador tras publicarlo en el detalle.
  void registerComment(String complaintId) {
    _patch(
      complaintId,
      (item) => item.copyWith(commentCount: item.commentCount + 1),
    );
  }

  void _patch(
    String id,
    ComplaintSummary Function(ComplaintSummary item) transform,
  ) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final item in current) item.id == id ? transform(item) : item,
    ]);
  }
}

final complaintsFeedProvider =
    AsyncNotifierProvider<ComplaintsFeedController, List<ComplaintSummary>>(
      ComplaintsFeedController.new,
    );
