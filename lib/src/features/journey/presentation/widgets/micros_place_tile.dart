import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/animation/motion.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_formatters.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../../../core/widgets/route_badge.dart';
import '../../../../core/widgets/route_photo.dart';
import '../../../stops/data/stop_search_models.dart';
import '../../application/micros_catalog.dart';

/// Tarjeta de resultado de lugar: la esquina (nombre completo) y su distancia
/// (modo «cerca de mí») y, POR CADA LÍNEA servida, un bloque más completo —
/// **foto del micro** a la izquierda (tocable: se abre a pantalla completa), el
/// numeral con su **trayecto** (`longName`) y una fila de acciones con los
/// botones **Ida / Vuelta** (dibujan/borran ese sentido en el mapa, cada uno
/// independiente) más un acceso **Detalle** al micro completo (recorrido,
/// horarios, empresa). Las líneas repetidas del feed (un registro por
/// orientación) se muestran una sola vez.
class MicrosPlaceTile extends StatelessWidget {
  const MicrosPlaceTile({
    super.key,
    required this.hit,
    required this.activeKeys,
    required this.busyKey,
    required this.locked,
    required this.directionsOf,
    required this.onToggleDirection,
  });

  final StopHit hit;

  /// Claves `routeId#directionId` ya dibujadas en el mapa.
  final Set<String> activeKeys;

  /// Clave del toggle en vuelo (deshabilita mientras hay una petición).
  final String? busyKey;

  /// Bloqueado porque OTRA dirección está en vuelo (toggle de red pendiente).
  final bool locked;

  /// Sentidos (Ida/Vuelta) que sirve cada línea, con headsign si ya se conoce.
  final List<MicroDirection> Function(StopRouteRef route) directionsOf;

