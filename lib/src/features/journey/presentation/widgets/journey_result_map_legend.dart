part of 'journey_result_map.dart';

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback? onFit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roundButton(
          context,
          icon: Icons.add_rounded,
          tooltip: 'Acercar',
          onTap: onZoomIn,
        ),
        const SizedBox(height: 6),
        _roundButton(
          context,
          icon: Icons.remove_rounded,
          tooltip: 'Alejar',
          onTap: onZoomOut,
        ),
        const SizedBox(height: 6),
        _roundButton(
          context,
          icon: Icons.center_focus_strong_rounded,
          tooltip: 'Encuadrar el viaje',
          onTap: onFit,
        ),
      ],
    );
  }

  static Widget _roundButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, size: 19, color: colors.primary),
      ),
    );
  }
}

/// Leyenda del mapa del viaje: una fila por micro con el color de SU línea
/// (mismo color que la polilínea y la insignia del mapa) + caminata y
/// transbordo.
///
/// Es pública para que la pantalla fusionada Viaje+Mapa la coloque justo
/// encima de la hoja de resultados.
class MapLegend extends StatelessWidget {
  const MapLegend(this.option, {super.key});

  final JourneyOption option;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    Widget bar(Color color, String label, {IconData? icon}) {
      // El color de la leyenda es el de la línea (GTFS), pero aquí se pinta
      // COMO ícono/barrita sobre la superficie de la hoja: un `2C3E50` sobre el
      // grafito del tema oscuro desaparece, así que se pasa por `legible` con el
      // mínimo de 3:1 que pide WCAG para gráficos significativos.
      final ink = AppColors.legible(color, colors.surface, minContrast: 3);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 15, color: ink)
          else
            Container(
              width: 16,
              height: 4,
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: text.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    // Un micro por ruta (varios tramos de la misma línea = una fila).
    final busRows = <Widget>[];
    final seen = <String>{};
    for (final leg in option.busLegs) {
      final name = leg.routeShortName?.trim() ?? '';
      if (name.isEmpty) continue;
      final key = '${leg.routeId ?? ''}|$name|${leg.routeColor ?? ''}';
      if (!seen.add(key)) continue;
      if (busRows.isNotEmpty) busRows.add(const SizedBox(height: 4));
      busRows.add(
        bar(
          AppColors.fromHex(leg.routeColor),
          'Micro $name',
          icon: Icons.directions_bus_rounded,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...busRows,
          if (busRows.isNotEmpty) const SizedBox(height: 4),
          bar(
            const Color(0xFF94A3B8),
            'Caminata',
            icon: Icons.directions_walk_rounded,
          ),
          const SizedBox(height: 4),
          bar(AppColors.accent, 'Transbordo'),
        ],
      ),
    );
  }
}
