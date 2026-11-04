import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/location/startup_location_gate.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';

/// `MaterialApp.router` con tema claro/oscuro controlable por el usuario
/// ([themeModeControllerProvider], persiste en preferencias) y es-ES.
class UrbanoApp extends ConsumerWidget {
  const UrbanoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      title: 'Urbano',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('es', 'BO'),
      supportedLocales: const [Locale('es', 'BO'), Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Chrome del sistema (status bar + barra de navegación Android) del
      // color del tema ACTIVO: sin esto, en oscuro quedaba blanca/transparente
      // y la app "no era toda oscura". El `builder` corre dentro del
      // WidgetsApp, donde MediaQuery ya refleja el brillo real del sistema.
      //
      // Como el usuario ya puede forzar claro/oscuro por encima del sistema,
      // el chrome sigue el BRILLO EFECTIVO (modo elegido + brillo del
      // sistema como base cuando el modo es `ThemeMode.system`).
      builder: (context, child) {
        final platformBrightness = MediaQuery.of(context).platformBrightness;
        final effectiveBrightness = switch (themeMode) {
          ThemeMode.system => platformBrightness,
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
        };
        final overlay = switch (effectiveBrightness) {
          Brightness.dark => const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: AppColors.surfaceDark,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          Brightness.light => const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: AppColors.canvasLight,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        };
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          // Puerta de arranque: pide el permiso de ubicación pendiente al
          // lanzar la app y activa el auto-follow del mapa si se concede.
          child: StartupLocationGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
