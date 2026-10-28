import 'package:flutter/material.dart';

import '../animation/motion.dart';
import 'app_colors.dart';
import 'typography.dart';

/// Escala de espaciado (múltiplos de 4/8).
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(lg);
}

/// Radios generosos y sombras suaves.
abstract final class AppRadius {
  /// Escala de radios del sistema. Ningún widget escribe un radio a mano: se
  /// elige el paso que corresponde al elemento. `tile` e `input` son los dos
  /// pasos intermedios que la escala anterior no sabía nombrar (pastilla
  /// compacta y campo/botón secundario); salieron de unificar los ~40
  /// literales sueltos que había repartidos por la app.
  static const double sm = 10;
  static const double tile = 12;
  static const double input = 14;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Cápsula. Al ser mayor que cualquier lado, sirve también para las barras
  /// finas (alto 4 px + `pill` dibuja exactamente la cápsula que antes se
  /// lograba con un `2` a medida: radio = media altura).
  static const double pill = 999;

  static final BorderRadius card = BorderRadius.circular(lg);
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Degradado de marca reutilizable: va de la orilla (verde agua brillante) a
/// la laguna profunda. La mitad del recorrido ya es verde agua sólido
/// (paradas inclinadas hacia el color principal) para que la identidad se
/// lea sólida, no pastel. Se usa en la cabecera del home, en la tarjeta CTA
/// y en el logo para que la identidad sea la misma en todos lados.
const LinearGradient urbanoGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.aqua, AppColors.primary, AppColors.primaryDark],
  stops: [0.0, 0.58, 1.0],
);

/// Tema claro/oscuro de Urbano (Material 3, semillas propias).
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// Sombra suave reutilizable.
  static List<BoxShadow> softShadow({
    Color color = AppColors.ink,
    double opacity = 0.08,
    double blur = 24,
    double dy = 8,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: blur,
      offset: Offset(0, dy),
    ),
  ];

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seedScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    // Ambos modos se controlan explícitamente sobre la semilla: en claro,
    // grises neutros de Apple con los tres acentos de marca; en oscuro,
    // grafito sobre negro con un primario luminoso para que siga vivo.
    final scheme = isDark
        ? seedScheme.copyWith(
            primary: AppColors.primarySoftDark,
            onPrimary: AppColors.onPrimaryDark,
            primaryContainer: AppColors.primaryContainerDark,
            onPrimaryContainer: AppColors.onPrimaryContainerDark,
            secondary: AppColors.aquaSoftDark,
            tertiary: AppColors.accentSoftDark,
            surface: AppColors.surfaceDark,
            surfaceContainerLowest: AppColors.canvasDark,
            surfaceContainerLow: AppColors.surfaceContainerLowDark,
            surfaceContainer: AppColors.surfaceContainerDark,
            surfaceContainerHigh: AppColors.surfaceContainerHighDark,
            surfaceContainerHighest: AppColors.surfaceContainerHighestDark,
            onSurface: AppColors.inkDark,
            onSurfaceVariant: AppColors.inkDarkSoft,
            outline: AppColors.outlineDark,
            outlineVariant: AppColors.outlineVariantDark,
          )
        : seedScheme.copyWith(
            primary: AppColors.primary,
            primaryContainer: AppColors.primaryContainerLight,
            onPrimaryContainer: AppColors.onPrimaryContainerLight,
            secondary: AppColors.aquaDeep,
            secondaryContainer: AppColors.secondaryContainerLight,
            onSecondaryContainer: AppColors.onSecondaryContainerLight,
            tertiary: AppColors.accentDeep,
            tertiaryContainer: AppColors.tertiaryContainerLight,
            onTertiaryContainer: AppColors.onTertiaryContainerLight,
            surface: AppColors.surfaceLight,
            surfaceContainerLowest: AppColors.canvasLight,
            surfaceContainerLow: const Color(0xFFEDEDF2),
            surfaceContainer: const Color(0xFFE9E9EE),
            surfaceContainerHigh: const Color(0xFFE4E4EA),
            surfaceContainerHighest: const Color(0xFFE0E0E6),
            onSurface: AppColors.ink,
            onSurfaceVariant: AppColors.inkSoft,
            outline: AppColors.outlineLight,
            outlineVariant: AppColors.outlineVariantLight,
          );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final textTheme = AppTypography.apply(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.canvasDark
          : AppColors.canvasLight,
      splashFactory: InkSparkle.splashFactory,
      // Movimiento propio: las páginas que se abren (detalle de ruta, Info)
      // suben por la ventana con fundido en vez de un Zoom/Cupertino genérico.
      // Android se queda deliberadamente con `PredictiveBackPageTransitionsBuilder`
      // (el gesto de «atrás predictivo» ES la motion de la plataforma; lo peor
      // que podíamos hacer era pisarlo).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: UrbanoPageTransitions(),
          TargetPlatform.macOS: UrbanoPageTransitions(),
          TargetPlatform.windows: UrbanoPageTransitions(),
          TargetPlatform.linux: UrbanoPageTransitions(),
          TargetPlatform.fuchsia: UrbanoPageTransitions(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      // Tarjetas 100% planas en ambos modos, como las listas agrupadas de
      // iOS: la separación la dan contraste y separadores, no bordes ni
      // sombras.
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      // Campos al estilo search field de iOS: píldora con relleno gris suave
      // y sin borde; el foco solo enciende el acento.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFE9E9EE),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 52),
          elevation: 0,
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: AppTypography.semiBold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: 2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: isDark ? scheme.surfaceContainerLow : Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: AppTypography.semiBold),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        showDragHandle: true,
        // Agarre discreto, como las hojas de iOS.
        dragHandleColor: scheme.outlineVariant,
        dragHandleSize: const Size(48, 4.5),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
