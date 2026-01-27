import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sync_service.dart';
import 'app_settings_controller.dart';
import 'auth_providers.dart';
import 'note_repository_provider.dart';
import 'supabase_providers.dart';
import 'tag_dictionary_repository_provider.dart';

final syncServiceProvider = Provider<SyncService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userIdAsync = ref.watch(authUserIdStreamProvider);
  final userId = userIdAsync.valueOrNull;
  if (client == null || userId == null) return null;

  final repo = ref.watch(noteRepositoryProvider);
  final tagRepo = ref.watch(tagDictionaryRepositoryProvider);
  final clientId = ref.watch(appSettingsProvider.select((s) => s.clientId));

  return SyncService(
    client: client,
    noteRepository: repo,
    tagDictionaryRepository: tagRepo,
    userId: userId,
    clientId: clientId,
  );
});

final syncConflictsProvider = StateProvider<List<SyncConflict>>((ref) => []);

final syncInProgressProvider = StateProvider<bool>((ref) => false);
