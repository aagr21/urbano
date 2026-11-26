import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/features/journey/application/trip_history_controller.dart';
import 'package:urbano/src/features/journey/data/trip_history.dart';
import 'package:urbano/src/features/journey/domain/journey_place.dart';

import 'helpers/memory_trip_history_store.dart';

/// Contenedor con el historial apoyado en el store en memoria (sin plugins).
Future<ProviderContainer> _container(MemoryTripHistoryStore store) async {
  final container = ProviderContainer(
    overrides: [
      tripHistoryControllerProvider.overrideWith(
        () => TripHistoryController(store),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(tripHistoryControllerProvider.future);
  return container;
}

JourneyPlacePoi _poi(String name, {double lat = -17.7833}) => JourneyPlacePoi(
  name: name,
  lat: lat,
  lon: -63.1821,
  subtitle: 'Centro histórico',
);

TripHistoryEntry _entry(String label, DateTime at, {int? minutes}) =>
    TripHistoryEntry(
      label: label,
      lat: -17.78,
      lon: -63.18,
      lastUsed: at,
      durationMinutes: minutes,
    );

void main() {
  group('TripHistoryEntry', () {
    test('sobrevive al JSON de ida y vuelta', () {
      final entry = _entry(
        'Plaza 24 de Septiembre',
        DateTime(2026, 11, 5, 13, 30),
        minutes: 8,
      );
      final restored = TripHistoryEntry.fromJson(entry.toJson());

      expect(restored, isNotNull);
      expect(restored!.label, entry.label);
      expect(restored.lat, entry.lat);
      expect(restored.lon, entry.lon);
      expect(restored.lastUsed, entry.lastUsed);
      expect(restored.durationMinutes, 8);
      expect(restored.subtitle, isNull);
    });

    test('descarta filas corruptas sin lanzar', () {
      expect(TripHistoryEntry.fromJson(null), isNull);
      expect(TripHistoryEntry.fromJson('no soy un mapa'), isNull);
      expect(TripHistoryEntry.fromJson({'label': ''}), isNull);
      expect(
        TripHistoryEntry.fromJson({
          'label': 'Sin coordenadas',
          'lastUsed': DateTime(2026).toIso8601String(),
        }),
        isNull,
      );
      expect(
        TripHistoryEntry.fromJson({
          'label': 'Sin fecha',
          'lat': -17.78,
          'lon': -63.18,
        }),
        isNull,
      );
    });

    test('la clave ignora el nombre en mayúsculas y los decimales de más', () {
      final a = TripHistoryEntry(
        label: 'Plaza',
        lat: -17.78331,
        lon: -63.18214,
        lastUsed: DateTime(2026),
      );
      final b = TripHistoryEntry(
        label: 'plaza',
        lat: -17.78334,
        lon: -63.18211,
        lastUsed: DateTime(2026),
      );
      expect(a.key, b.key);
    });
  });

  group('TripHistoryController', () {
    test('carga lo persistido al arrancar', () async {
      final store = MemoryTripHistoryStore([
        _entry('Mercado', DateTime(2026, 11, 4)),
      ]);
      final container = await _container(store);

      final saved = container.read(tripHistoryControllerProvider).valueOrNull;
      expect(saved, hasLength(1));
      expect(saved!.single.label, 'Mercado');
    });

    test('anota el destino y deja el más reciente arriba', () async {
      final store = MemoryTripHistoryStore();
      final container = await _container(store);
      final controller = container.read(tripHistoryControllerProvider.notifier);

      await controller.record(
        destination: _poi('Mercado'),
        at: DateTime(2026, 11),
      );
      await controller.record(
        destination: _poi('Plaza'),
        at: DateTime(2026, 11, 3),
      );

      final saved = container.read(tripHistoryControllerProvider).valueOrNull;
      expect(saved!.map((e) => e.label), ['Plaza', 'Mercado']);
      // Lo mismo que leería la próxima sesión.
      expect(store.saved.map((e) => e.label), ['Plaza', 'Mercado']);
    });

    test('deduplica por destino en vez de repetir la fila', () async {
      final store = MemoryTripHistoryStore();
      final container = await _container(store);
      final controller = container.read(tripHistoryControllerProvider.notifier);

      await controller.record(
        destination: _poi('Mercado'),
        at: DateTime(2026, 11),
      );
      await controller.record(
        destination: _poi('Plaza'),
        at: DateTime(2026, 11, 2),
      );
      await controller.record(
        destination: _poi('Mercado'),
        at: DateTime(2026, 11, 5),
        durationMinutes: 8,
      );

      final saved = container.read(tripHistoryControllerProvider).valueOrNull;
      expect(saved, hasLength(2));
      expect(saved!.first.label, 'Mercado');
      expect(saved.first.durationMinutes, 8, reason: 'gana la última visita');
      expect(saved.last.label, 'Plaza');
    });

    test('acota la lista a maxEntries', () async {
      final store = MemoryTripHistoryStore();
      final container = await _container(store);
      final controller = container.read(tripHistoryControllerProvider.notifier);

      const recorded = TripHistoryController.maxEntries + 3;
      for (var i = 0; i < recorded; i++) {
        await controller.record(
          destination: _poi('Lugar $i'),
          at: DateTime(2026, 11).add(Duration(minutes: i)),
        );
      }

      final saved = container.read(tripHistoryControllerProvider).valueOrNull;
      expect(saved, hasLength(TripHistoryController.maxEntries));
      expect(
        saved!.first.label,
        'Lugar ${recorded - 1}',
        reason: 'el último gana',
      );
      expect(
        saved.any((e) => e.label == 'Lugar 0'),
        isFalse,
        reason: 'los más viejos salen por la cola',
      );
    });

    test('clear vacía memoria y persistencia', () async {
      final store = MemoryTripHistoryStore([
        _entry('Mercado', DateTime(2026, 11, 4)),
      ]);
      final container = await _container(store);

      await container.read(tripHistoryControllerProvider.notifier).clear();

      expect(
        container.read(tripHistoryControllerProvider).valueOrNull,
        isEmpty,
      );
      expect(store.saved, isEmpty);
    });
  });

  group('filterTripHistory', () {
    final entries = [
      TripHistoryEntry(
        label: 'Ventura Mall',
        subtitle: '4to Anillo',
        lat: 1,
        lon: 1,
        lastUsed: DateTime(2026),
      ),
      TripHistoryEntry(
        label: 'Plaza',
        lat: 2,
        lon: 2,
        lastUsed: DateTime(2026),
      ),
    ];

    test('sin texto devuelve todo', () {
      expect(filterTripHistory(entries, '  '), same(entries));
    });

    test('busca en nombre y contexto sin distinguir mayúsculas', () {
      expect(filterTripHistory(entries, 'PLAZA').single.label, 'Plaza');
      expect(filterTripHistory(entries, 'anillo').single.label, 'Ventura Mall');
      expect(filterTripHistory(entries, 'xyz'), isEmpty);
    });
  });
}
