import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';

class SyncService {
  SyncService({
    required SupabaseClient client,
    required NoteRepository noteRepository,
    required String userId,
    required String clientId,
  })  : _client = client,
        _noteRepository = noteRepository,
        _userId = userId,
        _clientId = clientId;

  final SupabaseClient _client;
  final NoteRepository _noteRepository;
  final String _userId;
  final String _clientId;

  Future<SyncResult> syncNow({required DateTime? lastSyncAt}) async {
    final syncedAt = DateTime.now().toUtc();

    final dirty = await _noteRepository.listDirtyNotes();
    if (dirty.isNotEmpty) {
      final payload = dirty
          .map(
            (n) => {
              'id': n.uuid,
              'user_id': _userId,
              'title': n.title,
              'content': n.content,
              'is_deleted': n.isDeleted,
              'local_updated_at': n.localUpdatedAt.toUtc().toIso8601String(),
              'sync_version': n.syncVersion,
              'client_id': n.clientId ?? _clientId,
            },
          )
          .toList(growable: false);

      await _client.from('notes').upsert(payload, onConflict: 'id');
      await _noteRepository.markClean(
        noteIds: dirty.map((e) => e.uuid),
        syncedAt: syncedAt,
      );
    }

    final since = lastSyncAt?.toUtc().toIso8601String();
    final baseQuery = _client.from('notes').select();
    final rows = await (since == null
            ? baseQuery
            : baseQuery.gt('server_updated_at', since))
        .order('server_updated_at', ascending: true);

    var maxServerUpdatedAt = lastSyncAt?.toUtc();
    var conflicts = 0;

    for (final row in rows) {
      final remote = _fromRemoteRow(row);
      maxServerUpdatedAt = _max(maxServerUpdatedAt, remote.serverUpdatedAt);

      final local = await _noteRepository.getNote(remote.uuid);
      if (local != null && local.isDirty) {
        conflicts += 1;
        await _noteRepository.createNote(initialContent: remote.content);
        continue;
      }

      await _noteRepository.upsertFromRemote([remote]);
    }

    return SyncResult(
      syncedAt: syncedAt,
      lastSyncAt: maxServerUpdatedAt ?? syncedAt,
      conflicts: conflicts,
    );
  }

  Note _fromRemoteRow(Map<String, dynamic> row) {
    final note = Note()
      ..uuid = row['id'] as String
      ..title = (row['title'] as String?) ?? ''
      ..content = (row['content'] as String?) ?? ''
      ..isDeleted = (row['is_deleted'] as bool?) ?? false
      ..createdAt = DateTime.parse(row['created_at'] as String).toUtc()
      ..localUpdatedAt = DateTime.parse(row['local_updated_at'] as String).toUtc()
      ..serverUpdatedAt = DateTime.parse(row['server_updated_at'] as String).toUtc()
      ..syncVersion = (row['sync_version'] as int?) ?? 1
      ..clientId = row['client_id'] as String?
      ..isDirty = false;

    return note;
  }

  DateTime? _max(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }
}

class SyncResult {
  const SyncResult({
    required this.syncedAt,
    required this.lastSyncAt,
    required this.conflicts,
  });

  final DateTime syncedAt;
  final DateTime lastSyncAt;
  final int conflicts;
}
