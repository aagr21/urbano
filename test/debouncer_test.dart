import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:urbano/src/core/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('ejecuta la acción después del delay', () async {
      var called = false;
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      debouncer.run(() => called = true);

      expect(called, isFalse);
      await Future.delayed(const Duration(milliseconds: 150));
      expect(called, isTrue);
    });

    test('cancel evita la ejecución', () async {
      var called = false;
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      debouncer.run(() => called = true);
      debouncer.cancel();

      await Future.delayed(const Duration(milliseconds: 150));
      expect(called, isFalse);
    });

    test('nueva llamada reinicia el timer', () async {
      var callCount = 0;
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      debouncer.run(() => callCount++);
      await Future.delayed(const Duration(milliseconds: 50));
      debouncer.run(() => callCount++);
      await Future.delayed(const Duration(milliseconds: 150));

      expect(callCount, 1);
    });

    test('dispose limpia el timer', () async {
      var called = false;
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      debouncer.run(() => called = true);
      debouncer.dispose();

      await Future.delayed(const Duration(milliseconds: 150));
      expect(called, isFalse);
    });

    test('con timerFactory falso permite control total en tests', () {
      void Function()? capturedCallback;

      Timer fakeTimerFactory(Duration duration, void Function() callback) {
        capturedCallback = callback;
        return Timer(duration, callback);
      }

      final debouncer = Debouncer(
        delay: const Duration(milliseconds: 100),
        timerFactory: fakeTimerFactory,
      );

      var called = false;
      debouncer.run(() => called = true);

      expect(capturedCallback, isNotNull);
      expect(called, isFalse);

      // Ejecuta el callback manualmente
      capturedCallback!();
      expect(called, isTrue);
    });
  });
}
