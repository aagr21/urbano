import 'dart:async';

/// Fábrica de timers para [Debouncer]. En producción usa [Timer.new];
/// en tests se puede inyectar un reloj falso (p. ej. `FakeAsync`).
typedef TimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Debounce simple para búsquedas en vivo.
class Debouncer {
  Debouncer({
    this.delay = const Duration(milliseconds: 350),
    TimerFactory? timerFactory,
  }) : _timerFactory = timerFactory ?? _defaultTimerFactory;

  static Timer _defaultTimerFactory(
    Duration duration,
    void Function() callback,
  ) => Timer(duration, callback);

  final Duration delay;
  final TimerFactory _timerFactory;
  Timer? _timer;

  /// Reinicia el temporizador y ejecuta [action] cuando [delay] pase sin
  /// nuevas llamadas.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = _timerFactory(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
