import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/runtime_flags.dart';

/// De dónde llegan los enlaces que otras apps le pasan a Urbano.
///
/// En Android lo llena `IncomingLinkActivity` (un intent `geo:` al tocar una
/// ubicación en WhatsApp, un `urbano://…` o un texto compartido) y Dart lo
/// retira de a uno: [takePending] devuelve el enlace y lo borra, así que el
/// mismo mensaje nunca abre la hoja dos veces.
abstract interface class IncomingLinkSource {
  /// El enlace pendiente (y lo consume), o `null` si no hay ninguno.
  Future<String?> takePending();
}

/// Canal nativo de Android (`MainActivity`/`SplashActivity` lo registran).
class MethodChannelIncomingLinkSource implements IncomingLinkSource {
  const MethodChannelIncomingLinkSource();

  static const _channel = MethodChannel('urbano/incoming_link');

  @override
  Future<String?> takePending() async {
    try {
      return await _channel.invokeMethod<String>('takePending');
    } on MissingPluginException {
      // iOS/web/escritorio no tienen el canal, y en Android el engine
      // pre-calentado puede preguntar antes de engancharse: se reintenta al
      // volver a primer plano.
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// Fuente vacía: la de `flutter test`, que no tiene plataforma.
class NoIncomingLinkSource implements IncomingLinkSource {
  const NoIncomingLinkSource();

  @override
  Future<String?> takePending() async => null;
}

final incomingLinkSourceProvider = Provider<IncomingLinkSource>(
  (_) => isRunningUnderTest
      ? const NoIncomingLinkSource()
      : const MethodChannelIncomingLinkSource(),
);
