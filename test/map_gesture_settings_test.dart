import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:urbano/src/core/map/map_scene.dart';

void main() {
  test('la escena interactiva permite girar el mapa', () {
    const scene = MapScene(center: LatLng(-17.78, -63.18), zoom: 13);

    expect(scene.rotateGesturesEnabled, isTrue);
  });

  test('una escena no interactiva mantiene bloqueados todos los gestos', () {
    const scene = MapScene(
      center: LatLng(-17.78, -63.18),
      zoom: 13,
      interactive: false,
    );

    expect(scene.rotateGesturesEnabled, isFalse);
  });
}
