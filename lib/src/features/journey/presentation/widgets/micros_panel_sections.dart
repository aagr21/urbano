part of 'journey_micros_sheet.dart';

/// Secciones visuales del panel (encabezado, interruptor de modo, buscador,
/// acciones y listados de líneas) como extension del [_MicrosPanelState]:
/// métodos puros de pintura sobre el mismo estado — el archivo se lee de
/// arriba hacia abajo: primero la conducta (State), después el aspecto.
extension _MicrosPanelSections on _MicrosPanelState {
  /// Fondo vivo del cajón: dos manchas suaves (el verde agua de la marca y el
  /// coral del atardecer) que derivan **muy** despacio tras el encabezado, más
  /// una guía de color en el borde superior. Es UN solo [Ambient] para todo el
  /// panel y va dentro de un [IgnorePointer]: el listado y sus toques no se
  /// enteran del movimiento ni del color.
  Widget _backdrop(ColorScheme colors) {
    return IgnorePointer(
      child: ClipRect(
        child: Ambient(
          period: const Duration(seconds: 12),
          builder: (_, _, phase, _) {
            // Deriva senoidal: la mancha se va y vuelve sin saltos de bucle.
            final drift = math.sin(phase * 2 * math.pi);
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -70 + drift * 18,
                  top: -110,
                  child: _aura(colors.primary, 250, 0.16),
                ),
                Positioned(
                  right: -80 - drift * 14,
                  top: -60,
                  child: _aura(colors.tertiary, 200, 0.1),
                ),
                // Filo de color: el panel se lee «de Urbano» desde el borde.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          Color.lerp(colors.primary, colors.secondary, 0.8)!,
                          colors.tertiary,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Mancha radial del fondo (barata: un degradado, sin blur).
  Widget _aura(Color color, double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ),
    ),
  );

  /// Encabezado: insignia de bus con el degradado de marca (que respira cuando
  /// hay recorridos dibujados) + título + subtítulo animado con el conteo.
  Widget _header(ColorScheme colors, TextTheme text, int activeCount) {
    final alive = activeCount > 0;
    // Mancha del subtítulo «en vivo»: tinte de marca lo bastante suave como
    // para que la tinta calculada encima conserve el contraste de la casa.
    final tintWash = Color.lerp(colors.surface, colors.primary, 0.14)!;
    final liveInk = AppColors.legible(colors.primary, tintWash);
    // El ícono del bus se arma una sola vez: con recorridos activos entra
    // flotando («hay unidades rodando ahora mismo en el mapa», sin una palabra
    // de más); sin ellos queda quieto y sin ticker.
    final busIcon = Icon(
      Icons.directions_bus_rounded,
      size: 24,
      color: colors.onPrimary,
    );
    final subtitle = alive
        ? '$activeCount recorridos en el mapa'
        : '${_micros.length} líneas · elige ida o vuelta';

    return _rise(
      _aHeader,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Halo que respira bajo la insignia: SOLO con recorridos en
                  // el mapa (así el panel entero se ve «encendido»).
                  if (alive)
                    Positioned.fill(
                      child: Ambient(
                        period: const Duration(milliseconds: 1900),
                        builder: (_, _, phase, _) => Transform.scale(
                          scale: 1 + 0.3 * phase,
                          child: Opacity(
                            opacity: 0.45 * (1 - phase),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: Motion.morph,
                    curve: Curves.easeOutCubic,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      // Degradado de marca: la insignia deja de ser un cuadro
                      // gris y pasa a ser el punto de color del encabezado.
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primary,
                          Color.lerp(colors.primary, colors.secondary, 0.8)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                        alive ? AppRadius.md : AppRadius.input,
                      ),
                      border: Border.all(
                        color: colors.onPrimary.withValues(alpha: 0.24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(
                            alpha: alive ? 0.45 : 0.22,
                          ),
                          blurRadius: alive ? 16 : 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedScale(
                        duration: Motion.transition,
                        curve: Curves.easeOutBack,
                        scale: alive ? 1.08 : 1,
                        // Con recorridos dibujados el bus flota dentro de su
                        // insignia.
                        child: alive
                            ? Bob(
                                amplitude: 2.5,
                                period: const Duration(milliseconds: 1500),
                                child: busIcon,
                              )
                            : busIcon,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Micros',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: Motion.morph,
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.45),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: alive
                        // Con recorridos en el mapa el conteo se vuelve una
                        // píldora de color con su punto vivo al lado.
                        ? Container(
                            key: ValueKey(subtitle),
                            padding: const EdgeInsets.fromLTRB(6, 2, 9, 2),
                            decoration: BoxDecoration(
                              color: tintWash,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.32),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LiveDot(color: liveInk, size: 6),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(
                                      color: liveInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            subtitle,
                            key: ValueKey(subtitle),
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Interruptor de modo del panel: LÍNEAS (catálogo con ida/vuelta) o
  /// LUGARES («¿qué línea pasa por este lugar?»). Pista hundida y una pastilla
  /// de color que se DESLIZA al cambiar de modo; más vida que el segmentado
  /// gris del material sin romper sus toques (cada rótulo sigue siendo su
  /// propio `Text`).
  Widget _modeToggle(ColorScheme colors, TextTheme text) {
    return _rise(
      _aHeader,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: _ModeSwitch(
          places: _placesMode,
          colors: colors,
          text: text,
          onChanged: _switchMode,
        ),
      ),
    );
  }

  /// Buscador con halo de foco animado (el theme ya pinta el borde primario;
  /// aquí se añade el resplandor y el tinte del prefijo).
  Widget _searchField(ColorScheme colors) {
    final focused = _searchFocus.hasFocus;
    return _rise(
      _aSearch,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: AnimatedContainer(
          duration: Motion.fade,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.input),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: focused ? 0.18 : 0),
                blurRadius: focused ? 16 : 0,
                spreadRadius: focused ? 0.5 : 0,
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            // En lugares el ENTER confirma la búsqueda (no por letra); en
            // líneas filtra en vivo (local, gratis).
            onSubmitted: _placesMode ? (_) => _commitPlacesSearch() : null,
            decoration: InputDecoration(
              isDense: true,
              // Relleno teñido (marca al 5%, al 10% con el foco): el campo
              // deja de ser un gris plano y se lee parte del panel.
              filled: true,
              fillColor: Color.lerp(
                colors.surface,
                colors.primary,
                focused ? 0.1 : 0.05,
              ),
              // Modo lugares: el foco invita a preguntar «¿qué línea pasa
              // por X?» sin que el usuario conozca numerales.
              hintText: _placesMode
                  ? '¿Qué línea pasa por aquí? (calle, lugar…)'
                  : 'Buscar línea…',
              prefixIcon: TweenAnimationBuilder<Color?>(
                duration: Motion.fade,
                curve: Curves.easeOut,
                tween: ColorTween(
                  end: focused ? colors.primary : colors.onSurfaceVariant,
                ),
                builder: (_, color, _) => Icon(
                  _placesMode ? Icons.place_rounded : Icons.search_rounded,
                  size: 20,
                  color: color,
                ),
              ),
              suffixIcon: _suffix(colors),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input),
                borderSide: BorderSide(color: colors.primary, width: 1.6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sufijo del buscador según modo: en LÍNEAS la «x» limpia el filtro; en
  /// LUGARES es el botón que confirma (el borrador cumplió ≥ 3 letras) más
  /// la «x» que borra TODO (borrador + confirmada).
  Widget? _suffix(ColorScheme colors) {
    if (!_placesMode) {
      if (_query.isEmpty) return null;
      return IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: _clearQuery,
        icon: const Icon(Icons.close_rounded, size: 18),
      );
    }
    final draft = _placesDraft.trim();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Marcar el lugar directamente en el mapa (además de escribirlo o
        // usar «cerca de mí»): siempre disponible en modo lugares.
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Marcar en el mapa',
          onPressed: _locked ? null : _pickPlaceOnMap,
          icon: const Icon(Icons.add_location_alt_rounded, size: 18),
        ),
        if (draft.isNotEmpty)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Buscar',
            onPressed: _commitPlacesSearch,
            icon: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: colors.primary,
            ),
          ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _clearPlacesSearch,
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ],
    );
  }

  /// Acciones rápidas: "Activar todas" (con el tinte de marca: es la acción
  /// buena) y "Limpiar" (esta última solo cobra sentido —y color de daño—
  /// cuando hay algo que limpiar).
  Widget _actions(int activeCount) {
    final colors = context.colors;
    // Relleno de "Activar todas": el acento al 12% con su tinta legible
    // encima (medida contra la mezcla, no contra la superficie).
    final addFill = Color.lerp(colors.surface, colors.primary, 0.12)!;
    return _rise(
      _aActions,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locked ? null : _activateAll,
                style: OutlinedButton.styleFrom(
                  backgroundColor: addFill,
                  foregroundColor: AppColors.legible(colors.primary, addFill),
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.35),
                  ),
                ),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Activar todas'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locked || activeCount == 0 ? null : _clearAll,
                style: OutlinedButton.styleFrom(
                  // `colors.error` (no `Colors.red.shade700`): en el tema
                  // oscuro el token es un rojo luminoso; un rojo oscuro sobre
                  // la superficie oscura sería letra oscura sobre fondo oscuro.
                  foregroundColor: activeCount == 0 ? null : colors.error,
                ),
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: const Text('Limpiar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Listado: relleno/estado vacío con animación propia y "jalar para
  /// actualizar" (el catálogo ya está cacheado, así que no hay red al abrir).
  Widget _list(ColorScheme colors) {
    if (_micros.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: EmptyState(
          icon: Icons.directions_bus_rounded,
          title: 'No hay micros registrados todavía.',
          compact: true,
        ),
      );
    }

    final filtered = _filteredMicros;
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Sin resultados para "$_query".',
          message: 'Prueba con otro numeral o nombre de línea.',
          actionLabel: 'Ver todas',
          onAction: _clearQuery,
          compact: true,
        ),
      );
    }

    return RefreshIndicator(
      color: colors.primary,
      backgroundColor: colors.surface,
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final micro = filtered[index];
          final tile = JourneyMicroTile(
            key: ValueKey('micro-tile-${micro.id}'),
            micro: micro,
            directions: _directionsOf(micro),
            activeDirectionKeys: _activeKeys,
            busyKey: _pendingKey,
            locked: _locked,
            onToggle: (directionId) => _toggle(micro, directionId),
          );
          // El escalonado de entrada solo vale para la primera hornada: una
          // vez terminado [_entrance], las tarjetas que entran al hacer scroll
          // se muestran ya en su sitio (nada de re-animar en cada frame).
          return _stagger(_entrance, index, tile);
        },
      ),
    );
  }
}

/// Interruptor LÍNEAS ⇄ LUGARES: una pista hundida con una pastilla de marca
/// que se desliza al cambiar de modo. La tinta de los rótulos se interpola, así
/// que el texto no salta de color a mitad del recorrido; los toques siguen
/// siendo uno por rótulo (el `Text` vive dentro de su `InkWell`).
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.places,
    required this.colors,
    required this.text,
    required this.onChanged,
  });

