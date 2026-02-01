import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../services/attachment_storage_service.dart';
import 'app_settings_controller.dart';

final attachmentStorageServiceProvider =
    Provider<AttachmentStorageService>((ref) {
  return const AttachmentStorageService();
});

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  final isar = ref.watch(isarProvider);
  final uuid = ref.watch(uuidProvider);
  final storage = ref.watch(attachmentStorageServiceProvider);
  return AttachmentRepository(isar: isar, uuid: uuid, storage: storage);
});
