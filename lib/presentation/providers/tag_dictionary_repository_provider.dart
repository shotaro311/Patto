import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/repositories/tag_dictionary_repository.dart';
import 'app_settings_controller.dart';

final tagDictionaryRepositoryProvider = Provider<TagDictionaryRepository>((
  ref,
) {
  final isar = ref.watch(isarProvider);
  final uuid = ref.watch(uuidProvider);
  final clientId = ref.watch(appSettingsProvider.select((s) => s.clientId));
  return TagDictionaryRepository(isar: isar, uuid: uuid, clientId: clientId);
});
