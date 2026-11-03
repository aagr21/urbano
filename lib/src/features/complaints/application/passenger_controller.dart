import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/identity/passenger_identity.dart';

/// Puerto de persistencia de la identidad del pasajero. En la app real usa
/// `shared_preferences`; los tests inyectan un fake en memoria (regla del
/// repo: `flutter test` no toca plugins).
abstract interface class PassengerIdentityStore {
  Future<({String deviceKey, String nickname})?> load();
  Future<void> save({required String deviceKey, required String nickname});
}

class SharedPreferencesPassengerIdentityStore
    implements PassengerIdentityStore {
  static const _deviceKey = 'urbano.passenger.device_key';
  static const _nickname = 'urbano.passenger.nickname';

  @override
  Future<({String deviceKey, String nickname})?> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = preferences.getString(_deviceKey);
      if (key == null || key.isEmpty) return null;
      return (deviceKey: key, nickname: preferences.getString(_nickname) ?? '');
    } catch (_) {
      // Sin plugin (test) o store corrupto: el controller genera identidad en
      // memoria y la app sigue funcionando.
      return null;
    }
  }

  @override
  Future<void> save({
    required String deviceKey,
    required String nickname,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_deviceKey, deviceKey);
      await preferences.setString(_nickname, nickname);
    } catch (_) {
      // La persistencia es opcional; la identidad vive igual en memoria.
    }
  }
}

/// Dueño de la identidad social del dispositivo: la carga al arrancar (o la
/// crea con un apodo determinista) y permite editar el apodo.
class PassengerController extends AsyncNotifier<PassengerIdentity> {
  PassengerController([this._store]);

  final PassengerIdentityStore? _store;

  PassengerIdentityStore get _resolvedStore =>
      _store ?? SharedPreferencesPassengerIdentityStore();

  @override
  Future<PassengerIdentity> build() async {
    final saved = await _resolvedStore.load();
    final deviceKey = saved?.deviceKey.isNotEmpty ?? false
        ? saved!.deviceKey
        : generateDeviceKey();
    final nickname = (saved?.nickname ?? '').trim().isNotEmpty
        ? saved!.nickname.trim()
        : PassengerNames.nicknameFor(deviceKey);
    final identity = PassengerIdentity(
      deviceKey: deviceKey,
      nickname: nickname,
      avatarColorHex: PassengerNames.avatarColorFor(deviceKey),
    );
    // Persiste la clave recién generada para que el dedup de likes sea estable
    // entre sesiones.
    if (saved?.deviceKey != deviceKey) {
      await _resolvedStore.save(deviceKey: deviceKey, nickname: nickname);
    }
    return identity;
  }

  /// Cambia el apodo visible (máx. 40 caracteres). Lanza [ArgumentError] si
  /// queda vacío para que la UI lo invalide antes.
  Future<void> rename(String nickname) async {
    var clean = nickname.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length > 40) clean = clean.substring(0, 40);
    if (clean.isEmpty) {
      throw ArgumentError.value(
        nickname,
        'nickname',
        'El apodo no puede ser vacío',
      );
    }
    final current = await future;
    final updated = current.copyWith(nickname: clean);
    await _resolvedStore.save(deviceKey: updated.deviceKey, nickname: clean);
    state = AsyncData(updated);
  }
}

final passengerControllerProvider =
    AsyncNotifierProvider<PassengerController, PassengerIdentity>(
      PassengerController.new,
    );
