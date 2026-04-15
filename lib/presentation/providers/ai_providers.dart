import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/config/env.dart';
import '../../domain/app_settings.dart';
import '../../services/ai_key_repository.dart';
import '../../services/ai_service.dart';
import '../../services/apple_intelligence_client.dart';
import 'app_settings_controller.dart';

final aiKeyRepositoryProvider = Provider<AiKeyRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return AiKeyRepository(storage);
});

final appleIntelligenceClientProvider = Provider<AppleIntelligenceClient>((
  ref,
) {
  return const AppleIntelligenceClient();
});

final aiServiceProvider = Provider<AiService>((ref) {
  final repo = ref.watch(aiKeyRepositoryProvider);
  final apple = ref.watch(appleIntelligenceClientProvider);
  final settings = ref.watch(appSettingsProvider);
  return AiService(repo, apple, settings);
});

final aiSelectableModelsProvider = FutureProvider<List<String>>((ref) async {
  final settings = ref.watch(appSettingsProvider);
  if (!settings.aiExternalApiEnabled) return const [];

  switch (settings.aiExternalProvider) {
    case AiExternalProvider.openAiCompatible:
      final models = await ref.read(aiServiceProvider).fetchLocalModels();
      return <String>{
        if (settings.aiExternalModel.trim().isNotEmpty)
          settings.aiExternalModel.trim(),
        ...models,
      }.toList(growable: false);
    case AiExternalProvider.gemini:
      final configured = settings.aiExternalModel.trim();
      if (configured.isNotEmpty) {
        return [configured];
      }
      final fallback = Env.aiModelName.trim();
      return fallback.isEmpty ? const [] : [fallback];
  }
});
