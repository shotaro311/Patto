import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AttachmentStorageService {
  const AttachmentStorageService();

  Future<File> saveWebpImage({
    required String noteUuid,
    required String attachmentId,
    required List<int> bytes,
  }) async {
    final dir = await _ensureAttachmentDir(noteUuid);
    final file = File('${dir.path}/$attachmentId.webp');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<Directory> _ensureAttachmentDir(String noteUuid) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/attachments/$noteUuid');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
