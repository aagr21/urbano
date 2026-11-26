import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart' show AppRadius, AppSpace;
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../../domain/destination_draft.dart';
import 'journey_endpoint_field.dart';
import 'journey_plan_button.dart';
import 'journey_swap_divider.dart';

/// Callbacks de UN campo de extremo (origen o destino).
class EndpointFieldActions {
  const EndpointFieldActions({
    required this.onChanged,
    required this.onSubmitted,
    required this.onTap,
    required this.onMapTap,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onTap;
  final VoidCallback onMapTap;
}

/// Bloque de ruta de la hoja «¿A dónde vas?»: origen y destino en UNA
/// tarjeta (riel punteado entre sus placas y el botón de invertir sobre la
/// línea que los separa) y el CTA de planificar debajo, fuera del bloque.
///
/// Solo pinta el [draft]: los textos salen de él y cada gesto sube por su
/// callback.
class DestinationEndpointsCard extends StatelessWidget {
  const DestinationEndpointsCard({
    super.key,
    required this.draft,
    required this.originController,
    required this.originFocus,
    required this.destinationController,
    required this.destinationFocus,
    required this.origin,
    required this.destination,
    required this.originSuggestions,
    required this.destinationSuggestions,
    required this.onSwap,
    required this.onPlan,
  });

  final DestinationDraft draft;
  final TextEditingController originController;
  final FocusNode originFocus;
  final TextEditingController destinationController;
  final FocusNode destinationFocus;
  final EndpointFieldActions origin;
  final EndpointFieldActions destination;

  /// Panel de sugerencias bajo cada campo (o `null` si no toca mostrarlo).
  final Widget? originSuggestions;
  final Widget? destinationSuggestions;

  final VoidCallback onSwap;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            // En oscuro la hoja ya es `surface`: el bloque sube un escalón
            // para leerse como tarjeta y no solo por el filete.
            color: dark ? colors.surfaceContainerHigh : colors.surface,
            borderRadius: radius,
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: dark ? 0.2 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JourneyEndpointField(
                  label: 'Origen',
                  value: draft.originLabel,
                  emptyHint: 'Escribe o elige tu origen',
                  empty: draft.origin == null,
                  subtitle: draft.originSubtitle,
                  tag: draft.originTag,
                  icon: Icons.my_location_rounded,
                  accent: HtmlDesignTokens.emerald600,
                  controller: originController,
                  focusNode: originFocus,
                  inputKey: const ValueKey('journey-origin-input'),
                  onChanged: origin.onChanged,
                  onSubmitted: origin.onSubmitted,
                  suggestions: originSuggestions,
                  onTap: origin.onTap,
                  onMapTap: origin.onMapTap,
                ),
                JourneySwapDivider(onSwap: onSwap),
                JourneyEndpointField(
                  label: 'Destino',
                  value: draft.destinationLabel,
                  emptyHint: '¿A dónde vas?',
                  empty: draft.destination == null,
                  subtitle: draft.destinationSubtitle,
                  icon: Icons.location_on_rounded,
                  accent: HtmlDesignTokens.rose500,
                  controller: destinationController,
                  focusNode: destinationFocus,
                  inputKey: const ValueKey('journey-destination-input'),
                  onChanged: destination.onChanged,
                  onSubmitted: destination.onSubmitted,
                  suggestions: destinationSuggestions,
                  onTap: destination.onTap,
                  onMapTap: destination.onMapTap,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        JourneyPlanButton(
          enabled: draft.canPlan,
          onPressed: draft.canPlan ? onPlan : null,
        ),
      ],
    );
  }
}
