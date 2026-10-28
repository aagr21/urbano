import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animation/motion.dart';
import 'empty_state.dart';
import 'error_view.dart';
import 'loading_shimmer.dart';

/// Render consistente de estados carga / error / vacío / datos en TODAS
/// las pantallas.
///
/// Cuando el esqueleto se retira, el contenido no aparece de golpe: entra con
/// el `Reveal` del kit (fundido + subida corta). Así el cambio
/// carga→datos se lee como una transición y no como un parpadeo, en todas las
/// pantallas a la vez. No se le cambia la clave: el `Reveal` se monta una sola
/// vez por posición, así que un refresco con `[keepPreviousData]` no vuelve a
/// reproducir la entrada ni pierde el scroll de la lista.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    this.onError,
    this.onEmpty,
    this.isEmpty,
    this.emptyIcon = Icons.inbox_rounded,
    this.emptyTitle = 'Sin resultados',
    this.emptyMessage,
    this.loadingCount = 6,
  });

  final AsyncValue<T> value;
  final Widget Function(T payload) data;
  final VoidCallback? onRetry;
  final Widget Function()? loading;
  final Widget Function(Object error)? onError;
  final Widget Function()? onEmpty;
  final bool Function(T payload)? isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final int loadingCount;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (payload) {
        if (isEmpty?.call(payload) ?? false) {
          return onEmpty?.call() ??
              EmptyState(
                icon: emptyIcon,
                title: emptyTitle,
                message: emptyMessage,
              );
        }
        return Reveal(slide: 8, duration: Motion.base, child: data(payload));
      },
      loading: () => loading?.call() ?? SkeletonList(count: loadingCount),
      error: (error, stackTrace) =>
          onError?.call(error) ?? ErrorView(error: error, onRetry: onRetry),
    );
  }
}

/// Variante para listas con `AsyncValue<List<T>>` que ya centraliza vacío.
class AsyncListView<T> extends StatelessWidget {
  const AsyncListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    required this.count,
    this.onRetry,
    this.emptyIcon = Icons.search_off_rounded,
    this.emptyTitle = 'Sin resultados',
    this.emptyMessage,
    this.padding = const EdgeInsets.all(16),
    this.separated = true,
    this.itemCount,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int count;
  final VoidCallback? onRetry;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final EdgeInsetsGeometry padding;
  final bool separated;

  /// Longitud distinta a la del payload (ej: tras filtrar).
  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    return AsyncValueView<List<T>>(
      value: value,
      onRetry: onRetry,
      isEmpty: (items) => items.isEmpty,
      emptyIcon: emptyIcon,
      emptyTitle: emptyTitle,
      emptyMessage: emptyMessage,
      loadingCount: count,
      data: (items) {
        final length = itemCount ?? items.length;
        if (!separated) {
          return ListView.builder(
            padding: padding,
            itemCount: length,
            itemBuilder: (context, index) =>
                itemBuilder(context, items[index], index),
          );
        }
        return ListView.separated(
          padding: padding,
          itemCount: length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              itemBuilder(context, items[index], index),
        );
      },
    );
  }
}
