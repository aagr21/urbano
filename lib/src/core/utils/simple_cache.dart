/// Caché en memoria simple con TTL para listas (repositorios remotos).
class SimpleCache {
  SimpleCache({this.ttl = const Duration(minutes: 5)});

  final Duration ttl;
  final Map<String, _Entry> _entries = {};

  T? read<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return entry.value is T ? entry.value as T : null;
  }

  void write(String key, Object? value) {
    if (value == null) return;
    _entries[key] = _Entry(value, DateTime.now().add(ttl));
  }

  void clear() => _entries.clear();
}

class _Entry {
  _Entry(this.value, this.expiresAt);

  final Object value;
  final DateTime expiresAt;
}
