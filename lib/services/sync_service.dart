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
  static const _purgeAfter = Duration(days: 14);

  Future<SyncResult> syncNow({required DateTime? lastSyncAt}) async {
    final syncedAt = DateTime.now().toUtc();
    final purgeCutoff = syncedAt.subtract(_purgeAfter);

    final dirty = await _noteRepository.listDirtyNotes();

    final since = lastSyncAt?.toUtc().toIso8601String();
    final baseQuery = _client.from('notes').select();
    final rows = await (since == null
            ? baseQuery
            : baseQuery.gt('server_updated_at', since))
        .order('server_updated_at', ascending: true);

    final remoteNotes = rows
        .whereType<Map<String, dynamic>>()
        .map(_fromRemoteRow)
        .toList(growable: false);
    final remoteById = {
      for (final remote in remoteNotes) remote.uuid: remote,
    };

    final conflictItems = <SyncConflict>[];
    final uploadNotes = <Note>[];
    for (final local in dirty) {
      final remote = remoteById[local.uuid];
      if (remote != null) {
        conflictItems.add(SyncConflict(local: local, remote: remote));
      } else {
        uploadNotes.add(local);
      }
    }

    final conflictIds = {
      for (final item in conflictItems) item.remote.uuid,
    };

    var maxServerUpdatedAt = lastSyncAt?.toUtc();

    if (remoteNotes.isNotEmpty) {
      for (final remote in remoteNotes) {
        maxServerUpdatedAt = _max(maxServerUpdatedAt, remote.serverUpdatedAt);
      }

      final applyTargets =
          remoteNotes.where((note) => !conflictIds.contains(note.uuid)).toList();
      await _noteRepository.upsertFromRemote(applyTargets);
    }

    if (uploadNotes.isNotEmpty) {
      final payload = uploadNotes
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

      final rows = await _client
          .from('notes')
          .upsert(payload, onConflict: 'id')
          .select('id, server_updated_at');

      final serverUpdatedAtById = _extractServerUpdatedAt(rows);
      await _noteRepository.markClean(serverUpdatedAtById: serverUpdatedAtById);

      for (final updatedAt in serverUpdatedAtById.values) {
        maxServerUpdatedAt = _max(maxServerUpdatedAt, updatedAt);
      }
    }

    final nextLastSyncAt = conflictItems.isEmpty
        ? maxServerUpdatedAt ?? lastSyncAt?.toUtc()
        : lastSyncAt?.toUtc();

    await _purgeDeletedBefore(purgeCutoff);

    return SyncResult(
      syncedAt: syncedAt,
      lastSyncAt: nextLastSyncAt,
      conflicts: conflictItems.length,
      conflictDetails: conflictItems,
    );
  }

  Note _fromRemoteRow(Map<String, dynamic> row) {
    final serverUpdatedAt = _parseDateTime(row['server_updated_at']);
    final note = Note()
      ..uuid = row['id'] as String
      ..title = (row['title'] as String?) ?? ''
      ..content = (row['content'] as String?) ?? ''
      ..isDeleted = (row['is_deleted'] as bool?) ?? false
      ..createdAt = DateTime.parse(row['created_at'] as String).toUtc()
      ..localUpdatedAt = DateTime.parse(row['local_updated_at'] as String).toUtc()
      ..serverUpdatedAt = serverUpdatedAt
      ..syncVersion = (row['sync_version'] as int?) ?? 1
      ..clientId = row['client_id'] as String?
      ..isDirty = false;

    return note;
  }

  Map<String, DateTime> _extractServerUpdatedAt(List<dynamic> rows) {
    final result = <String, DateTime>{};
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final id = row['id'];
      final serverUpdatedAt = _parseDateTime(row['server_updated_at']);
      if (id is String && serverUpdatedAt != null) {
        result[id] = serverUpdatedAt;
      }
    }
    return result;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      return DateTime.parse(value).toUtc();
    }
    return null;
  }

  DateTime? _max(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  Future<void> _purgeDeletedBefore(DateTime cutoff) async {
    await _client
        .from('notes')
        .delete()
        .eq('user_id', _userId)
        .eq('is_deleted', true)
        .lt('server_updated_at', cutoff.toIso8601String());

    await _noteRepository.purgeDeletedBefore(cutoff);
  }

  Future<void> resolveConflict(
    SyncConflict conflict,
    SyncConflictResolution resolution,
  ) async {
    switch (resolution) {
      case SyncConflictResolution.keepLocal:
        final payload = [
          {
            'id': conflict.local.uuid,
            'user_id': _userId,
            'title': conflict.local.title,
            'content': conflict.local.content,
            'is_deleted': conflict.local.isDeleted,
            'local_updated_at': conflict.local.localUpdatedAt.toUtc().toIso8601String(),
            'sync_version': conflict.local.syncVersion,
            'client_id': conflict.local.clientId ?? _clientId,
          }
        ];
        final rows = await _client
            .from('notes')
            .upsert(payload, onConflict: 'id')
            .select('id, server_updated_at');
        final serverUpdatedAtById = _extractServerUpdatedAt(rows);
        await _noteRepository.markClean(serverUpdatedAtById: serverUpdatedAtById);
        return;
      case SyncConflictResolution.keepRemote:
        await _noteRepository.upsertFromRemote([conflict.remote]);
        return;
    }
  }
}

class SyncResult {
  const SyncResult({
    required this.syncedAt,
    required this.lastSyncAt,
    required this.conflicts,
    required this.conflictDetails,
  });

  final DateTime syncedAt;
  final DateTime? lastSyncAt;
  final int conflicts;
  final List<SyncConflict> conflictDetails;
}

enum SyncConflictResolution {
  keepLocal,
  keepRemote,
}

class SyncConflict {
  const SyncConflict({
    required this.local,
    required this.remote,
  });

  final Note local;
  final Note remote;
}
