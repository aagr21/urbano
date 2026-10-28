import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animation/motion.dart';
import '../config/env.dart';
import '../map/map_tile.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/map_theme_controller.dart';
import '../utils/extensions.dart';
import 'map_layer_preview.dart';

/// Ancho de cada tarjeta del selector: caben 4 en un teléfono de ~360 dp sin
/// forzar scroll (132 × 4 + espaciado ≈ 324).
const double _layerCardWidth = 132;

/// Alto de la miniatura de capa dentro de la tarjeta.
const double _layerPreviewHeight = 78;

/// Selector de **capa del mapa**, independiente del tema de la app.
///
/// Tocar abre una hoja con miniaturas dibujadas de cada capa (Mapa/OpenStreetMap,
/// Google Maps, Google Satélite, Oscuro). La capa cambia ÚNICAMENTE el mapa base:
/// los botones, chips, paneles y hojas se pintan siempre con el tema de la app.
/// La hoja ofrece además "Capa automática", que devuelve el mapa al brillo de la
/// app (equivale al antiguo mantener-pulsado: borra la elección).
///
/// Las capas de Google se muestran siempre — si no se compiló con
/// `--dart-define=GOOGLE_MAPS_API_KEY=AIza…` aparecen marcadas y, al tocarlas,
/// explican cómo activarlas. Ocultarlas era el problema: el usuario no sabía
/// ni que existían.
class MapTileButton extends ConsumerWidget {
  const MapTileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return SizedBox(
      // MISMO diámetro que el resto de la columna (el `Tooltip` fuera del lado
      // del botón inflaría 3 px por lado y rompería la uniformidad).
      width: AppControl.mapButton,
      height: AppControl.mapButton,
      child: Tooltip(
        message: 'Cambiar la capa del mapa',
        child: PressScale(
          scale: 0.92,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.outlineVariant),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              // MISMO diámetro que el resto de la columna de controles del mapa
              // ([AppControl.mapButton]).
              constraints: const BoxConstraints.tightFor(
                width: AppControl.mapButton,
                height: AppControl.mapButton,
              ),
              onPressed: () => _openSheet(context),
              // Ícono de "capas": ofrece cambiar la capa, no el estado.
              icon: Icon(Icons.layers_rounded, size: 20, color: colors.primary),
            ),
          ),
        ),
      ),
    );
  }

  /// El botón no mira el provider: la hoja resuelve la capa activa al abrirse,
  /// así que cambiar de capa no reconstruye toda la columna de controles.
  static void _openSheet(BuildContext context) {
    // La hoja es chrome de la app, no del mapa: hereda el tema de la app
    // (forma, agarre y fondo ya los pone `bottomSheetTheme` de `AppTheme`).
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _LayerPickerSheet(),
    );
  }
}

/// Hoja del selector de capas: tira de miniaturas + pastilla de modo automático.
class _LayerPickerSheet extends ConsumerStatefulWidget {
  const _LayerPickerSheet();

  @override
  ConsumerState<_LayerPickerSheet> createState() => _LayerPickerSheetState();
}

class _LayerPickerSheetState extends ConsumerState<_LayerPickerSheet> {
  /// Si el usuario ya tocó una capa de Google sin clave: se despliega el how-to.
  bool _showKeyHelp = false;

  /// ¿Hay clave de Map Tiles API compilada? Sin ella Google no puede servir.
  static bool get _hasGoogleKey => Env.googleMapsApiKey.isNotEmpty;