  /// `true` = modo LUGARES (la pastilla se va a la derecha).
  final bool places;
  final ColorScheme colors;
  final TextTheme text;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    // Pista: el gris de los contenedores con un soplo del primario.
    final track = Color.lerp(
      colors.surfaceContainerHighest,
      colors.primary,
      colors.brightness == Brightness.dark ? 0.06 : 0.04,
    )!;
    return Container(
      height: 42,
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: track,
        borderRadius: radius,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: places ? Alignment.centerRight : Alignment.centerLeft,
            duration: Motion.morph,
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      Color.lerp(colors.primary, colors.secondary, 0.8)!,
                    ],
                  ),
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            // Stretch: cada rótulo ocupa todo el alto de la pista (zona
            // táctil cómoda, no solo el renglón del texto).
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _segment(
                selected: !places,
                label: 'Líneas',
                icon: Icons.format_list_numbered_rounded,
                onTap: () => onChanged(false),
                radius: radius,
              ),
              _segment(
                selected: places,
                label: 'Lugares',
                icon: Icons.place_rounded,
                onTap: () => onChanged(true),
                radius: radius,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required BorderRadius radius,
  }) {
    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: TweenAnimationBuilder<Color?>(
            duration: Motion.morph,
            curve: Curves.easeOut,
            tween: ColorTween(
              end: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
            builder: (_, color, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
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
