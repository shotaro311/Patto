import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/sync_service.dart';
import 'app_settings_controller.dart';
import 'note_repository_provider.dart';
import 'supabase_providers.dart';

final syncServiceProvider = Provider<SyncService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(supabaseUserIdProvider);
  if (client == null || userId == null) return null;

  final repo = ref.watch(noteRepositoryProvider);
  final clientId = ref.watch(appSettingsProvider.select((s) => s.clientId));

  return SyncService(
    client: client,
    noteRepository: repo,
    userId: userId,
    clientId: clientId,
  );
});