  void _select(MapTile tile) {
    if (tile.isGoogle && !_hasGoogleKey) {
      if (!_showKeyHelp) setState(() => _showKeyHelp = true);
      return;
    }
    ref.read(mapThemeControllerProvider.notifier).setTile(tile);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    // La hoja pinta SIEMPRE el tema de la app: la miniatura es la única que
    // muestra el brillo de la capa.
    final chosen = ref.watch(mapThemeControllerProvider);
    final effective = MapTile.resolve(
      appDark: Theme.of(context).brightness == Brightness.dark,
      choice: chosen,
    );
    final autoActive = chosen == null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.xs,
          AppSpace.lg,
          AppSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Capa del mapa',
                        style: text.titleMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Solo cambia el fondo del mapa; la interfaz sigue el '
                        'tema de la app.',
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                // Miniatura de lo que el mapa está mostrando ahora.
                _PreviewChip(tile: effective),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              height: _cardHeight(context),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                itemCount: MapTile.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
                itemBuilder: (context, index) {
                  final tile = MapTile.values[index];
                  return Reveal(
                    index: index,
                    slide: 10,
                    child: SizedBox(
                      width: _layerCardWidth,
                      child: _LayerCard(
                        tile: tile,
                        selected: tile == effective,
                        locked: tile.isGoogle && !_hasGoogleKey,
                        onTap: () => _select(tile),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            Reveal(
              index: MapTile.values.length,
              slide: 8,
              child: _AutoModeTile(
                // La miniatura enseña la capa que saldría si el tema de la app
                // mandara (hoy, o al cambiar de tema mañana).
                tile: MapTile.resolve(
                  appDark: Theme.of(context).brightness == Brightness.dark,
                ),
                active: autoActive,
                onTap: () {
                  ref
                      .read(mapThemeControllerProvider.notifier)
                      .followAppTheme();
                  Navigator.of(context).pop();
                },
              ),
            ),
            AnimatedSize(
              duration: Motion.morph,
              curve: Motion.standard,
              alignment: Alignment.topCenter,
              child: _showKeyHelp && !_hasGoogleKey
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpace.md),
                      child: _KeyHelp(colors: colors),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  /// Alto de la fila de tarjetas: deja espacio para la etiqueta de estado de
  /// cada tarjeta sin que las demás se vean cortadas.
  double _cardHeight(BuildContext context) =>
      _layerPreviewHeight +
      AppSpace.xl * 2 +
      MediaQuery.textScalerOf(context).scale(20) * 2 +
      14;
}

/// Tarjeta de una capa: miniatura dibujada + nombre + estado.
class _LayerCard extends StatelessWidget {
  const _LayerCard({
    required this.tile,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final MapTile tile;
  final bool selected;

  /// Capa que no puede usarse todavía (Google sin clave).
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final fill = _cardFill(colors, selected: selected);

    return PressScale(
      scale: 0.96,
      enabled: !locked,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          // Llave propia: los tests leen de aquí el fondo realmente pintado.
          key: ValueKey('layer-card-box-${tile.name}'),
          duration: Motion.quick,
          curve: Motion.standard,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? AppTheme.softShadow(color: colors.primary, opacity: 0.18)
                : null,
          ),
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: SizedBox(
                      height: _layerPreviewHeight,
                      child: MapLayerPreview(tile: tile),
                    ),
                  ),
                  PositionedDirectional(
                    top: AppSpace.xs,
                    end: AppSpace.xs,
                    child: Opacity(
                      // La marca de la capa en uso se atenúa si además está
                      // bloqueada: manda el aviso de clave.
                      opacity: selected ? 1 : 0,
                      child: const _SelectedBadge(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                // Llave para los tests: localiza la tarjeta por capa sin
                // depender de que el nombre corto sea único.
                key: ValueKey('layer-card-${tile.name}'),
                tile.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              Text(
                // Estado en segunda línea: con nombre propio, para que los
                // tests puedan medir la tinta secundaria sin ambigüedades.
                key: ValueKey('layer-card-state-${tile.name}'),
                locked ? 'Requiere clave' : tile.provider,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                  // El secundario del tema no siempre llega a AA sobre el
                  // fondo tenue de la tarjeta: se asegura el contraste.
                  color: AppColors.legible(
                    locked ? colors.error : colors.onSurfaceVariant,
                    fill,
                  ),
                  fontWeight: locked ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fondo pintado de la tarjeta: sólida la elegida, tenue el resto.
  Color _cardFill(ColorScheme colors, {required bool selected}) => selected
      ? colors.surfaceContainerHigh
      : colors.surfaceContainerLowest.withValues(alpha: 0.55);
}

/// Palomita sobre la miniatura de la capa en uso.
class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: context.colors.primary,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
      boxShadow: AppTheme.softShadow(blur: 8, dy: 2),
    ),
    child: Icon(
      Icons.check_rounded,
      size: 14,
      // El primario de la app es oscuro: se asegura la tinta sobre la marca.
      color: AppColors.onColor(context.colors.primary, preferred: Colors.white),
    ),
  );
}

/// Miniatura chica de la capa, para la cabecera y la pastilla automática.
class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.tile});

  final MapTile tile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          width: 46,
          height: 34,
          child: MapLayerPreview(tile: tile, showRoute: false),
        ),
      ),
    );
  }
}

/// Pastilla «Capa automática»: el mapa sigue el brillo de la app.
class _AutoModeTile extends StatelessWidget {
  const _AutoModeTile({
    required this.tile,
    required this.active,
    required this.onTap,
  });

  /// Capa que resulta del brillo actual (se dibuja en la miniatura).
  final MapTile tile;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    return PressScale(
      scale: 0.98,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          curve: Motion.standard,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            color: active
                ? colors.primaryContainer.withValues(alpha: 0.55)
                : colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(
              color: active ? colors.primary : colors.outlineVariant,
              width: active ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_mode_rounded,
                size: 18,
                color: active ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capa automática',
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Sin nombrar la capa: «Oscuro»/«Mapa» ya salen escritos en
                    // las tarjetas y repetirlos haría ambiguos los `find.text`.
                    Text(
                      active
                          ? 'El mapa sigue el tema de la app'
                          : 'Volver a seguir el tema de la app',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              _PreviewChip(tile: tile),
              if (active) ...[
                const SizedBox(width: AppSpace.sm),
                Icon(Icons.check_rounded, size: 18, color: colors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Cómo activar las capas de Google (aparece al tocar una capa bloqueada).
class _KeyHelp extends StatelessWidget {
  const _KeyHelp({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_rounded, size: 16, color: colors.primary),
              const SizedBox(width: AppSpace.sm),
              Text(
                'Capas de Google bloqueadas',
                style: text.labelLarge?.copyWith(color: colors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Necesitan una clave de la Map Tiles API. Ejecuta la app con:',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpace.sm),
          SelectableText(
            'flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza…',
            style: text.labelSmall?.copyWith(
              color: colors.onSurface,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
