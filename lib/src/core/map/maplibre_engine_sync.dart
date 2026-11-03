part of 'maplibre_engine.dart';

/// Latido con el que se reescribe el radio de las ondas nativas.
///
/// 90 ms (~11 fps) en vez de 60: el aura es un brillo que se mueve lento sobre
/// [MapPulse.period] (2,8 s), así que 90 ms siguen siendo ~31 pasos por vuelta y
/// el ojo no nota la diferencia — mientras cada paso son unas pocas llamadas
/// por canal al mapa nativo. Es el reloj que más despierta al teléfono cuando
/// el mapa está montado, y el planeador lo está SIEMPRE.
const Duration _pulseTick = Duration(milliseconds: 90);

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
  /// Por pulso se crean [MapPulse.waves] ondas + 1 halo difuso. El tick NO vive
  /// aquí: [_tickPulses] reescribe radio, opacidad y geometría de cada círculo
  /// leyendo la escena, así que este método solo se ocupa de altas y bajas. Con
  /// «reducir animaciones» ([Motion.reduced]) se pinta un halo quieto y el reloj
  /// no arranca.
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
      // El halo difuso va PRIMERO: los círculos nativos se pintan en orden de
      // alta, así que las ondas quedan encima de él.
      final glowOk = await _upsertPulseCircle(
        manager,
        _pulseGlowId(i),
        _pulseGlowOptions(pulses[i], phase),
        generation,
      );
      if (!glowOk) return;
      for (var wave = 0; wave < MapPulse.waves; wave++) {
        final ok = await _upsertPulseCircle(
          manager,
          _pulseCircleId(i, wave),
          _pulseOptions(pulses[i], wave, phase),
          generation,
        );
        if (!ok) return;
      }
    }

    // Retira auras de pulsos que salieron de la escena (p. ej. al desactivar
    // el seguimiento GPS).
    final liveIds = <String>{
      for (var i = 0; i < pulses.length; i++) ...[
        _pulseGlowId(i),
        for (var wave = 0; wave < MapPulse.waves; wave++)
          _pulseCircleId(i, wave),
      ],
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

  /// Alta o refresco de un círculo del aura.
  ///
  /// Devuelve `false` si el estilo cambió mientras se esperaba al canal: la
  /// sincronía en curso ya no sirve y hay que abandonarla.
  Future<bool> _upsertPulseCircle(
    ml.CircleManager manager,
    String id,
    ml.CircleOptions options,
    int generation,
  ) async {
    final circle = ml.Circle(id, options);
    if (_pulseCircles.containsKey(id)) {
      await manager.set(circle);
    } else {
      await manager.add(circle);
    }
    if (!mounted || generation != _styleGeneration) return false;
    _pulseCircles[id] = circle;
    return true;
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
        final glowId = _pulseGlowId(i);
        if (_pulseCircles.containsKey(glowId)) {
          final glow = ml.Circle(glowId, _pulseGlowOptions(pulses[i], phase));
          _pulseCircles[glowId] = glow;
          await manager.set(glow);
          if (!mounted) return;
        }
        for (var wave = 0; wave < MapPulse.waves; wave++) {
          final id = _pulseCircleId(i, wave);
          if (!_pulseCircles.containsKey(id)) continue;
          final circle = ml.Circle(id, _pulseOptions(pulses[i], wave, phase));
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

  /// Opciones de una onda. `t` = avance de su vuelta (0 recién encendida, 1
  /// apagada): el brillo sale de [pulseWaveGlow], el desplazamiento hacia fuera
  /// de [pulseWaveGrowth] y el aro se afina mientras se aleja. Las MISMAS
  /// curvas usa el motor simulado, así que el latido es idéntico en ambos.
  ml.CircleOptions _pulseOptions(MapPulse pulse, int wave, double phase) {
    // El estilo se pinta en px FÍSICOS: radios y aros viajan en px lógicos
    // ([MapPulse]) y aquí se convierten con la densidad del dispositivo (en
    // web la densidad ya es 1). Sin esto los anillos quedaban por dentro del
    // punto en móviles.
    final density = _nativeDensity();
    // Al alejar el mapa el mismo anillo se veía gigante sobre la ciudad: se
    // achica y se apaga con el zoom, hasta quedar casi imperceptible.
    final zoom = _camera.zoom;
    final span = (wave / (MapPulse.waves - 1)).clamp(0.0, 1.0);
    final t = (phase + wave / MapPulse.waves) % 1.0;
    final glow = pulseWaveGlow(t) * pulsePresence(zoom);
    final radius =
        (pulse.baseRadius +
            (pulse.maxRadius - pulse.baseRadius) * span +
            pulseWaveGrowth(t)) *
        pulseRadiusScale(zoom) *
        density;
    final stroke =
        MapPulse.strokeWidth +
        (MapPulse.minStrokeWidth - MapPulse.strokeWidth) * t;
    return ml.CircleOptions(
      geometry: _toMl(pulse.point),
      circleRadius: radius,
      circleColor: _hex(pulse.color),
      // El relleno se apaga con la onda: solo da cuerpo al nacer, no deja un
      // disco relleno y plano sobre el mapa.
      circleOpacity: MapPulse.peakFillOpacity * glow * (1 - t),
      // Casi sin blur: el latido se lee por el ARO nítido, no por un disco
      // difuso (con `circleBlur` alto el borde se comía el anillo).
      circleBlur: 0.06,
      circleStrokeColor: _hex(pulse.color),
      circleStrokeOpacity: (MapPulse.peakStrokeOpacity * glow).clamp(0.0, 1.0),
      circleStrokeWidth: stroke * density,
    );
  }

  /// Halo difuso bajo las ondas: respira ([pulseBreath]) y es lo que hace que
  /// el punto se sienta «encendido» entre onda y onda.
  ///
  /// `circleBlur: 1` es el máximo del estilo y aquí SÍ conviene: no hay aro
  /// que proteger, todo el círculo es un degradado suave.
  ml.CircleOptions _pulseGlowOptions(MapPulse pulse, double phase) {
    final density = _nativeDensity();
    final zoom = _camera.zoom;
    final breath = 0.6 + 0.4 * pulseBreath(phase);
    return ml.CircleOptions(
      geometry: _toMl(pulse.point),
      circleRadius:
          pulse.baseRadius *
          MapPulse.glowRadiusScale *
          pulseRadiusScale(zoom) *
          density,
      circleColor: _hex(pulse.color),
      circleOpacity: (MapPulse.glowOpacity * pulsePresence(zoom) * breath)
          .clamp(0.0, 1.0),
      circleBlur: 1.0,
    );
  }

  /// Fase actual (0..1) dentro de una vuelta del aura.
  double _pulsePhase() {
    if (!_pulseClock.isRunning) _pulseClock.start();
    final period = MapPulse.period.inMilliseconds;
    return (_pulseClock.elapsedMilliseconds % period) / period;
  }

  void _startPulseClock() {
    _pulseClock.start();
    _pulseTimer ??= Timer.periodic(_pulseTick, (_) => unawaited(_tickPulses()));
  }

  /// Congela/descongela el aura según el ciclo de vida de la app.
  ///
  /// Un `Timer.periodic` en segundo plano sigue disparando `manager.set()` por
  /// canal y pidiendo redraws de un mapa que nadie mira: CPU, batería y calor
  /// tirados.
  void _onAppLifecycleState(AppLifecycleState state) {
    final invisible = switch (state) {
      AppLifecycleState.paused ||
      AppLifecycleState.hidden ||
      AppLifecycleState.detached => true,
      // `inactive` (sombra de notificaciones, diálogo de permiso) sigue animando:
      // la app se ve, cortar aquí dejaría el halo congelado a la vista.
      _ => false,
    };
    if (invisible) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
      // `stop()` SIN `reset()`: [_stopPulseClock] borra la fase y el aura
      // rearrancaría desde cero. Así el latido continúa donde lo dejó.
      _pulseClock.stop();
      return;
    }
    // De vuelta: solo si hay círculos que mover y el estilo está listo (si no,
    // `_syncPulses` se ocupa cuando llegue la próxima sincronía).
    if (_styleLoaded && _pulseCircles.isNotEmpty && !Motion.reduced(context)) {
      _startPulseClock();
    }
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

  /// Id del halo difuso de un pulso (el círculo que va DEBAJO de las ondas).
  String _pulseGlowId(int index) => 'urbano-pulse-$index-glow';

  /// Asegura que el icono PNG del marcador exista en el estilo actual.
  Future<String?> _ensureImage(MapMarker marker, int generation) async {
    final key = marker.imageCacheKey;
    final name = _imageNames[key] ??= 'urbano-marker-${_imageNames.length}';
    if (_imagesLoaded.contains(name)) return name;

    var bytes = await MarkerRasterizer.rasterize(
      context,
      marker,
      pixelRatio: _nativeDensity(),
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

  /// Densidad nativa (píxeles físicos por px lógico) con la que MapLibre mide
  /// todo lo que no es un widget de Flutter.
  ///
  /// Importa para DOS cosas: rasterizar los iconos de los marcadores y
  /// escalar los círculos del aura ([MapPulse]). El estilo se pinta en píxeles
  /// del lienzo nativo, así que un radio "de 54" son 54 px FÍSICOS: en un
  /// móvil de densidad 3 eso son 18 px lógicos y el anillo quedaba escondido
  /// detrás del punto (22 px) — se veía en el motor simulado (1x) y no en el
  /// teléfono.
  ///
  /// - **Web**: el plugin registra las imágenes con `pixelRatio: 1` y el
  ///   lienzo ya trabaja en px lógicos, así que el PNG debe medir exactamente
  ///   el tamaño lógico del marcador.
  /// - **iOS/Android**: el PNG se sube como píxeles crudos y MapLibre los
  ///   dibuja a tamaño de pantalla, así que hay que rasterizar a la densidad
  ///   del dispositivo.
  double _nativeDensity() {
    if (kIsWeb) return 1;
    final ratio = MediaQuery.maybeOf(context)?.devicePixelRatio;
    if (ratio == null || !ratio.isFinite || ratio <= 0) return 3;
    return ratio.clamp(1.0, 4.0).toDouble();
  }
}
