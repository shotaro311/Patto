import 'dart:async';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';

class NoteRepository {
  NoteRepository({
    required Isar isar,
    required Uuid uuid,
    required String clientId,
  })  : _isar = isar,
        _uuid = uuid,
        _clientId = clientId;

  final Isar _isar;
  final Uuid _uuid;
  final String _clientId;

  static const defaultMaxDrafts = 50;

  Stream<List<Note>> watchNotes({required String query}) {
    final q = query.trim();
    if (q.isEmpty) {
      return _isar.notes
          .filter()
          .isDraftEqualTo(false)
          .and()
          .isDeletedEqualTo(false)
          .sortByLocalUpdatedAtDesc()
          .watch(fireImmediately: true);
    }

    return _isar.notes
        .filter()
        .isDraftEqualTo(false)
        .and()
        .isDeletedEqualTo(false)
        .and()
        .group(
          (qb) => qb
              .titleContains(q, caseSensitive: false)
              .or()
              .contentContains(q, caseSensitive: false),
        )
        .sortByLocalUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  Stream<Note?> watchNote(String id) {
    return _isar.notes
        .where()
        .uuidEqualTo(id)
        .watch(fireImmediately: true)
        .map((items) => items.isEmpty ? null : items.first);
  }

  Stream<int> watchDirtyCount() {
    return _isar.notes
        .filter()
        .isDraftEqualTo(false)
        .and()
        .isDirtyEqualTo(true)
        .watch(fireImmediately: true)
        .map((items) => items.length);
  }

  Future<Note?> getNote(String id) async {
    return _isar.notes.where().uuidEqualTo(id).findFirst();
  }

  Future<Note> createNote({String? initialContent}) async {
    final now = DateTime.now();
    final note = Note()
      ..uuid = _uuid.v4()
      ..isDraft = false
      ..content = initialContent ?? ''
      ..title = deriveTitleFromContent(initialContent ?? '')
      ..createdAt = now
      ..localUpdatedAt = now
      ..clientId = _clientId
      ..isDirty = true;

    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });

