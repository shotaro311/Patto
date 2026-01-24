import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../services/ai_key_repository.dart';
import '../../services/ai_service.dart';
import '../../services/apple_intelligence_client.dart';

final aiKeyRepositoryProvider = Provider<AiKeyRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return AiKeyRepository(storage);
});

final appleIntelligenceClientProvider =
    Provider<AppleIntelligenceClient>((ref) {
  return const AppleIntelligenceClient();
});

final aiServiceProvider = Provider<AiService>((ref) {
  final repo = ref.watch(aiKeyRepositoryProvider);
  final apple = ref.watch(appleIntelligenceClientProvider);
  return AiService(repo, apple);
});
