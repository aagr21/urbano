import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import 'api_client.dart';

/// Cliente HTTP único de la app (base URL por `--dart-define=API_BASE_URL`).
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: Env.apiBaseUrl);
  ref.onDispose(client.close);
  return client;
});
