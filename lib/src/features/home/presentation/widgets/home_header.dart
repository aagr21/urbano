import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/config/env.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/html_design_tokens.dart' show HtmlDesignTokens;
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/location.dart';
import '../../../../core/widgets/urbano_menu.dart'
    show showUrbanoMenu, UrbanoSection;
import 'home_route_lattice.dart';

/// **Cabecera de Inicio**, sobre el lienzo de la portada.
///
/// La referencia abre con dos franjas: la **banda oficial** —escudo del
/// Gobierno Autónomo Municipal de Santa Cruz de la Sierra a la izquierda y la
/// píldora «Transporte Oficial» a la derecha— y, debajo, la marca centrada
/// (wordmark con su punto, lema, botón de menú a la derecha y la píldora de
/// ubicación). La banda es lo que firma la app como servicio municipal; el
/// escudo es una imagen (no se redibuja) y conserva su relación de aspecto.
///
/// El buscador de rutas se retiró con la poda de la portada: la pantalla debe
/// caber entera (cabecera, accesos, «¿A dónde vas?» y viajes recientes) y el
/// catálogo ya se abre desde el acceso **Micros**. La cabecera se queda en
/// banda oficial + marca + ubicación.
///
/// Encima del lienzo todo se mide con los tokens del tema ([ColorScheme]), de
/// modo que el mismo bloque funciona en claro y en oscuro sin tintas fijas.
/// La trama de anillos de Santa Cruz sigue de fondo, muy tenue, para que la
/// portada no pierda el movimiento de la marca.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        // Anillos de la ciudad de fondo.
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.55,
              child: HomeRouteLattice(tint: colors.primary),
            ),
          ),
        ),
        Column(
          children: [
            SizedBox(height: topInset),
            const _OfficialBand(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg + AppSpace.xs,
                AppSpace.xxl,
                AppSpace.lg + AppSpace.xs,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Escalado solo en pintura: el alto de la cabecera
                          // (y por tanto que la portada quepa sin scroll) no
                          // cambia por agrandar la marca.
                          Transform.scale(
                            scale: 1.5,
                            alignment: Alignment.bottomCenter,
                            child: const _Wordmark(),
                          ),
                          // El trazo y la parada asoman bajo la línea base
                          // (escalados ×1,5): el lema les deja ese aire.
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            Env.tagline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        right: 0,
                        top: -6,
                        child: _MenuButton(
                          key: const ValueKey('home-menu-button'),
                          onTap: () => showUrbanoMenu(
                            context,
                            current: UrbanoSection.home,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  const _LocationPill(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Banda oficial de la portada.
///
/// Firma la app como servicio del municipio: escudo a la izquierda y la
/// píldora «Transporte Oficial» a la derecha, sobre una franja clara que
/// separa la cabecera del lienzo de la portada. Va a sangre horizontal; el
/// área del sistema la resuelve [HomeHeader] con su respiro de lienzo.
class _OfficialBand extends StatelessWidget {
  const _OfficialBand();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Franja de papel: un blanco apenas teñido de aqua que se disuelve hacia
    // abajo, para que la banda oficial no corte el lienzo con una losa dura.
    // En oscuro sigue la superficie del tema, nunca una franja clara.
    final fillTop = dark
        ? colors.surface
        : AppColors.tint(AppColors.aqua, colors.surface, 0.09);
    final fillBottom = dark
        ? colors.surfaceContainerLow
        : AppColors.tint(AppColors.aqua, colors.surface, 0.02);
    final hairline = dark
        ? AppColors.lineDark
        : colors.primary.withValues(alpha: 0.14);

    return DecoratedBox(
      key: const ValueKey('home-official-band'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillTop, fillBottom],
        ),
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg + AppSpace.xs,
          AppSpace.sm,
          AppSpace.lg + AppSpace.xs,
          AppSpace.sm,
        ),
        child: Row(
          children: [
            // El escudo es una imagen: se escala, nunca se redibuja.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Semantics(
                  label:
                      'Gobierno Autónomo Municipal de Santa Cruz de la Sierra',
                  image: true,
                  child: const _OfficialSeal(),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            const _OfficialPill(),
          ],
        ),
      ),
    );
  }
}

/// Escudo oficial en PNG (fondo transparente).
///
/// En claro cae directamente sobre la franja; en oscuro el trazo negro del
/// escudo se perdería contra el grafito, así que se monta en una placa blanca
/// —el único blanco duro del archivo, y está justificado: la imagen es fija y
/// no puede recolorearse por tema—.
class _OfficialSeal extends StatelessWidget {
  const _OfficialSeal();

  static const String _asset = 'assets/images/gobierno-santa-cruz.png';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final image = Image.asset(
      _asset,
      height: 34,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      // El escudo ya viene recortado; se declara su tamaño real para que el
      // layout no dependa del decodificado asíncrono.
      width: 34 * 900 / 370,
    );
    if (!dark) return image;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: image,
    );
  }
}

