import 'package:material_ui/material_ui.dart';

import '../animation/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/extensions.dart';
import '../widgets/urbano_glyph.dart';

/// Una pestaña de la barra inferior.
@immutable
class UrbanoTab {
  const UrbanoTab({
    required this.id,
    required this.label,
    this.glyph,
    this.icon,
    this.selectedIcon,
  }) : assert(glyph != null || icon != null);

  /// Clave estable (`nav-<id>`), la que usan los tests.
  final String id;
  final String label;

  /// Ícono de la marca (Micros, Viajes, Lugares, Denuncias).
  final UrbanoGlyphKind? glyph;

  /// Ícono de Material (Inicio, Perfil) y su variante seleccionada.
  final IconData? icon;
  final IconData? selectedIcon;
}

/// Las seis pestañas del diseño, en orden: Inicio · Micros · Viajes ·
/// Lugares · Denuncias · Perfil.
const List<UrbanoTab> urbanoTabs = [
  UrbanoTab(
    id: 'home',
    label: 'Inicio',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  UrbanoTab(id: 'micros', label: 'Micros', glyph: UrbanoGlyphKind.micros),
  UrbanoTab(id: 'journey', label: 'Viajes', glyph: UrbanoGlyphKind.journey),
  UrbanoTab(id: 'places', label: 'Lugares', glyph: UrbanoGlyphKind.places),
  UrbanoTab(
    id: 'complaints',
    label: 'Denuncias',
    glyph: UrbanoGlyphKind.complaints,
  ),
  UrbanoTab(
    id: 'profile',
    label: 'Perfil',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
  ),
];

/// Barra inferior de Urbano (diseño «Pantalla de inicio»): una tarjeta blanca
/// flotante con las seis pestañas; la seleccionada lleva una placa verde
/// diluida y tinta verde, el resto va en gris.
///
/// Es solo pintura: qué pestaña está activa ([selectedIndex], o ninguna con
/// `null`) y qué pasa al tocar ([onSelect]) los decide el shell. Así una
/// pestaña puede ser una **acción** (Lugares abre su hoja) en vez de una rama.
class UrbanoBottomBar extends StatelessWidget {
  const UrbanoBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.tabs = urbanoTabs,
  });

  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final List<UrbanoTab> tabs;

  /// Alto de la tarjeta (sin el área segura del sistema).
  static const double height = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.lg);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm + 2,
          AppSpace.xs,
          AppSpace.sm + 2,
          0,
        ),
        child: Container(
          height: height,
          padding: const EdgeInsets.all(AppSpace.xs + 2),
          decoration: BoxDecoration(
            color: dark ? colors.surfaceContainerHigh : colors.surface,
            borderRadius: radius,
            border: Border.all(
              color: dark ? AppColors.lineDark : colors.outlineVariant,
            ),
            boxShadow: AppTheme.softShadow(
              color: Colors.black,
              opacity: dark ? 0.3 : 0.08,
              blur: 20,
              dy: 6,
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabButton(
                    tab: tabs[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final UrbanoTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = dark ? colors.primary : AppColors.greenDeep;
    final idle = colors.onSurfaceVariant;
    final ink = selected ? active : idle;
    final radius = BorderRadius.circular(AppRadius.md);
    final fill = selected
        ? AppColors.tint(colors.primary, colors.surface, dark ? 0.22 : 0.14)
        : Colors.transparent;

    final icon = tab.glyph != null
        ? UrbanoGlyph(tab.glyph!, size: 26, color: ink)
        : Icon(
            selected ? (tab.selectedIcon ?? tab.icon) : tab.icon,
            size: 26,
            color: ink,
          );

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: Tooltip(
        message: tab.label,
        excludeFromSemantics: true,
        child: AnimatedContainer(
          key: ValueKey('nav-${tab.id}'),
          duration: Motion.duration(context, Motion.base),
          curve: Motion.standard,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: fill, borderRadius: radius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        style: context.text.labelSmall?.copyWith(
                          color: ink,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