    return note;
  }

  Future<Note> createDraft({required String initialContent}) async {
    final now = DateTime.now();
    final note = Note()
      ..uuid = _uuid.v4()
      ..isDraft = true
      ..content = initialContent
      ..title = deriveTitleFromContent(initialContent)
      ..createdAt = now
      ..localUpdatedAt = now
      ..clientId = _clientId
      ..isDirty = false;

    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });

    return note;
  }

  Stream<List<Note>> watchDrafts({int limit = defaultMaxDrafts}) {
    return _isar.notes
        .filter()
        .isDraftEqualTo(true)
        .and()
        .isDeletedEqualTo(false)
        .sortByLocalUpdatedAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  Future<void> updateContent(String id, String content) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.where().uuidEqualTo(id).findFirst();
      if (note == null) return;
      final previousTitle = note.title;
      note
        ..content = content
        ..localUpdatedAt = DateTime.now()
        ..syncVersion = note.syncVersion + 1
        ..isDirty = note.isDraft ? false : true;
      if (previousTitle.trim().isEmpty) {
        note.title = deriveTitleFromContent(content);
      }
      await _isar.notes.put(note);
    });
  }

  Future<void> updateTitle(String id, String title) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.where().uuidEqualTo(id).findFirst();
      if (note == null) return;
      note
        ..title = title
        ..localUpdatedAt = DateTime.now()
        ..syncVersion = note.syncVersion + 1
        ..isDirty = note.isDraft ? false : true;
      await _isar.notes.put(note);
    });
  }

  Future<void> setManualTags(String id, List<String> tags) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.where().uuidEqualTo(id).findFirst();
      if (note == null) return;
      note
        ..manualTags = List<String>.from(tags)
        ..localUpdatedAt = DateTime.now();
      await _isar.notes.put(note);
    });
  }

  Future<void> setAutoTags(String id, List<String> tags) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.where().uuidEqualTo(id).findFirst();
      if (note == null) return;
      note
        ..autoTags = List<String>.from(tags)
        ..localUpdatedAt = DateTime.now();
      await _isar.notes.put(note);
    });
  }

  Future<void> setLinksOut(String id, List<String> linksOut) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.where().uuidEqualTo(id).findFirst();
      if (note == null) return;
      note
        ..linksOut = List<String>.from(linksOut)
        ..localUpdatedAt = DateTime.now();
      await _isar.notes.put(note);
    });
  }

  Future<Note?> promoteDraftToNote(String id) async {
    Note? promoted;
    await _isar.writeTxn(() async {
      final note = await _isar.notes.where().uuidEqualTo(id).findFirst();
      if (note == null) return;
      if (!note.isDraft) {
        promoted = note;
        return;
      }

      note
        ..isDraft = false
        ..localUpdatedAt = DateTime.now()
        ..syncVersion = note.syncVersion + 1
        ..isDirty = true;

      if (note.title.trim().isEmpty) {
        note.title = deriveTitleFromContent(note.content);
      }

      await _isar.notes.put(note);
      promoted = note;
    });
    return promoted;
  }

  Future<void> autoArchiveDrafts({required int maxDrafts}) async {
    if (maxDrafts <= 0) return;
    final drafts = await _isar.notes
        .filter()
        .isDraftEqualTo(true)
        .and()
        .isDeletedEqualTo(false)
        .sortByLocalUpdatedAt()
        .findAll();

    if (drafts.length <= maxDrafts) return;

    final overflow = drafts.take(drafts.length - maxDrafts).toList();
    await _isar.writeTxn(() async {
      for (final note in overflow) {
        final isEmpty = note.title.trim().isEmpty && note.content.trim().isEmpty;
        if (isEmpty) {
          await _isar.notes.delete(note.id);
          continue;
        }
        note
          ..isDraft = false
          ..localUpdatedAt = DateTime.now()
          ..syncVersion = note.syncVersion + 1
          ..isDirty = true;
        if (note.title.trim().isEmpty) {
          note.title = deriveTitleFromContent(note.content);
        }
        await _isar.notes.put(note);
      }
    });
  }

  Future<bool> isTitleDuplicate({
    required String title,
    required String excludeId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return false;
    final matches = await _isar.notes
        .filter()
        .isDraftEqualTo(false)
        .and()
        .isDeletedEqualTo(false)
        .and()
        .titleEqualTo(trimmed, caseSensitive: false)
        .findAll();
    return matches.any((note) => note.uuid != excludeId);
  }

  Future<void> softDelete(String id) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.where().uuidEqualTo(id).findFirst();
      if (note == null) return;
      note
        ..isDeleted = true
        ..localUpdatedAt = DateTime.now()
        ..syncVersion = note.syncVersion + 1
        ..isDirty = true;
      await _isar.notes.put(note);
    });
  }

  Future<List<Note>> listDirtyNotes() async {
    return _isar.notes
        .filter()
        .isDraftEqualTo(false)
        .and()
        .isDirtyEqualTo(true)
        .findAll();
  }

  Future<void> markAllDirty() async {
    final all = await _isar.notes.filter().isDraftEqualTo(false).findAll();
    if (all.isEmpty) return;
    await _isar.writeTxn(() async {
      for (final note in all) {
        note.isDirty = true;
      }
      await _isar.notes.putAll(all);
    });
  }

  Future<void> markClean({
    required Map<String, DateTime> serverUpdatedAtById,
  }) async {
    if (serverUpdatedAtById.isEmpty) return;

    await _isar.writeTxn(() async {
      for (final entry in serverUpdatedAtById.entries) {
        final note = await _isar.notes.where().uuidEqualTo(entry.key).findFirst();
        if (note == null) continue;
        note
          ..isDirty = false
          ..serverUpdatedAt = entry.value;
        await _isar.notes.put(note);
      }
    });
  }

  Future<void> markCleanLocal({required List<String> ids}) async {
    if (ids.isEmpty) return;
    await _isar.writeTxn(() async {
      for (final id in ids) {
        final note = await _isar.notes.where().uuidEqualTo(id).findFirst();
        if (note == null) continue;
        note.isDirty = false;
        await _isar.notes.put(note);
      }
    });
  }

  Future<void> upsertFromRemote(List<Note> remoteNotes) async {
    if (remoteNotes.isEmpty) return;
    await _isar.writeTxn(() async {
      for (final remote in remoteNotes) {
        final local = await _isar.notes.where().uuidEqualTo(remote.uuid).findFirst();
        if (local != null) {
          remote
            ..manualTags = List<String>.from(local.manualTags)
            ..autoTags = List<String>.from(local.autoTags)
            ..linksOut = List<String>.from(local.linksOut);
        }
        await _isar.notes.put(remote);
      }
    });
  }

  Future<void> purgeDeletedBefore(DateTime cutoff) async {
    await _isar.writeTxn(() async {
      await _isar.notes
          .filter()
          .isDeletedEqualTo(true)
          .and()
          .isDirtyEqualTo(false)
          .and()
          .serverUpdatedAtLessThan(cutoff)
          .deleteAll();
    });
  }
}
