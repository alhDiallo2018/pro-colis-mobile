import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/ai_api.dart';
import '../services/api/client.dart';

final aiAssistantConfiguredProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final link = ref.keepAlive();
  ref.onDispose(link.close);
  final api = AiAssistantApi(ApiClient());
  return api.isConfigured();
});
