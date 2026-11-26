import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../animation/motion.dart';
import '../theme/app_theme.dart';
import '../utils/extensions.dart';
import 'map_layer_picker_sheet.dart';

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
      builder: (_) => const MapLayerPickerSheet(),
    );
  }
}
