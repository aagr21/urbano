import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../routes/data/route_models.dart';
import '../../routes/data/route_repository.dart';
import '../data/complaint_repository.dart';
import '../domain/complaint_models.dart';
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

/// Nombre largo de la línea sin repetir su número (`Micro 12 San Juan` →
/// `San Juan`).
///
/// La tarjeta y el detalle ya muestran `Micro 12` en el título, así que repetir
/// el prefijo en la segunda línea no aporta nada: lo que el pasajero necesita
/// es el recorrido. Devuelve `null` cuando no queda nada útil.
String? routeSubtitleOf(RouteSummary? route) {
  final long = route?.longName.trim() ?? '';
  if (long.isEmpty) return null;
  final short = route!.shortName.trim();
  var text = long;
  if (short.isNotEmpty) {
    text = text.replaceFirst(
      RegExp(
        '^micro\\s*${RegExp.escape(short)}\\b[\\s·-]*',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceFirst(
      RegExp('^${RegExp.escape(short)}\\b[\\s·-]*', caseSensitive: false),
      '',
    );
  }
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

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

/// Cómo se ordena el feed. Las tres cifras de la portada (reportes · apoyos ·
/// comentarios) son también sus tres botones.
enum ComplaintSort {
  /// Lo último primero (el orden del servidor).
  recent('Más recientes', Icons.schedule_rounded),

  /// Lo que más respaldó la comunidad.
  supported('Más apoyadas', Icons.favorite_rounded),

  /// Donde hay conversación.
  discussed('Más comentadas', Icons.chat_bubble_rounded);

  const ComplaintSort(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Orden elegido del feed. Provider (no `State`) por lo mismo que el filtro:
/// sobrevive a abrir y cerrar el detalle.
final complaintSortProvider = StateProvider<ComplaintSort>(
  (ref) => ComplaintSort.recent,
);

/// Ordena [items] según [sort] sin tocar la lista original. Estable: a igual
/// cifra se conserva el orden del servidor (lo más reciente arriba).
List<ComplaintSummary> sortComplaints(
  List<ComplaintSummary> items,
  ComplaintSort sort,
) {
  if (sort == ComplaintSort.recent) return items;
  final indexed = items.indexed.toList(growable: false);
  int metric(ComplaintSummary item) => switch (sort) {
    ComplaintSort.supported => item.likeCount,
    ComplaintSort.discussed => item.commentCount,
    ComplaintSort.recent => 0,
  };
  indexed.sort((a, b) {
    final byMetric = metric(b.$2).compareTo(metric(a.$2));
    return byMetric != 0 ? byMetric : a.$1.compareTo(b.$1);
  });
  return [for (final (_, item) in indexed) item];
}

/// Cuántos reportes hay por motivo, sobre el feed COMPLETO (las pastillas del
/// filtro lo muestran: se sabe cuánto hay antes de tocar).
final complaintCategoryCountsProvider = Provider<Map<String, int>>((ref) {
  final items =
      ref.watch(complaintsFeedProvider).valueOrNull ??
      const <ComplaintSummary>[];
  final counts = <String, int>{};
  for (final item in items) {
    counts.update(item.category, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts;
});

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

/// Feed ya filtrado por motivo y ordenado, conservando carga y error.
///
/// Se deriva aquí para que la pantalla solo pinte: `AsyncListView` recibe este
/// valor y no necesita `itemCount`, porque su longitud es la de lo visible.
final visibleComplaintsProvider = Provider<AsyncValue<List<ComplaintSummary>>>((
  ref,
) {
  final feed = ref.watch(complaintsFeedProvider);
  final filter = ref.watch(complaintCategoryFilterProvider);
  final sort = ref.watch(complaintSortProvider);
  if (filter == null && sort == ComplaintSort.recent) return feed;
  return switch (feed) {
    AsyncData(:final value) => AsyncData(
      sortComplaints(
        filter == null
            ? value
            : value
                  .where((item) => item.category == filter)
                  .toList(growable: false),
        sort,
      ),
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
