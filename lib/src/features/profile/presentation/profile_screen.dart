import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/animation/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/extensions.dart';
import 'widgets/profile_sections.dart';

/// **Perfil** (pestaña de la barra inferior).
///
/// Urbano no tiene cuentas: el «perfil» es lo que este teléfono guarda de su
/// pasajero. Reúne en un solo lugar lo que antes estaba disperso:
///
/// 1. La identidad anónima con la que participa en Denuncias (avatar y apodo,
///    editable con la misma hoja del feed).
/// 2. La apariencia (sistema · claro · oscuro), la misma preferencia que el
///    botón de la cabecera de Inicio.
/// 3. El historial de viajes recientes, con la opción de borrarlo.
/// 4. Acerca de: quién publica la app y de dónde salen los datos.
///
/// La pantalla solo monta secciones (`widgets/profile_sections.dart`); cada
/// una lee su provider.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLowest,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.lg,
          topInset + AppSpace.lg,
          AppSpace.lg,
          AppSpace.xl,
        ),
        children: [
          Text(
            'Perfil',
            style: context.text.headlineMedium?.copyWith(
              color: context.colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          const Reveal(child: ProfileIdentityCard()),
          const SizedBox(height: AppSpace.lg),
          const Reveal(index: 1, child: ProfileAppearanceSection()),
          const SizedBox(height: AppSpace.lg),
          const Reveal(index: 2, child: ProfileHistorySection()),
          const SizedBox(height: AppSpace.lg),
          const Reveal(index: 3, child: ProfileAboutSection()),
        ],
      ),
    );
  }
}
