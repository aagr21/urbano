import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/utils/extensions.dart';
import '../journey_providers.dart';

/// Tarjeta del planeador — estilo de `sheet.html`: tarjeta blanca con
/// bordes redondeados, campos de origen/destino con iconos de color,
/// separador con botón de intercambio y botón de planificar con degradado.
class JourneyPlannerCard extends StatelessWidget {
  const JourneyPlannerCard({
    super.key,
    required this.origin,
    required this.destination,
    required this.time,
    required this.ready,
    required this.hasResults,
    required this.onSwap,
    required this.onPickOrigin,
    required this.onPickDestination,
    required this.onPickOriginOnMap,
    required this.onPickDestinationOnMap,
    required this.onPickTime,
    required this.onSubmit,
    required this.onClear,
  });

  final JourneyPlace? origin;
  final JourneyPlace? destination;

  /// Hora de salida `HH:mm` (nula = "Ahora").
  final String? time;

  /// `true` con origen y destino fijados: habilita "Viajar".
  final bool ready;

  /// `true` con resultados visibles: muestra el botón "Limpiar".
  final bool hasResults;

  final VoidCallback onSwap;
  final VoidCallback onPickOrigin;
  final VoidCallback onPickDestination;
  final VoidCallback onPickOriginOnMap;
  final VoidCallback onPickDestinationOnMap;
  final VoidCallback onPickTime;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark ? colors.surface : HtmlDesignTokens.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: dark ? AppColors.lineDark : HtmlDesignTokens.slate200,
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.2)
                : HtmlDesignTokens.slate900.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.1)
                : HtmlDesignTokens.slate900.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Brillo ambiental de las esquinas (como el HTML)
          Positioned(
            top: -48,
            right: -48,
            child: SizedBox(
              width: 128,
              height: 128,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x2626C481), Color(0x0026C481)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -48,
            left: -48,
            child: SizedBox(
              width: 128,
              height: 128,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x1AF43F5E), Color(0x00F43F5E)],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Contenedor de campos con fondo gris claro
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dark
                        ? colors.surfaceContainerHigh
                        : HtmlDesignTokens.slate50,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: dark
                          ? AppColors.lineDark
                          : HtmlDesignTokens.slate200,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline vertical con swap centrado
                      Padding(
                        padding: const EdgeInsets.only(top: 25, left: 4),
                        child: SizedBox(
                          width: 48,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _TimelineDot(
                                    color: HtmlDesignTokens.emerald500,
                                    icon: Icons.trip_origin_rounded,
                                  ),
                                  SizedBox(
                                    width: 2,
                                    height: 62,
                                    child: ColoredBox(
                                      color: HtmlDesignTokens.slate400,
                                    ),
                                  ),
                                  _TimelineDot(
                                    color: HtmlDesignTokens.rose500,
                                    icon: Icons.flag_rounded,
                                  ),
                                ],
                              ),
                              _SwapButton(onTap: onSwap),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            // Campo de origen
                            _EndpointField(
                              label: 'Origen',
                              place: origin,
                              hint: 'Marca un punto en el mapa o usa tu ubicación',
                              icon: Icons.my_location_rounded,
                              iconBg: HtmlDesignTokens.emerald100,
                              iconInk: HtmlDesignTokens.emerald600,
                              labelInk: HtmlDesignTokens.emerald700,
                              subtitleInk: HtmlDesignTokens.emerald500,
                              onTap: onPickOrigin,
                              onMapTap: onPickOriginOnMap,
                              mapButtonBg: HtmlDesignTokens.white,
                              mapButtonInk: HtmlDesignTokens.emerald700,
                              mapButtonBorder: HtmlDesignTokens.emerald200,
                            ),
                            const SizedBox(height: 8),
                            // Campo de destino
                            _EndpointField(
                              label: 'Destino',
                              place: destination,
                              hint: 'Marca dónde quieres llegar',
                              icon: Icons.location_on_rounded,
                              iconBg: HtmlDesignTokens.rose50,
                              iconInk: HtmlDesignTokens.rose500,
                              labelInk: HtmlDesignTokens.roseRed,
                              subtitleInk: HtmlDesignTokens.rose400,
                              onTap: onPickDestination,
                              onMapTap: onPickDestinationOnMap,
                              mapButtonBg: HtmlDesignTokens.white,
                              mapButtonInk: HtmlDesignTokens.roseRed,
                              mapButtonBorder: HtmlDesignTokens.rose300,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Botón de planificar — degradado esmeralda
                _PlanButton(
                  ready: ready,
                  hasResults: hasResults,
                  onSubmit: onSubmit,
                  onClear: onClear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón swap sobre el conector del timeline.
class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: 'Invertir origen y destino',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: HtmlDesignTokens.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: dark ? AppColors.lineDark : HtmlDesignTokens.slate200,
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
    );
  }
}

/// Punto de la timeline (origen verde / destino rosa).
class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(icon, size: 8, color: Colors.white),
  );
}

/// Campo de extremo (origen o destino) — estilo del HTML.
class _EndpointField extends StatelessWidget {
  const _EndpointField({
    required this.label,
    required this.place,
    required this.hint,
    required this.icon,
    required this.iconBg,
    required this.iconInk,
    required this.labelInk,
    required this.subtitleInk,
    required this.onTap,
    required this.onMapTap,
    required this.mapButtonBg,
    required this.mapButtonInk,
    required this.mapButtonBorder,
  });

  final String label;
  final JourneyPlace? place;
  final String hint;
  final IconData icon;
  final Color iconBg;
  final Color iconInk;
  final Color labelInk;
  final Color subtitleInk;
  final VoidCallback onTap;
  final VoidCallback? onMapTap;
  final Color mapButtonBg;
  final Color mapButtonInk;
  final Color mapButtonBorder;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Icono con fondo de color
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(icon, size: 14, color: iconInk),
            ),
            const SizedBox(width: 10),
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.labelSmall?.copyWith(
                      color: labelInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place?.label ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (place == null)
                    Text(
                      hint,
                      style: text.labelSmall?.copyWith(
                        color: subtitleInk,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            // Botón "Mapa" — tooltip para los tests.
            if (onMapTap != null)
              Tooltip(
                message: 'Elegir en el mapa',
                child: InkWell(
                  onTap: onMapTap,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: mapButtonBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: mapButtonBorder, width: 0.8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 13, color: mapButtonInk),
                        const SizedBox(width: 6),
                        Text(
                          'Mapa',
                          style: text.labelSmall?.copyWith(
                            color: mapButtonInk,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botón de planificar viaje — degradado esmeralda a teal.
class _PlanButton extends StatelessWidget {
  const _PlanButton({
    required this.ready,
    required this.hasResults,
    required this.onSubmit,
    required this.onClear,
  });

  final bool ready;
  final bool hasResults;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: ready
            ? const LinearGradient(
                colors: [
                  HtmlDesignTokens.emerald600,
                  HtmlDesignTokens.emerald500,
                  HtmlDesignTokens.teal500,
                ],
              )
            : null,
        color: ready
            ? null
            : (dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08)),
        boxShadow: ready
            ? [
                BoxShadow(
                  color: HtmlDesignTokens.emerald500.withValues(alpha: 0.35),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: ready ? onSubmit : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono de micro
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ready
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.directions_bus_rounded,
                  size: 16,
                  color: ready
                      ? Colors.white
                      : (dark
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.35)),
                ),
              ),
              const SizedBox(width: 12),
              // Texto — "Viajar" es lo que los tests buscan.
              const Text(
                'Viajar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              if (ready) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
