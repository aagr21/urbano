import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../utils/extensions.dart';
import '../utils/location.dart';
import 'empty_state.dart';

/// Estado de error amigable + reintento (degrada bien sin backend).
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
    this.compact = false,
  });

  final Object? error;
  final VoidCallback? onRetry;
  final String? title;
  final bool compact;

  String get _message {
    final current = error;
    if (current is ApiException) return current.friendlyMessage;
    if (current is LocationFailure) return current.friendlyMessage;
    if (current is String) return current;
    return 'Algo salió mal. Intenta de nuevo en unos segundos.';
  }

  IconData get _icon {
    final current = error;
    if (current is ApiException) {
      return switch (current.kind) {
        ApiErrorKind.network || ApiErrorKind.timeout => Icons.wifi_off_rounded,
        ApiErrorKind.notFound => Icons.search_off_rounded,
        _ => Icons.cloud_off_rounded,
      };
    }
    if (current is LocationFailure) return Icons.location_off_rounded;
    return Icons.error_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    // `EmptyState` ya entra con `Reveal`; aquí no hace falta otra animación (y
    // duplicarla hacía que el bloque se moviera dos veces).
    return EmptyState(
      icon: _icon,
      iconColor: context.colors.error,
      title: title ?? 'No pudimos cargar',
      message: _message,
      actionLabel: onRetry == null ? null : 'Reintentar',
      onAction: onRetry,
      compact: compact,
    );
  }
}
