import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../core/widgets/urbano_logo.dart';
import 'home_route_lattice.dart';

/// **Portada de Inicio**: el mismo campo de marca que abre Quejas.
///
/// Antes la cabecera vivía dentro del `SafeArea` y arrancaba con el degradado
/// completo (`urbanoGradient`): quedaba una franja gris del sistema arriba y el
/// verde agua brillante del arranque competía con el texto. Ahora la portada es
/// a sangre —entra por debajo de la barra de estado, con su inset adentro— y el
/// campo es la laguna profunda con el riel verde agua al pie, igual que la
/// portada de Quejas: una sola marca en toda la app.
///
/// Encima del campo, todo se mide: la tinta clara sale de [AppColors.onColor]
/// contra el extremo MÁS CLARO del degradado ([AppColors.fieldMid]), no de un
/// blanco escrito a mano, y los vidrios (chip de ubicación, cifras, botón de
/// info) son esa misma tinta al 10–20 %.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final topInset = MediaQuery.paddingOf(context).top;
    // El buscador pisa el degradado de marca, que es el mismo con tema claro,
    // tema oscuro y con el mapa en cualquiera de sus dos modos. Heredar el
    // `inputDecorationTheme` lo rompía cruzado: en oscuro su vidrio (blanco al
    // 6%) desaparece sobre el verde y en claro la tinta del tema es casi negra
    // sobre un degradado saturado. Se fija un vidrio casi opaco y todo lo que se
    // pinta sobre él (letra, placeholder, íconos, borde, cursor) se mide contra
    // el fondo realmente pintado, no contra `context.colors`.
    final fieldGlass = Colors.white.withValues(alpha: 0.94);
    // Se mide contra el extremo MÁS CLARO del campo: es el peor caso para una
    // tinta oscura, así el resultado vale también sobre `primary`/`primaryDark`
    // (donde el contraste sube) y con cualquier tema.
    final fieldBg = Color.lerp(AppColors.fieldMid, Colors.white, 0.94)!;
    final fieldInk = AppColors.legible(AppColors.ink, fieldBg);
    final fieldHint = AppColors.legible(AppColors.inkSoft, fieldBg);
    final fieldEdge = AppColors.legible(
      AppColors.primary,
      fieldBg,
      minContrast: 3,
    );
    // Tinta del campo: se mide, no se escribe.
    final ink = AppColors.onColor(AppColors.fieldMid);
    final softInk = ink.withValues(alpha: 0.84);
    final edge = ink.withValues(alpha: 0.22);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // El campo es oscuro con los dos temas: los íconos del sistema van claros
      // mientras la portada está arriba (al scrollearla vuelve el chrome del
      // tema, igual que en Quejas).
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        // Esquinas inferiores: la portada es una hoja de marca, no una banda.
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                AppColors.fieldMid,
                AppColors.primary,
              ],
              stops: [0, 0.55, 1],
            ),
          ),
          child: Stack(
            children: [
              // Trama de anillos + micro que circula: la portada se mueve sola
              // en cuanto abre la app. Va de fondo e `IgnorePointer`, así que
              // no roba toques al buscador ni a los botones.
              const Positioned.fill(child: HomeRouteLattice()),
              // Orilla de la laguna: la misma firma luminosa del pie de la
              // portada de Quejas.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.aqua,
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                // El inset del sistema lo paga la portada (a sangre): el campo
                // verde llega hasta el borde del teléfono.
                padding: EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  topInset + AppSpace.md,
                  AppSpace.lg,
                  AppSpace.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const UrbanoLogo(size: 46),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Env.appName,
                                style: AppTypography.wordmark(
                                  text.titleLarge?.copyWith(color: ink),
                                ),
                              ),
                              Text(
                                Env.tagline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall?.copyWith(
                                  color: softInk,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Vidrio del sistema: el botón de info deja de ser un
                        // ícono suelto sobre el degradado.
                        _GlassButton(
                          tooltip: 'Acerca de Urbano',
                          icon: Icons.info_outline_rounded,
                          onTap: () => context.push('/info'),
                          ink: ink,
                          edge: edge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Text(
                      '¿A dónde vas hoy?',
                      maxLines: 2,
                      style: text.titleLarge?.copyWith(
                        color: ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Row(
                      children: [
                        // Punto de la orilla: la marca en el detalle más chico.
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.aqua,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: Text(
                            '${Fmt.greeting()} · ${_today()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelMedium?.copyWith(
                              color: softInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.md),
                    const _LocationChip(),
                    const SizedBox(height: AppSpace.md),
                    // El buscador flota: la sombra de la laguna lo despega del
                    // campo y lo deja como el objeto que se toca primero.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) => TextField(
                          controller: controller,
                          textInputAction: TextInputAction.search,
                          cursorColor: fieldInk,
                          style: text.bodyMedium?.copyWith(color: fieldInk),
                          decoration: InputDecoration(
                            hintText: 'Busca rutas…',
                            hintStyle: text.bodyMedium?.copyWith(
                              color: fieldHint,
                            ),
                            filled: true,
                            fillColor: fieldGlass,
                            prefixIconColor: fieldHint,
                            suffixIconColor: fieldHint,
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: value.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpiar',
                                    onPressed: controller.clear,
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: fieldInk,
                                    ),
                                  ),
                            // Píldora con borde propio: sin él, el vidrio
                            // blanco sobre el verde no marca dónde empieza el
                            // campo.
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              borderSide: BorderSide(
                                color: fieldEdge,
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              borderSide: BorderSide(
                                color: AppColors.legible(
                                  AppColors.primary,
                                  fieldBg,
                                ),
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _today() {
    const days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }
}

/// Botón redondo de vidrio sobre el campo de marca.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.ink,
    required this.edge,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color ink;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.92,
      child: Material(
        color: ink.withValues(alpha: 0.12),
        shape: CircleBorder(side: BorderSide(color: edge)),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, color: ink, size: 20),
        ),
      ),
    );
  }
}

class _LocationChip extends ConsumerWidget {
  const _LocationChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(myLocationProvider);

    return location.when(
      loading: () => const _Chip(
        icon: Icons.hourglass_bottom_rounded,
        label: 'Buscando ubicación…',
        dimmed: true,
      ),
      error: (error, _) => _Chip(
        icon: Icons.location_off_rounded,
        label: error is LocationFailure
            ? error.friendlyMessage
            : 'Ubicación no disponible',
        onTap: () => ref.invalidate(myLocationProvider),
      ),
      data: (position) {
        if (position == null) {
          return _Chip(
            icon: Icons.near_me_rounded,
            label: 'Usar mi ubicación',
            onTap: () => _activate(context, ref),
          );
        }
        return _Chip(
          icon: Icons.location_on_rounded,
          label:
              'Estás en ${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}',
        );
      },
    );
  }

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    try {
      final outcome = await ref.requestMyLocation();
      if (outcome == PermissionOutcome.granted || !context.mounted) return;
      context.showSnack(
        outcome == PermissionOutcome.deniedForever
            ? 'Permiso bloqueado. Actívalo desde la configuración de tu teléfono.'
            : 'Permiso de ubicación denegado.',
        isError: true,
      );
    } on LocationFailure catch (failure) {
      if (context.mounted) {
        context.showSnack(failure.friendlyMessage, isError: true);
      }
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.onTap,
    this.dimmed = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    // La tinta del chip se mide contra el campo (no es un blanco fijo): así el
    // mismo vidrio funciona sobre cualquier punto del degradado.
    final ink = AppColors.onColor(AppColors.fieldMid);
    final content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: dimmed ? 0.10 : 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: ink.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ink),
          const SizedBox(width: AppSpace.xs + 2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: ink, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return PressScale(
      scale: 0.95,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: content,
      ),
    );
  }
}
