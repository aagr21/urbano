import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/extensions.dart';
import '../utils/runtime_flags.dart';

/// Foto real del micro (imageUrl de `backend/micros.csv`). Se recorta con
/// [BoxFit.cover] al tamaño pedido; con [showFull] la foto se ve COMPLETA a
/// lo vertical (ajustada al alto) y el sobrante horizontal lo rellena la
/// MISMA foto difuminada de fondo (estilo cover de Spotify/WhatsApp). Falla a
/// un placeholder con identidad (bus estilizado sobre hoja neutral) si la red
/// no responde. En pruebas nunca intenta la red: el placeholder asegura
/// `pump()`/`pumpAndSettle()` deterministas.
class RoutePhoto extends StatelessWidget {
  const RoutePhoto({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius,
    this.fit = BoxFit.cover,
    this.showFull = false,
  });

  final String url;
  final double? width;
  final double? height;

  /// Radio de escala; si es null es el borde sugerido por [AppRadius].
  final BorderRadius? radius;

  /// Ajuste de la imagen nítida del frente.
  final BoxFit fit;

  /// Foto completa vertical con fondo difuminado del mismo origen.
  final bool showFull;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(AppRadius.input),
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: isRunningUnderTest
            ? _Fallback(small: (width ?? 0) < 100)
            : showFull
            ? Stack(
                fit: StackFit.expand,
                children: [
                  // Fondo: la misma foto a full-bleed, difuminada — llena el
                  // sobrante horizontal. Imagen estática, no BackdropFilter:
                  // se rasteriza una vez, sin re-blur por frame (regla de la
                  // casa para no lanzar jank en Android bajo).
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      frameBuilder: _fade,
                    ),
                  ),
                  // Frente: la foto completa, ajustada al alto disponible.
                  Image.network(url, fit: fit, frameBuilder: _fade),
                ],
              )
            : Image.network(
                url,
                width: width,
                height: height,
                fit: fit,
                frameBuilder: _fade,
              ),
      ),
    );
  }

  /// Aparición suave cuando llega el primer frame decodificado.
  static Widget _fade(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSync,
  ) {
    if (wasSync) return child;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      opacity: frame == null ? 0 : 1,
      child: child,
    );
  }
}

/// Placeholder: bus estilizado centrado — siempre válido, sin texto.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.small});

  final bool small;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SizedBox.square(
        dimension: small ? 44 : 160,
        child: Icon(
          Icons.directions_bus_rounded,
          size: small ? 20 : 40,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
