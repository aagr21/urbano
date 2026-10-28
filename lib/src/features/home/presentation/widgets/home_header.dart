import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../core/widgets/urbano_logo.dart';
import 'home_route_lattice.dart';

/// Cabecera de identidad: degradado de marca sobre los **anil  los de la ciudad**
/// pintados (con una unidad que recorre su corredor), logo de la micro, saludo,
/// ubicación y buscador.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.xl),
      ),
      child: Container(
        decoration: const BoxDecoration(gradient: urbanoGradient),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Trama de anillos + micro que circula: la cabecera se mueve sola
            // en cuanto abre la app (dos vueltas y queda en reposo, para no
            // dejar un ticker eterno que congele los `pumpAndSettle` de los
            // tests del planeador).
            const Positioned.fill(child: HomeRouteLattice()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const UrbanoLogo(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Env.appName,
                            style: AppTypography.wordmark(
                              text.titleLarge?.copyWith(color: Colors.white),
                            ),
                          ),
                          Text(
                            Env.tagline,
                            style: text.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push('/info'),
                      tooltip: 'Acerca de Urbano',
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '¿A dónde vas hoy?',
                  style: text.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${Fmt.greeting()} · ${_today()}',
                  style: text.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const _LocationChip(),
                const SizedBox(height: 16),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    style: text.bodyMedium?.copyWith(
                      color: context.colors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Busca rutas…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar',
                              onPressed: controller.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: dimmed ? 0.12 : 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
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
