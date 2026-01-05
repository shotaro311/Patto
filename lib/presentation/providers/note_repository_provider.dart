import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/repositories/note_repository.dart';
import 'app_settings_controller.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final isar = ref.watch(isarProvider);
  final uuid = ref.watch(uuidProvider);
  final clientId = ref.watch(appSettingsProvider.select((s) => s.clientId));
  return NoteRepository(isar: isar, uuid: uuid, clientId: clientId);
});

