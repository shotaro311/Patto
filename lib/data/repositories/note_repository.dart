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

  Stream<List<Note>> watchNotes({required String query}) {
    final q = query.trim();
    if (q.isEmpty) {
      return _isar.notes
          .filter()
          .isDeletedEqualTo(false)
          .sortByLocalUpdatedAtDesc()
          .watch(fireImmediately: true);
    }

    return _isar.notes
        .filter()
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

  Future<void> updateContent(String id, String content) async {
    await _isar.writeTxn(() async {
      final note = await _isar.notes.where().uuidEqualTo(id).findFirst();
      if (note == null) return;
      final previousTitle = note.title;
      final previousDerived = deriveTitleFromContent(note.content);
      note
        ..content = content
        ..localUpdatedAt = DateTime.now()
        ..syncVersion = note.syncVersion + 1
        ..isDirty = true;
      if (previousTitle.trim().isEmpty || previousTitle == previousDerived) {
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
        ..isDirty = true;
      await _isar.notes.put(note);
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
    return _isar.notes.filter().isDirtyEqualTo(true).findAll();
  }

  Future<void> markAllDirty() async {
    final all = await _isar.notes.where().findAll();
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

  Future<void> upsertFromRemote(List<Note> remoteNotes) async {
    if (remoteNotes.isEmpty) return;
    await _isar.writeTxn(() async {
      await _isar.notes.putAll(remoteNotes);
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
