import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` mientras la app está **en primer plano** (el usuario puede verla).
///
/// Es el interruptor de ciclo de vida del GPS: en segundo plano no hay nadie
/// mirando el mapa, así que no hay nada que escuchar. Se expone como provider
/// para que la política de ubicación (`locationDemandProvider`) lo lea y no para
/// que cada widget se ponga a observar `WidgetsBindingObserver` por su cuenta.
class AppForeground extends Notifier<bool> {
  @override
  bool build() {
    // El listener vive con el provider: `dispose()` quita el observador del
    // binding (de lo contrario quedaría colgado de WidgetsBinding para siempre).
    final listener = AppLifecycleListener(onStateChange: _onStateChange);
    ref.onDispose(listener.dispose);
    // Arranque normal: `resumed`. `null` (plataformas sin estado aún, y el
    // binding de `flutter test`) se trata como activo: si no, el seguimiento
    // nacería apagado y el mapa no centraría nunca sobre el usuario.
    return isForeground(WidgetsBinding.instance.lifecycleState);
  }

  void _onStateChange(AppLifecycleState lifecycle) {
    final foreground = isForeground(lifecycle);
    if (state == foreground) return;
    state = foreground;
  }

  /// Regla del ciclo de vida: [paused], [hidden] y [detached] son "no mirar".
  ///
  /// [AppLifecycleState.inactive] cuenta como primer plano a propósito: es
  /// transitorio (bajar la sombra de notificaciones, el diálogo de permiso,
  /// cambiar de app sin salir). Apagar el sensor ahí cerraría y abriría el stream
  /// en plena petición de permiso, y cada reapertura cuesta un fix nuevo.
  @visibleForTesting
  static bool isForeground(AppLifecycleState? state) => switch (state) {
    AppLifecycleState.paused ||
    AppLifecycleState.hidden ||
    AppLifecycleState.detached => false,
    _ => true,
  };
}

final appForegroundProvider = NotifierProvider<AppForeground, bool>(
  AppForeground.new,
);
