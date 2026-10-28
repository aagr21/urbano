import 'package:flutter/material.dart';

/// Helpers de [BuildContext] usados en las pantallas.
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  void showSnack(String message, {bool isError = false}) {
    final scheme = colors;
    ScaffoldMessenger.of(this)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? scheme.error : null,
        ),
      );
  }
}

extension StringX on String {
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension NullableStringX on String? {
  bool get blankOrNull => this == null || this!.trim().isEmpty;
}
