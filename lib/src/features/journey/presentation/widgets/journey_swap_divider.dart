import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;

/// Separador con botón de intercambio centrado.
///
/// Dibuja dos líneas divisorias con un botón circular en el medio para
/// invertir origen y destino.
class JourneySwapDivider extends StatelessWidget {
  const JourneySwapDivider({super.key, this.onSwap});

  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              color: dark ? AppColors.lineDark : HtmlDesignTokens.slate200,
            ),
          ),
          PressScale(
            scale: 0.9,
            child: Tooltip(
              message: 'Invertir origen y destino',
              child: InkWell(
                onTap: onSwap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: HtmlDesignTokens.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dark
                          ? AppColors.lineDark
                          : HtmlDesignTokens.slate200,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    size: 16,
                    color: HtmlDesignTokens.emerald500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              color: dark ? AppColors.lineDark : HtmlDesignTokens.slate200,
            ),
          ),
        ],
      ),
    );
  }
}
