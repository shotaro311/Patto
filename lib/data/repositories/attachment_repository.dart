import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:isar/isar.dart';
import 'package:swipelab_webp/swipelab_webp.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import '../../services/attachment_storage_service.dart';

class AttachmentRepository {
  AttachmentRepository({
    required Isar isar,
    required Uuid uuid,
    required AttachmentStorageService storage,
  })  : _isar = isar,
        _uuid = uuid,
        _storage = storage;

  final Isar _isar;
  final Uuid _uuid;
  final AttachmentStorageService _storage;

  Future<NoteAttachment?> addImageAttachmentFromFile({
    required String noteId,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    return addImageAttachmentFromBytes(noteId: noteId, bytes: bytes);
  }

  Future<NoteAttachment?> addImageAttachmentFromBytes({
    required String noteId,
    required Uint8List bytes,
  }) async {
    final note = await _isar.notes.where().uuidEqualTo(noteId).findFirst();
    if (note == null) return null;

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final rgba = decoded.getBytes(order: img.ChannelOrder.rgba);
    final webpBytes = encodeWebP(
      WebPEncodeInput(
        rgba: rgba,
        width: decoded.width,
        height: decoded.height,
        quality: 80,
      ),
    );
    if (webpBytes == null) return null;
    final attachmentId = _uuid.v4();
    final file = await _storage.saveWebpImage(
      noteUuid: noteId,
      attachmentId: attachmentId,
      bytes: webpBytes,
    );

    final attachment = NoteAttachment()
      ..id = attachmentId
      ..type = 'image'
      ..mimeType = 'image/webp'
      ..localPath = file.path
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      final target = await _isar.notes.where().uuidEqualTo(noteId).findFirst();
      if (target == null) return;
      final next = List<NoteAttachment>.from(target.attachments)..add(attachment);
      target
        ..attachments = next
        ..localUpdatedAt = DateTime.now()
        ..syncVersion = target.syncVersion + 1
        ..isDirty = target.isDraft ? false : true;
      await _isar.notes.put(target);
    });

    return attachment;
  }
}
