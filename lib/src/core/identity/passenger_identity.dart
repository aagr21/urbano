import 'dart:math';

import 'package:flutter/foundation.dart';

/// Identidad «social» del dispositivo para el feed de quejas: una clave única
/// (para el dedup de likes en el backend) y un apodo + color de avatar.
///
/// El apodo por defecto es determinista a partir de la clave (mismo algoritmo
/// y paleta que `backend/.../passenger-identity.ts`), así el nombre que ve el
/// usuario es exactamente el que el servidor pintaría si llegara a generar uno
/// él mismo. El usuario puede editarlo; la edición se guarda localmente.
@immutable
class PassengerIdentity {
  const PassengerIdentity({
    required this.deviceKey,
    required this.nickname,
    required this.avatarColorHex,
  });

  final String deviceKey;
  final String nickname;

  /// Hex sin `#` (p. ej. `E74C3C`), listo para [AppColors.fromHex].
  final String avatarColorHex;

  /// Iniciales para el avatar (una o dos letras).
  String get initials {
    final words = nickname
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  PassengerIdentity copyWith({String? nickname}) => PassengerIdentity(
    deviceKey: deviceKey,
    nickname: nickname ?? this.nickname,
    avatarColorHex: avatarColorHex,
  );
}

/// Generadores deterministas compartidos con el backend. Si tocás las listas,
/// tocá también `passenger-identity.ts` para que ambos lados coincidan.
abstract final class PassengerNames {
  static const List<String> adjectives = [
    'Rápido',
    'Tranquilo',
    'Amable',
    'Piloto',
    'Atento',
    'Genuino',
    'Leal',
    'Serio',
    'Listo',
    'Fiel',
    'Vivo',
    'Claro',
  ];

  static const List<String> nouns = [
    'Micro',
    'Minibús',
    'Paradero',
    'Asiento',
    'Pasajero',
    'Chofer',
    'Recorrido',
    'Tramo',
    'Ave',
    'Tucán',
    'Ñandú',
    'Gato',
  ];

  /// Paleta de avatar (hex sin `#`), mismo orden que el backend.
  static const List<String> avatarPalette = [
    'E74C3C',
    '8E44AD',
    '3498DB',
    '16A085',
    'F39C12',
    'D35400',
    '2C3E50',
    '27AE60',
  ];

  static String nicknameFor(String deviceKey) {
    final seed = _hash(deviceKey.isEmpty ? 'anonimo' : deviceKey);
    final adjective = adjectives[seed % adjectives.length];
    final noun = nouns[(seed >> 5) % nouns.length];
    final number = 10 + ((seed >> 10) % 90);
    return '$adjective $noun $number';
  }

  static String avatarColorFor(String deviceKey) {
    final seed = _hash('$deviceKey:color');
    return avatarPalette[seed % avatarPalette.length];
  }

  /// FNV-1a de 32 bits sobre unidades de código UTF-16 (idéntico a JS).
  static int _hash(String value) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < value.length; i++) {
      hash ^= value.codeUnitAt(i);
      // Multiplicación de 32 bits con desborde, igual que `Math.imul` en JS.
      hash = _imul(hash, 0x01000193);
    }
    return hash.toUnsigned(32);
  }

  static int _imul(int a, int b) {
    // Producto parcial por mitades para no desbordar los 53 bits seguros del
    // doble de JavaScript al compilar a web; en la VM el `& 0xFFFFFFFF` basta.
    final aLow = a & 0xFFFF;
    final aHigh = (a >> 16) & 0xFFFF;
    final result = (aLow * b + (((aHigh * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
    return result.toSigned(32);
  }
}

/// Clave aleatoria por instalación (no es un UUID canónico: sólo se usa como
/// identificador opaco de dispositivo para el dedup de likes).
String generateDeviceKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
