part of 'journey_micros_sheet.dart';

/// Secciones visuales del panel (encabezado, interruptor de modo, buscador,
/// acciones y listados de líneas) como extension del [_MicrosPanelState]:
/// métodos puros de pintura sobre el mismo estado — el archivo se lee de
/// arriba hacia abajo: primero la conducta (State), después el aspecto.
extension _MicrosPanelSections on _MicrosPanelState {
  /// Encabezado: insignia de bus (que se enciende cuando hay recorridos
  /// dibujados) + título + subtítulo animado con el conteo.
  Widget _header(ColorScheme colors, TextTheme text, int activeCount) {
    final alive = activeCount > 0;
    // El ícono del bus se arma una sola vez: con recorridos activos entra
    // flotando («hay unidades rodando ahora mismo en el mapa», sin una palabra
    // de más); sin ellos queda quieto y sin ticker.
    final busIcon = Icon(
      Icons.directions_bus_rounded,
      size: 24,
      color: colors.primary,
    );
    final subtitle = alive
        ? '$activeCount recorridos en el mapa'
        : '${_micros.length} líneas · elige ida o vuelta';

    return _rise(
      _aHeader,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Motion.morph,
              curve: Curves.easeOutCubic,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: alive ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(
                  alive ? AppRadius.md : AppRadius.input,
                ),
                border: Border.all(
                  color: colors.primary.withValues(alpha: alive ? 0.4 : 0),
                  width: 1.2,
                ),
              ),
              child: AnimatedScale(
                duration: Motion.transition,
                curve: Curves.easeOutBack,
                scale: alive ? 1.06 : 1,
                // Con recorridos dibujados el bus flota dentro de su insignia.
                child: alive
                    ? Bob(
                        amplitude: 2.5,
                        period: const Duration(milliseconds: 1500),
                        child: busIcon,
                      )
                    : busIcon,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Micros', style: text.titleMedium),
                  const SizedBox(height: 2),
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
                    child: Text(
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
  /// LUGARES («¿qué línea pasa por este lugar?»). SegmentedButton del
  /// material — ya viene con los tokens del theme del app.
  Widget _modeToggle(ColorScheme colors, TextTheme text) {
    return _rise(
      _aHeader,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: SizedBox(
          height: 38,
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(
                  'Líneas',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.format_list_numbered_rounded, size: 16),
              ),
              ButtonSegment(
                value: true,
                label: Text(
                  'Lugares',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.place_rounded, size: 16),
              ),
            ],
            selected: {_placesMode},
            onSelectionChanged: (selection) => _switchMode(selection.first),
            style: ButtonStyle(
              side: WidgetStatePropertyAll<BorderSide>(
                BorderSide(color: colors.outlineVariant),
              ),
              shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              iconSize: const WidgetStatePropertyAll<double>(16),
              visualDensity: VisualDensity.compact,
            ),
          ),
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

  /// Acciones rápidas: "Activar todas" y "Limpiar" (esta última solo cobra
  /// sentido —y color de daño— cuando hay algo que limpiar).
  Widget _actions(int activeCount) {
    final colors = context.colors;
    return _rise(
      _aActions,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locked ? null : _activateAll,
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
