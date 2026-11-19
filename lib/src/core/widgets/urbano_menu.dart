import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../animation/motion.dart';
import '../config/env.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import '../utils/extensions.dart';
import 'urbano_logo.dart';

/// Sección de primer nivel de la app: la que representa cada rama del shell.
///
/// El menú la usa para marcar dónde está parado el usuario; las cabeceras la
/// pasan al abrir el menú.
enum UrbanoSection { home, journey, complaints }

/// Abre el **menú principal** de Urbano (hoja inferior).
///
/// Sustituye a la barra de navegación inferior: la portada quedó como la de la
/// referencia (logo + ubicación + accesos) y la navegación entre secciones vive
/// en el botón de menú de cada cabecera. Se cierra al tocar una sección y el
/// router hace el cambio de rama, así el estado de cada pestaña se conserva.
Future<void> showUrbanoMenu(
  BuildContext context, {
  required UrbanoSection current,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _UrbanoMenuSheet(current: current),
);

class _UrbanoMenuSheet extends StatelessWidget {
  const _UrbanoMenuSheet({required this.current});

  final UrbanoSection current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          0,
          AppSpace.lg,
          AppSpace.lg,
        ),
        // En pantallas bajas (o con la letra grande) las cuatro filas no
        // entran: el menú se desplaza en vez de desbordar la hoja.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera de marca: el menú también es Urbano, no una lista gris
              // pegada al borde de la pantalla.
              Row(
                children: [
                  const UrbanoLogo(size: 36, shadow: false),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Env.appName,
                          style: AppTypography.wordmark(
                            text.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          Env.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              for (final (index, item) in _items.indexed)
                Reveal(
                  index: index,
                  slide: 6,
                  child: _MenuTile(
                    key: ValueKey('menu-item-${item.id}'),
                    item: item,
                    selected: item.section == current,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Destinos del menú. [section] `null` para pantallas que no son pestaña.
typedef _MenuItemDef = ({
  String id,
  String label,
  String subtitle,
  IconData icon,
  String path,
  UrbanoSection? section,
});

const List<_MenuItemDef> _items = [
  (
    id: 'home',
    label: 'Inicio',
    subtitle: 'Portada, micros y viajes recientes',
    icon: Icons.home_rounded,
    path: '/',
    section: UrbanoSection.home,
  ),
  (
    id: 'journey',
    label: 'Viaje',
    subtitle: 'Planifica y sigue tu recorrido en el mapa',
    icon: Icons.map_rounded,
    path: '/journey',
    section: UrbanoSection.journey,
  ),
  (
    id: 'complaints',
    label: 'Denuncias',
    subtitle: 'La voz del pasajero',
    icon: Icons.campaign_rounded,
    path: '/complaints',
    section: UrbanoSection.complaints,
  ),
  (
    id: 'info',
    label: 'Acerca de Urbano',
    subtitle: 'Datos GTFS, capas y créditos',
    icon: Icons.info_outline_rounded,
    path: '/info',
    section: null,
  ),
];

/// Fila del menú: ícono en disco teñido + título/subtítulo + destino.
///
/// La sección actual queda marcada con un check y tocarla solo cierra la hoja:
/// no se re-entra a la misma rama (perdería el scroll y el panel abierto).
class _MenuTile extends StatelessWidget {
  const _MenuTile({super.key, required this.item, required this.selected});

  final _MenuItemDef item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final fill = AppColors.tint(colors.primary, colors.surface, 0.1);
    // La tinta del disco se mide contra el relleno pintado, no contra el tema.
    final ink = AppColors.legible(colors.primary, fill);
    final radius = BorderRadius.circular(AppRadius.md);

    return PressScale(
      scale: 0.98,
      child: Material(
        color: selected ? fill : Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: () => _go(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: AppSpace.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.surface.withValues(alpha: 0.7)
                        : fill,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                  ),
                  child: Icon(item.icon, size: 21, color: ink),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.label,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.chevron_right,
                  size: 20,
                  color: selected ? ink : colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    if (selected) return;
    // `/info` es una pantalla de detalle: se apila para poder volver.
    if (item.path == '/info') {
      router.push(item.path);
    } else {
      router.go(item.path);
    }
  }
}
