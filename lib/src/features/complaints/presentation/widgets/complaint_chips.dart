import 'package:flutter/material.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../application/complaints_feed_controller.dart';

/// Piezas visuales compartidas del feed de quejas y de su detalle: la insignia
/// del micro, la pastilla del motivo y la del estado.
///
/// Viven juntas porque tarjeta y detalle tienen que teñirse **igual**: si cada
/// uno hiciera su propio `Color.lerp` con su propio alfa, el mismo motivo se
/// vería distinto según dónde se abra el reporte.
///
/// Regla de color de estas piezas: el acento (de categoría o de línea GTFS)
/// nunca pinta letras tal cual. Primero se teñe la superficie con
/// [AppColors.tint] y DESPUÉS la letra/ícono/borde se miden contra **ese**
/// relleno con [AppColors.legible] — nunca contra el token de origen. Así los
/// seis motivos siguen siendo legibles en modo claro y en modo oscuro.

/// Insignia cuadrada con el número del micro sobre el color de su línea.
class MicroBadge extends StatelessWidget {
  const MicroBadge({
    super.key,
    required this.label,
    required this.color,
    this.size = 46,
  });

  final String label;

  /// Color GTFS de la línea (ya convertido con [AppColors.fromHex]).
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Relleno vivo: el color de la línea hacia su versión profunda en diagonal.
    // La cifra se mide contra el PUNTO MEDIO del degradado, que es lo que ve el
    // ojo detrás del texto, no contra un extremo.
    final deep = Color.lerp(color, Colors.black, 0.28)!;
    final mid = Color.lerp(color, deep, 0.5)!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, deep],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppTheme.softShadow(
          color: color,
          opacity: 0.3,
          blur: 14,
          dy: 4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xs),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            // Sobre un relleno sólido con su propio texto: `onColor`, que elige
            // tinta clara u oscura por contraste (los hex GTFS son arbitrarios).
            style: TextStyle(
              color: AppColors.onColor(mid),
              fontWeight: FontWeight.w900,
              fontSize: size * 0.38,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastilla del **motivo** de la queja, teñida con el acento de su categoría.
///
/// Con [onTap] deja de ser informativa y se vuelve chip de filtro del feed;
/// con [selected] se satura, así el color del motivo ES el estado «elegido».
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    this.on,
    this.selected,
    this.onTap,
  });

  final String category;

  /// Superficie sobre la que se pinta (la tarjeta, la hoja, el fondo). Se pasa
  /// explícita porque el contraste se mide contra lo que REALMENTE hay detrás.
  final Color? on;

  /// Solo relevante con [onTap]: `true` si este motivo es el filtro activo.
  final bool? selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ComplaintPill(
    label: categoryLabelOf(category),
    icon: categoryIconOf(category),
    accent: AppColors.categoryAccent(category),
    on: on,
    emphasized: selected == true,
    onTap: onTap,
  );
}

/// Pastilla del **estado de revisión** (`pending` / `approved` / `rejected`):
/// informa sin gritar, porque el feed mezcla reportes verificados con reportes
/// recién enviados.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.on});

  final String status;
  final Color? on;

  @override
  Widget build(BuildContext context) {
    final (label, icon, accent) = switch (status) {
      'approved' => ('Verificada', Icons.verified_rounded, AppColors.success),
      'rejected' => (
        'Descartada',
        Icons.do_not_disturb_on_rounded,
        AppColors.danger,
      ),
      _ => (
        'En revisión',
        Icons.hourglass_top_rounded,
        AppColors.categoryDeviation,
      ),
    };
    return ComplaintPill(
      label: label,
      icon: icon,
      accent: accent,
      on: on,
      emphasized: false,
    );
  }
}

/// Pastilla viva: relleno teñido, borde del mismo matiz y letra legible sobre
/// lo que se pintó de verdad.
///
/// Es pública porque el filtro del feed necesita la misma pieza con un texto
/// propio ("Todas") y con tacto; CategoryChip/StatusChip son sus dos variantes
/// informativas.
class ComplaintPill extends StatelessWidget {
  const ComplaintPill({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.emphasized,
    this.on,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Color? on;

  /// Pasada seleccionada en un filtro: más saturada y con borde más firme.
  final bool emphasized;

  /// `null` = solo adorno; si no, la pastilla se puede tocar.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // El relleno se resuelve ANTES que la tinta: es el fondo que la letra tiene
    // que ganarse.
    final surface = on ?? context.colors.surface;
    final fill = AppColors.tint(accent, surface, emphasized ? 0.34 : 0.16);
    final ink = AppColors.legible(accent, fill);
    final pill = AnimatedContainer(
      duration: Motion.quick,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: ink.withValues(alpha: emphasized ? 0.85 : 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ink),
          const SizedBox(width: AppSpace.xs),
          // `Flexible`, no `Text` a pelo: dentro del `Wrap` de la tarjeta, un
          // motivo largo en pantalla angosta (360 px) desbordaba la pastilla.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return PressScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: pill,
      ),
    );
  }
}