/// Píldora «Transporte Oficial»: punto aqua, filete de marca y tinta legible
/// sobre el relleno realmente pintado.
class _OfficialPill extends StatelessWidget {
  const _OfficialPill();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = AppColors.tint(
      colors.primary,
      colors.surface,
      dark ? 0.18 : 0.07,
    );
    final ink = dark
        ? colors.onSurface
        : AppColors.legible(colors.primary, fill);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dark ? colors.secondary : AppColors.aqua,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpace.sm - 2),
          Text(
            'Transporte Oficial',
            maxLines: 1,
            style: text.labelSmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón del menú: estilo del HTML (blanco con sombra suave, bordes redondeados).
class _MenuButton extends StatelessWidget {
  const _MenuButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.md);
    final bg = dark ? colors.surface.withValues(alpha: 0.9) : Colors.white;
    final iconInk = dark ? colors.onSurface : HtmlDesignTokens.slate600;

    return PressScale(
      scale: 0.95,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(
            color: dark ? AppColors.lineDark : HtmlDesignTokens.slate100,
          ),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: iconInk.withValues(alpha: 0.08),
            child: Center(
              child: Tooltip(
                message: 'Menú',
                child: _HamburgerIcon(color: iconInk),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ícono de hamburguesa del HTML: tres líneas redondeadas.
class _HamburgerIcon extends StatelessWidget {
  const _HamburgerIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 3,
        children: [_Line(), _Line(), _Line()],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 2.5,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? context.colors.onSurface
            : HtmlDesignTokens.slate800,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// «Tu ubicación ›»: estilo del HTML (glass-pill con punto esmeralda).
///
/// El estado de permisos se cuenta con el ícono y la etiqueta, y se toca para
/// activar o refrescar. Sin ubicación la píldora invita («Usar mi ubicación»);
/// con ubicación resume y deja refrescar.
class _LocationPill extends ConsumerWidget {
  const _LocationPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final location = ref.watch(myLocationProvider);

    // Colores del HTML: glass-pill blanco con borde esmeralda.
    final bg = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.82);
    final border = dark
        ? colors.primary.withValues(alpha: 0.2)
        : HtmlDesignTokens.emerald100;
    final ink = dark ? colors.onSurface : HtmlDesignTokens.slate700;
    const dotColor = HtmlDesignTokens.emerald500;

    final ({String label, VoidCallback? onTap, bool live}) state = location
        .when(
          loading: () =>
              (label: 'Buscando ubicación…', onTap: null, live: false),
          error: (error, _) => (
            label: error is LocationFailure
                ? error.friendlyMessage
                : 'Ubicación no disponible',
            onTap: () => ref.invalidate(myLocationProvider),
            live: false,
          ),
          data: (position) => position == null
              ? (
                  label: 'Usar mi ubicación',
                  onTap: () => _activate(context, ref),
                  live: false,
                )
              : (
                  label: 'Tu ubicación',
                  onTap: () => ref.invalidate(myLocationProvider),
                  live: true,
                ),
        );

    const radius = BorderRadius.all(Radius.circular(AppRadius.pill));
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md + 2,
        vertical: AppSpace.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: state.live
                  ? [
                      BoxShadow(
                        color: dotColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: AppSpace.xs + 2),
          Flexible(
            child: Text(
              state.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (state.onTap != null) ...[
            const SizedBox(width: AppSpace.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: dark ? colors.onSurfaceVariant : HtmlDesignTokens.slate400,
            ),
          ],
        ],
      ),
    );

    final shell = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: state.onTap == null
            ? content
            : InkWell(
                onTap: state.onTap,
                borderRadius: radius,
                splashColor: colors.onSurface.withValues(alpha: 0.06),
                child: content,
              ),
      ),
    );

    return Center(child: shell);
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

/// **Wordmark de la portada**: «Urbano» como un recorrido.
///
/// Tres capas que cuentan la marca sin decir nada:
///  * las letras en Fredoka con un degradado de verde profundo a esmeralda
///    (en oscuro, de la tinta del tema a menta), en vez de un color plano;
///  * debajo, el **trazo del recorrido**: una línea que nace bajo la «U», se
///    dibuja una sola vez al llegar (`Ambient(cycles: 1)`, reposa trazada) y
///    termina en el punto final;
///  * ese punto es la **parada**: un aro con centro de la superficie y halo,
///    el destino de la línea.
///
/// El texto sigue siendo un `Text('Urbano')` (los tests lo buscan así): el
/// degradado lo pone un `ShaderMask`, no una imagen.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  static const double _fontSize = 34;
  static const double _stop = 9;

  /// Alto de la caja del trazo (la curva oscila ±2 px dentro de ella).
  static const double _stroke = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final inkTop = dark ? colors.onSurface : HtmlDesignTokens.darkWordmark;
    final inkBottom = dark
        ? HtmlDesignTokens.emerald300
        : HtmlDesignTokens.emerald600;
    final route = dark
        ? HtmlDesignTokens.emerald400
        : HtmlDesignTokens.emerald500;

    final word = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [inkTop, inkTop, inkBottom],
        stops: const [0, 0.35, 1],
      ).createShader(bounds),
      child: Text(
        Env.appName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.wordmark(
          text.headlineMedium?.copyWith(
            // El color real lo pone el degradado; este solo da opacidad.
            color: inkTop,
            fontSize: _fontSize,
            height: 1,
            letterSpacing: -0.6,
          ),
        ),
      ),
    );

    return Ambient(
      cycles: 1,
      period: const Duration(milliseconds: 1400),
      child: word,
      builder: (context, t, _, child) {
        final draw = Curves.easeInOutCubic.transform(t);
        // La parada «llega» cuando el trazo la alcanza.
        final stopIn = Curves.easeOutBack.transform(
          ((t - 0.7) / 0.3).clamp(0.0, 1.0),
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // El trazo corre sobre la línea base y termina en el centro de la
            // parada. Vive fuera del layout: no empuja el lema.
            Positioned(
              left: 2,
              right: _stop / 2,
              bottom: -_stroke / 2,
              height: _stroke,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RouteStrokePainter(
                    progress: draw,
                    from: route.withValues(alpha: 0.12),
                    to: route,
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: child!),
                const SizedBox(width: 3),
                // Centro de la parada en la línea base, igual que el trazo.
                Transform.translate(
                  offset: const Offset(0, _stop / 2),
                  child: Transform.scale(
                    scale: stopIn,
                    child: _StopDot(color: route, size: _stop),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Parada al final del trazo: aro del color de la ruta, centro de la
/// superficie (se lee igual en claro y oscuro) y un halo suave.
class _StopDot extends StatelessWidget {
  const _StopDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Trazo del recorrido bajo el wordmark: una curva suave (sube apenas y
/// vuelve) que se dibuja de izquierda a derecha hasta [progress] y se aclara
/// hacia su origen, como una línea que viene de lejos.
class _RouteStrokePainter extends CustomPainter {
  const _RouteStrokePainter({
    required this.progress,
    required this.from,
    required this.to,
  });

  final double progress;
  final Color from;
  final Color to;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.width <= 0) return;
    final y = size.height / 2;
    final path = Path()
      ..moveTo(0, y)
      ..cubicTo(
        size.width * 0.3,
        y + 2.2,
        size.width * 0.65,
        y - 2.2,
        size.width,
        y,
      );
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(colors: [from, to])
          .createShader(Offset.zero & size);
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(_RouteStrokePainter old) =>
      old.progress != progress || old.from != from || old.to != to;
}
