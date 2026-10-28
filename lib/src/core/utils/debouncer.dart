import 'dart:async';

/// Debounce simple para búsquedas en vivo.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 350)});

  final Duration delay;
  Timer? _timer;

  /// Reinicia el temporizador y ejecuta [action] cuando [delay] pase sin
  /// nuevas llamadas.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
