import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../home/presentation/widgets/home_route_lattice.dart';
import '../../../routes/data/route_models.dart';
import 'complaint_route_image.dart';

/// Nombre con el que el formulario muestra una línea: su recorrido o, si el
/// feed no lo trae, «Micro N».
String complaintRouteTitle(RouteSummary route) =>
    route.longName.isEmpty ? 'Micro ${route.shortName}' : route.longName;

/// Cabecera de marca del formulario («Cuéntanos qué ocurrió»), con la misma
/// trama de anillos del feed y del home.
class ComplaintFormHero extends StatelessWidget {
  const ComplaintFormHero({super.key});

  @override
  Widget build(BuildContext context) {
    // Tinta medida contra el degradado de marca (nunca un blanco a mano).
    final onGradient = AppColors.onColor(AppColors.primaryDark);
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        boxShadow: AppTheme.softShadow(
          color: AppColors.primaryDark,
          opacity: 0.16,
        ),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: urbanoGradient),
          child: Stack(
            children: [
              const Positioned.fill(child: HomeRouteLattice()),
              Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: onGradient, size: 32),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cuéntanos qué ocurrió',
                            style: context.text.titleLarge?.copyWith(
                              color: onGradient,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            'Tu reporte es anónimo y nos ayuda a mejorar.',
                            style: TextStyle(
                              color: onGradient.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
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
}

/// Campo «¿Qué micro está involucrado?»: muestra la línea elegida (o la
/// invitación a buscarla) y valida que haya una. Elegir es cosa de quien
/// lo usa ([onPick] devuelve la línea nueva o `null` si se canceló).
class ComplaintRouteField extends StatelessWidget {
  const ComplaintRouteField({
    super.key,
    required this.route,
    required this.onPick,
  });

  final RouteSummary? route;
  final Future<RouteSummary?> Function() onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FormField<RouteSummary>(
      initialValue: route,
      validator: (value) =>
          value == null ? 'Selecciona el micro relacionado' : null,
      builder: (field) {
        final current = field.value;
        return InkWell(
          onTap: () async {
            final picked = await onPick();
            if (picked != null) field.didChange(picked);
          },
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                decoration: BoxDecoration(
                  color: current == null
                      ? colors.surfaceContainerLow
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  border: Border.all(
                    color: field.errorText != null
                        ? colors.error
                        : current == null
                        ? colors.outlineVariant
                        : colors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    if (current == null)
                      Icon(Icons.search_rounded, color: colors.onSurfaceVariant)
                    else
                      ComplaintRouteImage(route: current),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: current == null
                          ? Text(
                              'Buscar y seleccionar una línea',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            )
                          : Text(
                              complaintRouteTitle(current),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              if (field.errorText != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpace.md,
                    top: AppSpace.xs,
                  ),
                  child: Text(
                    field.errorText!,
                    style: TextStyle(color: colors.error, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Campo de descripción (opcional, hasta 2000 caracteres).
class ComplaintDescriptionField extends StatelessWidget {
  const ComplaintDescriptionField({super.key, required this.controller});

  final TextEditingController controller;

  static const _border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
  );

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    minLines: 5,
    maxLines: 7,
    maxLength: 2000,
    decoration: const InputDecoration(
      hintText: 'Cuéntanos brevemente qué pasó (opcional).',
      filled: true,
      border: _border,
      enabledBorder: _border,
      focusedBorder: _border,
      errorBorder: _border,
      focusedErrorBorder: _border,
    ),
  );
}
