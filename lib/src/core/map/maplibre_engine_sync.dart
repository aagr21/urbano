part of 'maplibre_engine.dart';

/// Latido con el que se reescribe el radio de las ondas nativas.
const Duration _pulseTick = Duration(milliseconds: 60);

/// Ondas simultáneas por pulso, desfasadas un tercio de vuelta entre sí:
/// con el halo difuso del retroceso del aura, tres crestas seguidas (cada
/// `Motion.ambient / 3` ≈ 800 ms) hacen que la onda nunca se apague.
const int _pulseWaves = 3;

/// Opacidad con la que nace cada onda. El halo de Google Maps nace con
/// ~0.4 casi sustancial cerca del punto; 0.26 se perdía sobre tiles.
const double _pulsePeakOpacity = 0.38;

/// Sincronización escena → anotaciones nativas (métodos privados del
/// [MapLibreEngineState], separados aquí porque son el bloque más denso
/// del motor: agendado asíncrono, líneas y marcadores).

extension _EngineSync on MapLibreEngineState {
  // ------------------------------------------------------------------
  // Sincronización escena → anotaciones nativas
  // ------------------------------------------------------------------

  void _scheduleSync() {
    if (_syncScheduled || !mounted) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      unawaited(_syncAll());
    });
  }

  Future<void> _syncAll() async {
    if (_syncing) {
      _syncQueued = true;
      return;
    }
    _syncing = true;
    try {
      while (true) {
        _syncQueued = false;
        final generation = _styleGeneration;
        if (_styleLoaded && _map != null) {
          await _syncLines(generation);
          await _syncMarkers(generation);
          await _syncPulses(generation);
        }
        if (!_syncQueued || !mounted) break;
      }
    } on PlatformException catch (e) {
      // Defensa en profundidad contra la ventana de recarga de estilo: si un
      // `symbol#add`/`style#addImage`/`line#add` llega justo cuando el plugin
      // está swapping el estilo (p. ej. al aplicar el tema guardado tras el
      // primer frame), el nativo responde `STYLE_NOT_READY`. En vez de dejar
      // el error sin capturar (ruido en consola y dibujo perdido), marcamos
      // el estilo como no-cargado y dejamos que el próximo `onStyleLoaded`
      // re-sincronice todo. Cualquier otra `PlatformException` se propaga.
      if (e.code != 'STYLE_NOT_READY') rethrow;
      _styleLoaded = false;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncLines(int generation) async {
    final map = _map;
    final manager = map?.lineManager;
    if (manager == null) return;
    final signature = _linesSignature(widget.scene.polylines);
    if (signature == _lineSignature) return;

    await manager.clear();
    if (!mounted || generation != _styleGeneration) return;

    final lines = <ml.Line>[];
    var index = 0;
    ml.Line makeLine(
      List<LatLng> points,
      Color color,
      double width,
      double opacity,
    ) {
      final id = 'urbano-line-${index++}';
      return ml.Line(
        id,
        ml.LineOptions(
          geometry: [
            _toMl(points.first),
            for (final p in points.skip(1)) _toMl(p),
          ],
          lineColor: _hex(color),
          lineWidth: width,
          lineOpacity: opacity,
          lineJoin: 'round',
        ),
      );
    }

    for (final polyline in widget.scene.polylines) {
      if (polyline.points.length < 2) continue;
      if (polyline.dashed) {
        final segments = _dashSegments(polyline.points);
        if (polyline.outline) {
          for (final segment in segments) {
            lines.add(
              makeLine(
                segment,
                polyline.outlineColor,
                polyline.width + 4,
                polyline.opacity,
              ),
            );
          }
        }
        for (final segment in segments) {
          lines.add(
            makeLine(segment, polyline.color, polyline.width, polyline.opacity),
          );
        }
      } else {
        if (polyline.outline) {
          lines.add(
            makeLine(
              polyline.points,
              polyline.outlineColor,
              polyline.width + 4,
              polyline.opacity,
            ),
          );
        }
        lines.add(
          makeLine(
            polyline.points,
            polyline.color,
            polyline.width,
            polyline.opacity,
          ),
        );
      }
    }

    await manager.addAll(lines);
    if (!mounted || generation != _styleGeneration) return;
    _lineSignature = signature;
  }

  Future<void> _syncMarkers(int generation) async {
    final map = _map;
    final manager = map?.symbolManager;
    if (manager == null) return;
    final scene = widget.scene;

    // Los overrides locales solo valen mientras la pantalla no cambie el
    // `point` del marcador: si lo cambia, el punto de escena manda.
    for (final marker in scene.markers) {
      final seen = _sceneMarkerPoints[marker.id];
      if (seen == null || seen != marker.point) {
        _markerOverrides.remove(marker.id);
      }
      _sceneMarkerPoints[marker.id] = marker.point;
    }

    // Quita los símbolos de marcadores que ya no están en la escena.
    final liveIds = scene.markers.map((m) => m.id).toSet();
    final staleIds = _symbols.keys
        .where((id) => !liveIds.contains(id))
        .toList();
    for (final id in staleIds) {
      final symbol = _symbols.remove(id);
      _symbolImageKeys.remove(id);
      _sceneMarkerPoints.remove(id);
      _markerOverrides.remove(id);
      if (symbol != null) {
        await manager.remove(symbol);
        if (!mounted || generation != _styleGeneration) return;
      }
    }

    for (final marker in scene.markers) {
      final point = _markerOverrides[marker.id] ?? marker.point;
      final imageName = await _ensureImage(marker, generation);
      if (!mounted || generation != _styleGeneration) return;
      if (imageName == null) continue;

      final existing = _symbols[marker.id];
      final anchor = _anchorOf(marker);
      final needsRebuild =
          existing == null ||
          _symbolImageKeys[marker.id] != marker.imageCacheKey ||
          existing.options.iconAnchor != anchor ||
          existing.options.draggable != marker.draggable;

      if (needsRebuild) {
        if (existing != null) {
          await manager.remove(existing);
          if (!mounted || generation != _styleGeneration) return;
        }
        final symbol = ml.Symbol(
          marker.id,
          ml.SymbolOptions(
            geometry: _toMl(point),
            iconImage: imageName,
            iconAnchor: anchor,
            draggable: marker.draggable,
          ),
        );
        await manager.add(symbol);
        if (!mounted || generation != _styleGeneration) return;
        _symbols[marker.id] = symbol;
        _symbolImageKeys[marker.id] = marker.imageCacheKey;
        if (kDebugMode && marker.draggable) {
          debugPrint('[drag] símbolo arrastrable creado: ${marker.id}');
        }
      } else if (existing.options.geometry?.toLatLong() != point) {
        final updated = ml.Symbol(
          existing.id,
          existing.options.copyWith(ml.SymbolOptions(geometry: _toMl(point))),
        );
        await manager.set(updated);
        if (!mounted || generation != _styleGeneration) return;
        _symbols[marker.id] = updated;
      }
    }
  }

  // ------------------------------------------------------------------
  // Auras de «mi ubicación» (MapPulse)
  // ------------------------------------------------------------------

  /// Da de alta/baja los círculos del aura y gobierna su reloj.
  ///
  /// El tick NO vive aquí: [_tickPulses] reescribe radio, opacidad y geometría
  /// de cada círculo leyendo la escena, así que este método solo se ocupa de
  /// altas y bajas. Con «reducir animaciones» ([Motion.reduced]) se pinta un
  /// halo quieto y el reloj no arranca.
  Future<void> _syncPulses(int generation) async {
    final manager = _map?.circleManager;
    if (manager == null) return;
    final pulses = widget.scene.pulses;

    // El reloj avanza de forma continua: la fase sobrevive a altas/bajas.
    if (pulses.isEmpty) {
      await _clearPulses(manager);
      return;
    }

    final reduced = Motion.reduced(context);
    // Con «reducir animaciones» no se arranca el reloj: el halo queda quieto.
    final phase = reduced ? 0.0 : _pulsePhase();
    for (var i = 0; i < pulses.length; i++) {
      for (var wave = 0; wave < _pulseWaves; wave++) {
        final id = _pulseCircleId(i, wave);
        final options = _pulseOptions(pulses[i], wave, phase, reduced: reduced);
        final existing = _pulseCircles[id];
        if (existing == null) {
          final circle = ml.Circle(id, options);
          await manager.add(circle);
          if (!mounted || generation != _styleGeneration) return;
          _pulseCircles[id] = circle;
        } else {
          // Reinicia radio/geometría (p. ej. tras un cambio de capa del mapa)
          // sin recrear el círculo.
          final updated = ml.Circle(id, options);
          await manager.set(updated);
          if (!mounted || generation != _styleGeneration) return;
          _pulseCircles[id] = updated;
        }
      }
    }

    // Retira auras de pulsos que salieron de la escena (p. ej. al desactivar
    // el seguimiento GPS).
    final liveIds = <String>{
      for (var i = 0; i < pulses.length; i++)
        for (var wave = 0; wave < _pulseWaves; wave++) _pulseCircleId(i, wave),
    };
    final staleIds = _pulseCircles.keys
        .where((id) => !liveIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      final circle = _pulseCircles.remove(id);
      if (circle == null) continue;
      await manager.remove(circle);
      if (!mounted || generation != _styleGeneration) return;
    }

    if (reduced) {
      _stopPulseClock();
    } else {
      _startPulseClock();
    }
  }

  /// Un paso del aura: reescribe radio/opacidad de cada onda según la fase.
  Future<void> _tickPulses() async {
    if (!mounted || !_styleLoaded) return;
    final manager = _map?.circleManager;
    if (manager == null || _pulseCircles.isEmpty) return;

    final pulses = widget.scene.pulses;
    final phase = _pulsePhase();
    try {
      for (var i = 0; i < pulses.length; i++) {
        for (var wave = 0; wave < _pulseWaves; wave++) {
          final id = _pulseCircleId(i, wave);
          if (!_pulseCircles.containsKey(id)) continue;
          final circle = ml.Circle(
            id,
            _pulseOptions(pulses[i], wave, phase, reduced: false),
          );
          _pulseCircles[id] = circle;
          await manager.set(circle);
          if (!mounted) return;
        }
      }
    } on PlatformException catch (e) {
      // Misma ventana de recarga de estilo que `_syncAll`: `_onStyleLoaded`
      // vacía `_pulseCircles` y el próximo `_scheduleSync` los recrea.
      if (e.code != 'STYLE_NOT_READY') {
        if (kDebugMode) debugPrint('[pulse] tick descartado: ${e.code}');
        _stopPulseClock();
      }
    }
  }

  /// Opciones de una onda. `t` = avance dentro de su vuelta: 0 nace (radio
  /// mínimo, opacidad máxima) y 1 muere (radio máximo, opacidad 0).
  ///
  /// Con [reduced] se fija un halo quieto: la primera onda a mitad de camino y
  /// la segunda invisible (mismo aspecto que el estado de reposo del simulado).
  ml.CircleOptions _pulseOptions(
    MapPulse pulse,
    int wave,
    double phase, {
    required bool reduced,
  }) {
    final t = reduced
        ? (wave == 0 ? 0.35 : 1.0)
        : (phase + wave / _pulseWaves) % 1.0;
    final radius = pulse.baseRadius + (pulse.maxRadius - pulse.baseRadius) * t;
    final opacity = (_pulsePeakOpacity * (1 - t)).clamp(0.0, 1.0);
    return ml.CircleOptions(
      geometry: _toMl(pulse.point),
      circleRadius: radius,
      circleColor: _hex(pulse.color),
      circleOpacity: opacity,
      // Sin aro: el aura de Google Maps es un disco difuso. `circleBlur`
      // reparte la opacidad hacia el borde y hace el degradado que en el motor
      // simulado pinta `_PulsePainter` con un `RadialGradient`.
      circleBlur: 0.65,
    );
  }

  /// Fase actual (0..1) dentro de una vuelta del aura.
  double _pulsePhase() {
    if (!_pulseClock.isRunning) _pulseClock.start();
    final period = Motion.ambient.inMilliseconds;
    return (_pulseClock.elapsedMilliseconds % period) / period;
  }

  void _startPulseClock() {
    _pulseClock.start();
    _pulseTimer ??= Timer.periodic(_pulseTick, (_) => unawaited(_tickPulses()));
  }

  void _stopPulseClock() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
    _pulseClock
      ..stop()
      ..reset();
  }

  /// Vacía el manager y apaga el reloj (escena sin auras).
  Future<void> _clearPulses(ml.CircleManager manager) async {
    _stopPulseClock();
    if (_pulseCircles.isEmpty) return;
    final circles = _pulseCircles.values.toList(growable: false);
    _pulseCircles.clear();
    await manager.removeAll(circles);
  }

  String _pulseCircleId(int index, int wave) => 'urbano-pulse-$index-$wave';

  /// Asegura que el icono PNG del marcador exista en el estilo actual.
  Future<String?> _ensureImage(MapMarker marker, int generation) async {
    final key = marker.imageCacheKey;
    final name = _imageNames[key] ??= 'urbano-marker-${_imageNames.length}';
    if (_imagesLoaded.contains(name)) return name;

    var bytes = await MarkerRasterizer.rasterize(
      context,
      marker,
      pixelRatio: _markerPixelRatio(),
    );
    bytes ??= await MarkerRasterizer.fallbackMarker(
      width: marker.width,
      height: marker.height,
    );
    if (!mounted || generation != _styleGeneration) return null;
    final map = _map;
    if (map == null) return null;
    await map.addImage(name, bytes);
    if (!mounted || generation != _styleGeneration) return null;
    _imagesLoaded.add(name);
    return name;
  }

  /// Densidad con la que rasterizar los iconos.
  ///
  /// - **Web**: el plugin registra las imágenes con `pixelRatio: 1`, así que
  ///   el PNG debe medir exactamente el tamaño lógico del marcador.
  /// - **iOS/Android**: el PNG se sube como píxeles crudos y MapLibre los
  ///   dibuja a tamaño de pantalla, así que hay que rasterizar a la densidad
  ///   del dispositivo.
  double _markerPixelRatio() {
    if (kIsWeb) return 1;
    final ratio = MediaQuery.maybeOf(context)?.devicePixelRatio;
    if (ratio == null || !ratio.isFinite || ratio <= 0) return 3;
    return ratio.clamp(1.0, 4.0).toDouble();
  }
}
