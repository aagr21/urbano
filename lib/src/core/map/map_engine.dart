import 'package:flutter/widgets.dart';

import 'map_controller.dart';
import 'map_scene.dart';

/// Motor de mapa intercambiable.
///
/// Contrato que cumplen [MapLibreEngine] (motor nativo MapLibre) y
/// [FakeMapEngine] (superficie simulada para tests/offline): reciben un
/// [MapScene] y lo renderizan, enlazándose con el [UrbanoMapController] de la
/// fachada mediante [MapEngineHost].
abstract class MapEngine extends StatefulWidget {
  const MapEngine({super.key, required this.scene, this.controller});

  /// Qué dibujar y qué eventos reenviar.
  final MapScene scene;

  /// Controlador opcional de la fachada (para cámara y drags).
  final UrbanoMapController? controller;

  @override
  State<MapEngine> createState();
}