  /// Dibuja/borra en el mapa UN sentido de una línea del resultado.
  final Future<void> Function(StopRouteRef route, int directionId)
  onToggleDirection;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final routes = uniqueStopRoutes(hit.routes);
    return GlassCard(
      radius: AppRadius.tile,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.near_me_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hit.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (hit.distanceMeters != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        _distance(hit.distanceMeters!),
                        style: text.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Sin líneas servidas (feed pequeño): aviso sutil, sin acción.
            if (routes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ninguna línea pasa por este lugar',
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  children: [
                    for (final route in routes) _routeBlock(context, route),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Bloque de una línea: foto + numeral/trayecto + sentido(s) + Detalle.
  ///
  /// La foto va fija a la izquierda (46 px) y el resto dentro de un `Expanded`,
  /// así ninguna línea larga desborda el panel: el badge va en `Flexible` (se
  /// corta con ellipsis).
  ///
  /// Los botones **no** van en un `Wrap` (eso los dejaba a veces en una fila y a
  /// veces en dos, según el ancho — irregular). Van en un layout **determinista y
  /// simétrico**: una sola fila de sentidos donde cada botón (`Ida`, `Vuelta`) se
  /// estira con `Expanded` al mismo ancho y llena la tarjeta, y debajo **Detalle**
  /// como una fila completa. Así todas las líneas del resultado se ven iguales.
  Widget _routeBlock(BuildContext context, StopRouteRef route) {
    final colors = context.colors;
    final text = context.text;
    final tint = AppColors.fromHex(route.color);
    final directions = directionsOf(route);
    final trayecto = (route.longName?.trim().isNotEmpty ?? false)
        ? route.longName!
        : 'Línea ${route.shortName}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MicroThumb(route: route, tint: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: RouteBadge(
                        label: route.shortName,
                        colorHex: route.color,
                        size: RouteBadgeSize.small,
                        onTap: () => _openDetail(context, route),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trayecto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Sentidos en UNA sola fila, cada botón al mismo ancho (Expanded)
                // para que la tarjeta se vea simétrica y llena el ancho disponible.
                Row(
                  children: [
                    for (var i = 0; i < directions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _PlaceDirectionChip(
                          routeId: route.id,
                          direction: directions[i],
                          tint: tint,
                          active: activeKeys.contains(
                            microDirectionKey(
                              route.id,
                              directions[i].directionId,
                            ),
                          ),
                          loading:
                              busyKey ==
                              microDirectionKey(
                                route.id,
                                directions[i].directionId,
                              ),
                          enabled: !locked,
                          onTap: () => onToggleDirection(
                            route,
                            directions[i].directionId,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Detalle como fila completa, alineada con la de sentidos.
                SizedBox(
                  width: double.infinity,
                  child: _PlaceDetailChip(
                    routeId: route.id,
                    enabled: !locked,
                    onTap: () => _openDetail(context, route),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _distance(double meters) => Fmt.distance(meters);

  void _openDetail(BuildContext context, StopRouteRef micro) {
    unawaited(
      context.push(UrbanoRoutes.routeDetail(micro.id, from: 'panel-lugares')),
    );
  }
}

/// Quita líneas repetidas (mismo `id`) conservando el primer orden. Cubre
/// también los `StopHit` construidos a mano (tests), no solo los que vienen
/// de `StopHit.fromJson`.
List<StopRouteRef> uniqueStopRoutes(List<StopRouteRef> routes) {
  var duplicated = false;
  final ids = <String>{};
  for (final route in routes) {
    if (!ids.add(route.id)) {
      duplicated = true;
      break;
    }
  }
  if (!duplicated) return routes;
  final seen = <String>{};
  return [
    for (final route in routes)
      if (seen.add(route.id)) route,
  ];
}

/// Miniatura del micro para el resultado de lugares: la **foto real** (`imageUrl`
/// del feed) recortada a 46 px y TOCABLE — abre el visor a pantalla completa con
/// un vuelo desde aquí. Sin foto, la franja la pinta el color de la línea con un
/// bus encima, así la tarjeta nunca pierde su identidad visual.
class _MicroThumb extends StatelessWidget {
  const _MicroThumb({required this.route, required this.tint});

  final StopRouteRef route;
  final Color tint;

  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.sm);
    final url = route.imageUrl;
    final Widget face = url == null
        ? Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tint, Color.lerp(tint, Colors.black, 0.45)!],
              ),
            ),
            child: Icon(
              Icons.directions_bus_rounded,
              size: 20,
              color: AppColors.onColor(tint),
            ),
          )
        : RoutePhoto(url: url, width: _size, height: _size, radius: radius);
    final box = SizedBox(
      width: _size,
      height: _size,
      child: ClipRRect(borderRadius: radius, child: face),
    );
    if (url == null) return box;
    return PressScale(
      child: GestureDetector(
        key: ValueKey('place-route-photo-${route.id}'),
        onTap: () => openPhotoViewer(
          context,
          url: url,
          tag: photoHeroTag('lugares', route.id),
          title: (route.longName?.trim().isNotEmpty ?? false)
              ? route.longName!
              : 'Línea ${route.shortName}',
          subtitle: 'Foto del micro',
          accent: tint,
          sourceRadius: AppRadius.sm,
        ),
        child: box,
      ),
    );
  }
}

/// Chip de UN sentido (Ida/Vuelta) de una línea del resultado: al tocarlo se
/// dibuja/borra SOLO ese recorrido en el mapa. Activo: relleno sólido del color
/// de la línea; inactivo: insinuación del tinte sobre la superficie. El disco del
/// ícono (flecha según el sentido) hereda el foreground calculado por contraste,
/// porque un color de línea claro o casi negro nunca se usa tal cual para letras.
/// `loading` muestra un indicador estático (nada de `repeat()`: rompería
/// `pumpAndSettle`); `enabled=false` (otra dirección en vuelo) baja la opacidad.
class _PlaceDirectionChip extends StatelessWidget {
  const _PlaceDirectionChip({
    required this.routeId,
    required this.direction,
    required this.tint,
    required this.active,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final String routeId;
  final MicroDirection direction;
  final Color tint;
  final bool active;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final radius = BorderRadius.circular(AppRadius.pill);
    final fill = active ? tint : Color.lerp(colors.surface, tint, 0.10)!;
    final ink = active
        ? AppColors.onColor(tint, preferred: AppColors.fromHex('FFFFFF'))
        : AppColors.legible(tint, fill, minContrast: 3);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: fill,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('place-route-toggle-$routeId#${direction.directionId}'),
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  loading
                      ? Icons.pending_rounded
                      : direction.directionId == 0
                      ? Icons.arrow_circle_right_outlined
                      : Icons.arrow_circle_left_outlined,
                  size: 15,
                  color: ink,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    direction.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (text.labelMedium ?? text.bodySmall)?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Acceso «Detalle» de una línea del resultado: abre la pantalla del micro
/// completo (recorrido, horarios, empresa). Neutro (color de superficie) para no
/// competir con el tinte de los botones de sentido de al lado.
class _PlaceDetailChip extends StatelessWidget {
  const _PlaceDetailChip({
    required this.routeId,
    required this.enabled,
    required this.onTap,
  });

  final String routeId;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final radius = BorderRadius.circular(AppRadius.pill);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: colors.surfaceContainerHighest,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('place-route-detalle-$routeId'),
          borderRadius: radius,
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Detalle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (text.labelMedium ?? text.bodySmall)?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
