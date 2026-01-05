import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../services/ai_key_repository.dart';
import '../../services/ai_service.dart';

final aiKeyRepositoryProvider = Provider<AiKeyRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return AiKeyRepository(storage);
});

final aiServiceProvider = Provider<AiService>((ref) {
  final repo = ref.watch(aiKeyRepositoryProvider);
  return AiService(repo);
});

