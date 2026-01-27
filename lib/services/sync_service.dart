import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/note.dart';
import '../data/models/tag_dictionary_entry.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/tag_dictionary_repository.dart';

class SyncService {
  SyncService({
    required SupabaseClient client,
    required NoteRepository noteRepository,
    required TagDictionaryRepository tagDictionaryRepository,
    required String userId,
    required String clientId,
  }) : _client = client,
       _noteRepository = noteRepository,
       _tagDictionaryRepository = tagDictionaryRepository,
       _userId = userId,
       _clientId = clientId;

  final SupabaseClient _client;
  final NoteRepository _noteRepository;
  final TagDictionaryRepository _tagDictionaryRepository;
  final String _userId;
  final String _clientId;
  static const _purgeAfter = Duration(days: 14);
  static const _tagTable = 'tag_dictionary';

  Future<SyncResult> syncNow({required DateTime? lastSyncAt}) async {
    final syncedAt = DateTime.now().toUtc();
    final purgeCutoff = syncedAt.subtract(_purgeAfter);
    var maxServerUpdatedAt = lastSyncAt?.toUtc();

    final tagMaxServerUpdatedAt = await _syncTags(lastSyncAt: lastSyncAt);
    maxServerUpdatedAt = _max(maxServerUpdatedAt, tagMaxServerUpdatedAt);

    final dirty = await _noteRepository.listDirtyNotes();
    final emptyDirty = <Note>[];
    final effectiveDirty = <Note>[];
    for (final note in dirty) {
      if (!note.isDeleted && _isEmptyNote(note)) {
        emptyDirty.add(note);
      } else {
        effectiveDirty.add(note);
      }
    }

    final since = lastSyncAt?.toUtc().toIso8601String();
    final baseQuery = _client.from('notes').select();
    final rows =
        await (since == null
                ? baseQuery
                : baseQuery.gt('server_updated_at', since))
            .order('server_updated_at', ascending: true);

    final remoteNotes = rows
        .whereType<Map<String, dynamic>>()
        .map(_fromRemoteRow)
        .where((note) => note.isDeleted || !_isEmptyNote(note))
        .toList(growable: false);
    final remoteById = {for (final remote in remoteNotes) remote.uuid: remote};

    final conflictItems = <SyncConflict>[];
    final uploadNotes = <Note>[];
    for (final local in effectiveDirty) {
      final remote = remoteById[local.uuid];
      if (remote != null) {
        conflictItems.add(SyncConflict(local: local, remote: remote));
      } else {
        uploadNotes.add(local);
      }
    }

    final conflictIds = {for (final item in conflictItems) item.remote.uuid};

    try {
      await _deleteRemoteEmptyNotes();
    } catch (_) {
      // 空メモの削除に失敗しても同期自体は継続する
    }

    if (emptyDirty.isNotEmpty) {
      final missingRemote = <String>[];
      for (final note in emptyDirty) {
        if (!remoteById.containsKey(note.uuid)) {
          missingRemote.add(note.uuid);
        }
      }
      await _noteRepository.markCleanLocal(ids: missingRemote);
    }

    if (remoteNotes.isNotEmpty) {
      for (final remote in remoteNotes) {
        maxServerUpdatedAt = _max(maxServerUpdatedAt, remote.serverUpdatedAt);
      }

      final applyTargets = remoteNotes
          .where((note) => !conflictIds.contains(note.uuid))
          .toList();
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

  Future<DateTime?> _syncTags({required DateTime? lastSyncAt}) async {
    final dirtyEntries = await _tagDictionaryRepository.listDirtyEntries();
    final since = lastSyncAt?.toUtc().toIso8601String();
    try {
      final baseQuery = _client.from(_tagTable).select().eq('user_id', _userId);
      final rows =
          await (since == null
                  ? baseQuery
                  : baseQuery.gt('server_updated_at', since))
              .order('server_updated_at', ascending: true);

      final remoteEntries = rows
          .whereType<Map<String, dynamic>>()
          .map(_tagFromRemoteRow)
          .where(
            (entry) => entry.uuid.isNotEmpty && entry.canonicalTag.isNotEmpty,
          )
          .toList(growable: false);

      final remoteById = {
        for (final remote in remoteEntries) remote.uuid: remote,
      };
      final remoteByCanonical = {
        for (final remote in remoteEntries) remote.canonicalTag: remote,
      };

      final remoteNewerIds = <String>{};
      final remoteNewerCanonicals = <String>{};
      final uploadEntries = <TagDictionaryEntry>[];

      for (final local in dirtyEntries) {
        final canonical = TagDictionaryRepository.normalizeTag(
          local.canonicalTag,
        );
        final remote = remoteById[local.uuid] ?? remoteByCanonical[canonical];
        if (remote != null && _isRemoteTagNewer(remote, local)) {
          remoteNewerIds.add(remote.uuid);
          remoteNewerCanonicals.add(remote.canonicalTag);
        } else {
          uploadEntries.add(local);
        }
      }

      if (remoteEntries.isNotEmpty) {
        await _tagDictionaryRepository.upsertFromRemote(
          remoteEntries,
          overwriteDirtyIds: remoteNewerIds,
          overwriteDirtyCanonicals: remoteNewerCanonicals,
        );
      }

      var maxServerUpdatedAt = lastSyncAt?.toUtc();
      for (final remote in remoteEntries) {
        maxServerUpdatedAt = _max(maxServerUpdatedAt, remote.serverUpdatedAt);
      }

      if (uploadEntries.isNotEmpty) {
        final payload = uploadEntries
            .map(
              (entry) => {
                'id': entry.uuid,
                'user_id': _userId,
                'canonical_tag': entry.canonicalTag,
                'aliases': entry.aliases,
                'use_count': entry.useCount,
                'last_used_at': entry.lastUsedAt?.toUtc().toIso8601String(),
                'local_updated_at': entry.localUpdatedAt
                    .toUtc()
                    .toIso8601String(),
                'sync_version': entry.syncVersion,
                'client_id': entry.clientId ?? _clientId,
                'is_deleted': entry.isDeleted,
              },
            )
            .toList(growable: false);

        final rows = await _client
            .from(_tagTable)
            .upsert(payload, onConflict: 'user_id,canonical_tag')
            .select(
              'id, canonical_tag, aliases, use_count, last_used_at, created_at, '
              'local_updated_at, server_updated_at, sync_version, client_id, is_deleted',
            );

        final uploadedEntries = rows
            .whereType<Map<String, dynamic>>()
            .map(_tagFromRemoteRow)
            .where(
              (entry) => entry.uuid.isNotEmpty && entry.canonicalTag.isNotEmpty,
            )
            .toList(growable: false);

        if (uploadedEntries.isNotEmpty) {
          final uploadCanonicals = {
            for (final entry in uploadEntries)
              TagDictionaryRepository.normalizeTag(entry.canonicalTag),
          };
          await _tagDictionaryRepository.upsertFromRemote(
            uploadedEntries,
            overwriteDirtyCanonicals: uploadCanonicals,
          );
          for (final remote in uploadedEntries) {
            maxServerUpdatedAt = _max(
              maxServerUpdatedAt,
              remote.serverUpdatedAt,
            );
          }
        }
      }

      return maxServerUpdatedAt;
    } on PostgrestException catch (e) {
      if (e.code == '42P01') {
        throw const SyncSchemaException(
          'タグ同期用のテーブルがありません。docs/sample/supabase_schema.sql を実行してください',
        );
      }
      rethrow;
    }
  }

  Note _fromRemoteRow(Map<String, dynamic> row) {
    final serverUpdatedAt = _parseDateTime(row['server_updated_at']);
    final note = Note()
      ..uuid = row['id'] as String
      ..title = (row['title'] as String?) ?? ''
      ..content = (row['content'] as String?) ?? ''
      ..isDeleted = (row['is_deleted'] as bool?) ?? false
      ..createdAt = DateTime.parse(row['created_at'] as String).toUtc()
      ..localUpdatedAt = DateTime.parse(
        row['local_updated_at'] as String,
      ).toUtc()
      ..serverUpdatedAt = serverUpdatedAt
      ..syncVersion = (row['sync_version'] as int?) ?? 1
      ..clientId = row['client_id'] as String?
      ..isDirty = false;

    return note;
  }

  TagDictionaryEntry _tagFromRemoteRow(Map<String, dynamic> row) {
    final canonical = TagDictionaryRepository.normalizeTag(
      (row['canonical_tag'] as String?) ?? '',
    );
    final id = (row['id'] as String?) ?? '';
    final createdAt =
        _parseDateTime(row['created_at']) ?? DateTime.now().toUtc();
    final localUpdatedAt = _parseDateTime(row['local_updated_at']) ?? createdAt;
    final aliasesRaw = row['aliases'];
    final aliases =
        (aliasesRaw is List ? aliasesRaw : const [])
            .whereType<String>()
            .map(TagDictionaryRepository.normalizeTag)
            .where((t) => t.isNotEmpty && t != canonical)
            .toSet()
            .toList(growable: false)
          ..sort();

    final useCountRaw = row['use_count'];
    final useCount = useCountRaw is num ? useCountRaw.toInt() : 0;

    final entry = TagDictionaryEntry()
      ..uuid = id
      ..canonicalTag = canonical
      ..aliases = aliases
      ..useCount = useCount
      ..lastUsedAt = _parseDateTime(row['last_used_at'])
      ..createdAt = createdAt
      ..localUpdatedAt = localUpdatedAt
      ..serverUpdatedAt = _parseDateTime(row['server_updated_at'])
      ..syncVersion = (row['sync_version'] as int?) ?? 1
      ..clientId = row['client_id'] as String?
      ..isDeleted = (row['is_deleted'] as bool?) ?? false
      ..isDirty = false;
    return entry;
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

  bool _isEmptyNote(Note note) {
    return note.title.trim().isEmpty && note.content.trim().isEmpty;
  }

  bool _isRemoteTagNewer(TagDictionaryEntry remote, TagDictionaryEntry local) {
    if (remote.syncVersion != local.syncVersion) {
      return remote.syncVersion > local.syncVersion;
    }
    return remote.localUpdatedAt.isAfter(local.localUpdatedAt);
  }

  Future<void> _deleteRemoteEmptyNotes() async {
    await _client
        .from('notes')
        .delete()
        .eq('user_id', _userId)
        .eq('title', '')
        .eq('content', '')
        .eq('is_deleted', false);
  }

  Future<void> _purgeDeletedBefore(DateTime cutoff) async {
    final cutoffIso = cutoff.toIso8601String();
    await _client
        .from('notes')
        .delete()
        .eq('user_id', _userId)
        .eq('is_deleted', true)
        .lt('server_updated_at', cutoffIso);

    try {
      await _client
          .from(_tagTable)
          .delete()
          .eq('user_id', _userId)
          .eq('is_deleted', true)
          .lt('server_updated_at', cutoffIso);
    } on PostgrestException catch (e) {
      if (e.code == '42P01') {
        throw const SyncSchemaException(
          'タグ同期用のテーブルがありません。docs/sample/supabase_schema.sql を実行してください',
        );
      }
      rethrow;
    }

    await _noteRepository.purgeDeletedBefore(cutoff);
    await _tagDictionaryRepository.purgeDeletedBefore(cutoff);
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
            'local_updated_at': conflict.local.localUpdatedAt
                .toUtc()
                .toIso8601String(),
            'sync_version': conflict.local.syncVersion,
            'client_id': conflict.local.clientId ?? _clientId,
          },
        ];
        final rows = await _client
            .from('notes')
            .upsert(payload, onConflict: 'id')
            .select('id, server_updated_at');
        final serverUpdatedAtById = _extractServerUpdatedAt(rows);
        await _noteRepository.markClean(
          serverUpdatedAtById: serverUpdatedAtById,
        );
        return;
      case SyncConflictResolution.keepRemote:
        await _noteRepository.upsertFromRemote([conflict.remote]);
        return;
    }
  }
}

class SyncSchemaException implements Exception {
  const SyncSchemaException(this.message);

  final String message;

  @override
  String toString() => message;
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

enum SyncConflictResolution { keepLocal, keepRemote }

class SyncConflict {
  const SyncConflict({required this.local, required this.remote});

  final Note local;
  final Note remote;
}
