import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/urbano_logo.dart';
import '../../../complaints/application/passenger_controller.dart';
import '../../../complaints/presentation/widgets/passenger_avatar.dart';
import '../../../complaints/presentation/widgets/passenger_name_sheet.dart';
import '../../../home/presentation/widgets/home_official_seal.dart';
import '../../../journey/application/trip_history_controller.dart';

/// Tarjeta blanca de sección con su rótulo (todas las secciones del perfil).
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: dark ? AppColors.lineDark : colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: AppSpace.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: dark ? colors.primary : AppColors.greenDeep,
                ),
                const SizedBox(width: AppSpace.sm),
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// Identidad anónima del pasajero, sobre el campo de marca: avatar, apodo y
/// el botón para cambiarlo (la misma hoja que usa el feed de Denuncias).
class ProfileIdentityCard extends ConsumerWidget {
  const ProfileIdentityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(passengerControllerProvider).valueOrNull;
    final text = context.text;
    return Container(
      key: const ValueKey('profile-identity'),
      decoration: BoxDecoration(
        gradient: urbanoGradient,
        borderRadius: AppRadius.card,
        boxShadow: AppTheme.softShadow(
          color: AppColors.primaryDark,
          opacity: 0.22,
        ),
      ),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: identity == null
                  ? const SizedBox.square(dimension: 56)
                  : PassengerAvatar.from(identity, size: 56),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity?.nickname ?? 'Pasajero',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge?.copyWith(
                    color: AppColors.onBrand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Así te ven en Denuncias. Sin cuenta ni datos personales.',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.onBrand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('profile-rename'),
            tooltip: 'Cambiar apodo',
            onPressed: identity == null
                ? null
                : () => showPassengerNameSheet(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.greenDeep,
            ),
            icon: const Icon(Icons.edit_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Apariencia: sistema · claro · oscuro (la misma preferencia que el botón de
/// tema de Inicio, persistida por [ThemeModeController.setMode]).
class ProfileAppearanceSection extends ConsumerWidget {
  const ProfileAppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);
    return ProfileSectionCard(
      title: 'Apariencia',
      icon: Icons.palette_outlined,
      child: SegmentedButton<ThemeMode>(
        key: const ValueKey('profile-theme'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            label: Text('Sistema'),
            icon: Icon(Icons.brightness_auto_rounded, size: 18),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            label: Text('Claro'),
            icon: Icon(Icons.light_mode_rounded, size: 18),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text('Oscuro'),
            icon: Icon(Icons.dark_mode_rounded, size: 18),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => ref
            .read(themeModeControllerProvider.notifier)
            .setMode(selection.first),
      ),
    );
  }
}

/// Historial de viajes recientes: cuántos hay y el botón para borrarlos.
class ProfileHistorySection extends ConsumerWidget {
  const ProfileHistorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(tripHistoryControllerProvider).valueOrNull?.length ?? 0;
    final colors = context.colors;
    final summary = switch (count) {
      0 => 'Todavía no planificaste viajes.',
      1 => '1 destino guardado en este teléfono.',
      _ => '$count destinos guardados en este teléfono.',
    };
    return ProfileSectionCard(
      title: 'Tus viajes',
      icon: Icons.schedule_rounded,
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary,
              style: context.text.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          TextButton.icon(
            key: const ValueKey('profile-clear-history'),
            onPressed: count == 0 ? null : () => _confirmClear(context, ref),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Borrar'),
            style: TextButton.styleFrom(foregroundColor: colors.error),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Borrar tus viajes recientes?'),
        content: const Text(
          'Se quitan los destinos guardados en este teléfono. No afecta a tus '
          'reportes en Denuncias.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('profile-clear-history-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(tripHistoryControllerProvider.notifier).clear();
    if (context.mounted) context.showSnack('Historial borrado.');
  }
}

/// Acerca de: logo, quién publica la app y de dónde salen los datos.
class ProfileAboutSection extends StatelessWidget {
  const ProfileAboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final body = context.text.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return ProfileSectionCard(
      title: 'Acerca de Urbano',
      icon: Icons.info_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: HomeOfficialSeal(),
                ),
              ),
              SizedBox(width: AppSpace.md),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: UrbanoLogo(height: 34),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'Transporte público de Santa Cruz de la Sierra: rutas, paradas y '
            'viajes con los datos GTFS de la red de micros.',
            style: body,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Mapas y direcciones © colaboradores de OpenStreetMap.',
            style: body,
          ),
        ],
      ),
    );
  }
}
