import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';

/// Campo de búsqueda del catálogo de micros con botón limpiar.
class MicrosSearchField extends StatelessWidget {
  const MicrosSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Buscador de grafito con filete e íconos blancos: el relieve lo da el
    // borde claro, no un relleno blanco.
    final ink = colors.onSurface;
    final softInk = colors.onSurfaceVariant;
    final hairline = dark ? AppColors.lineDark : colors.outlineVariant;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      cursorColor: colors.primary,
      style: text.bodyLarge?.copyWith(color: ink),
      decoration: InputDecoration(
        hintText: 'Busca por número o nombre',
        hintStyle: text.bodyMedium?.copyWith(color: softInk),
        prefixIcon: const Icon(Icons.search_rounded),
        prefixIconColor: ink,
        suffixIconColor: softInk,
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Limpiar búsqueda',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
        ),
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: hairline),
        ),
      ),
    );
  }
}
