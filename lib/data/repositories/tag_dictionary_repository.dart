import 'dart:async';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import '../models/tag_dictionary_entry.dart';

class TagDictionaryRepository {
  TagDictionaryRepository({
    required Isar isar,
    required Uuid uuid,
    required String clientId,
  }) : _isar = isar,
       _uuid = uuid,
       _clientId = clientId;

  final Isar _isar;
  final Uuid _uuid;
  final String _clientId;
  DateTime _lastSyncAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _syncing = false;
  static const Duration _syncInterval = Duration(minutes: 5);

  static String normalizeTag(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed;
  }

  Future<void> _ensureSeeded() async {
    final now = DateTime.now();
    if (_syncing) return;
    if (now.difference(_lastSyncAt) < _syncInterval) return;
    _syncing = true;
    _lastSyncAt = now;
    try {
      final notes = await _isar.notes.where().findAll();
      final seedTags = <String>{
        for (final note in notes) ..._collectTags(note),
      };
      if (seedTags.isEmpty) return;

      await _isar.writeTxn(() async {
        final existing = await _isar.tagDictionaryEntrys.where().findAll();
        final metadataUpdates = <TagDictionaryEntry>[];
        for (final entry in existing) {
          var needsUpdate = false;
          var uuidValue = '';
          try {
            uuidValue = entry.uuid;
          } catch (_) {
            uuidValue = '';
          }
          if (uuidValue.isEmpty) {
            entry.uuid = _uuid.v4();
            needsUpdate = true;
          }
          if ((entry.clientId ?? '').isEmpty) {
            entry.clientId = _clientId;
            needsUpdate = true;
          }
          var localUpdatedAtMillis = 0;
          try {
            localUpdatedAtMillis = entry.localUpdatedAt.millisecondsSinceEpoch;
          } catch (_) {
            entry.localUpdatedAt = entry.createdAt;
            localUpdatedAtMillis = entry.localUpdatedAt.millisecondsSinceEpoch;
            needsUpdate = true;
          }
          if (localUpdatedAtMillis == 0) {
            entry.localUpdatedAt = entry.createdAt;
            needsUpdate = true;
          }
          if (entry.syncVersion <= 0) {
            entry.syncVersion = 1;
            needsUpdate = true;
          }
          if (needsUpdate) {
            entry.isDirty = true;
            metadataUpdates.add(entry);
          }
        }
        if (metadataUpdates.isNotEmpty) {
          await _isar.tagDictionaryEntrys.putAll(metadataUpdates);
        }
        final existingByCanonical = {
          for (final entry in existing) normalizeTag(entry.canonicalTag): entry,
        };
        final toInsert = <TagDictionaryEntry>[];
        final toUpdate = <TagDictionaryEntry>[];
        for (final tag in seedTags) {
          final existingEntry = existingByCanonical[tag];
          if (existingEntry != null) {
            if (existingEntry.isDeleted) {
              existingEntry
                ..isDeleted = false
                ..localUpdatedAt = now
                ..syncVersion = existingEntry.syncVersion + 1
                ..clientId = _clientId
                ..isDirty = true;
              toUpdate.add(existingEntry);
            }
            continue;
          }
          final entry = TagDictionaryEntry()
            ..uuid = _uuid.v4()
            ..canonicalTag = tag
            ..createdAt = now
            ..localUpdatedAt = now
            ..clientId = _clientId
            ..syncVersion = 1
            ..isDirty = true
            ..isDeleted = false;
          toInsert.add(entry);
        }
        if (toUpdate.isNotEmpty) {
          await _isar.tagDictionaryEntrys.putAll(toUpdate);
        }
        if (toInsert.isNotEmpty) {
          await _isar.tagDictionaryEntrys.putAll(toInsert);
        }
      });
    } finally {
      _syncing = false;
    }
  }

  Iterable<String> _collectTags(Note note) sync* {
    for (final tag in note.manualTags) {
      final normalized = normalizeTag(tag);
      if (normalized.isNotEmpty) yield normalized;
    }
    for (final tag in note.autoTags) {
      final normalized = normalizeTag(tag);
      if (normalized.isNotEmpty) yield normalized;
    }
  }

  Future<List<String>> listCanonicalTags({int limit = 200}) async {
    await _ensureSeeded();
    final entries = await _isar.tagDictionaryEntrys
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    entries.sort((a, b) {
      final byUse = b.useCount.compareTo(a.useCount);
      if (byUse != 0) return byUse;
      final aTime = a.lastUsedAt ?? a.createdAt;
      final bTime = b.lastUsedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return entries
        .map((e) => e.canonicalTag)
        .where((t) => t.isNotEmpty)
        .take(limit)
        .toList(growable: false);
  }

  Future<TagResolution> resolve(String tag) async {
    await _ensureSeeded();
    final normalized = normalizeTag(tag);
    if (normalized.isEmpty) {
      return const TagResolution.empty();
    }

    final direct = await _isar.tagDictionaryEntrys
        .where()
        .canonicalTagEqualTo(normalized)
        .findFirst();
    if (direct != null && !direct.isDeleted) {
      return TagResolution(canonicalTag: direct.canonicalTag, isNew: false);
    }

    final aliasMatch = await _isar.tagDictionaryEntrys
        .filter()
        .isDeletedEqualTo(false)
        .and()
        .aliasesElementEqualTo(normalized)
        .findFirst();
    if (aliasMatch != null) {
      return TagResolution(canonicalTag: aliasMatch.canonicalTag, isNew: false);
    }

    return TagResolution(canonicalTag: normalized, isNew: true);
  }

  Future<String> resolveToCanonical(String tag) async {
    final resolution = await resolve(tag);
    return resolution.canonicalTag;
  }

  Future<List<String>> resolveAll(Iterable<String> tags) async {
    final result = <String>[];
    for (final tag in tags) {
      final canonical = await resolveToCanonical(tag);
      if (canonical.isEmpty) continue;
      if (result.contains(canonical)) continue;
      result.add(canonical);
    }
    result.sort();
    return result;
  }

  Future<void> ensureCanonicalTags(Iterable<String> tags) async {
    await _ensureSeeded();
    final normalized = tags
        .map(normalizeTag)
        .where((t) => t.isNotEmpty)
        .toSet();
    if (normalized.isEmpty) return;

    await _isar.writeTxn(() async {
      final now = DateTime.now();
      final existing = await _isar.tagDictionaryEntrys
          .where()
          .anyOf(
            normalized.toList(growable: false),
            (q, tag) => q.canonicalTagEqualTo(tag),
          )
          .findAll();
      final existingByCanonical = {
        for (final entry in existing) normalizeTag(entry.canonicalTag): entry,
      };
      final toInsert = <TagDictionaryEntry>[];
      final toUpdate = <TagDictionaryEntry>[];
      for (final tag in normalized) {
        final entry = existingByCanonical[tag];
        if (entry != null) {
          if (entry.isDeleted) {
            entry.isDeleted = false;
            _markDirty(entry, now);
            toUpdate.add(entry);
          }
          continue;
        }
        toInsert.add(_newEntry(tag, now));
      }
      if (toUpdate.isNotEmpty) {
        await _isar.tagDictionaryEntrys.putAll(toUpdate);
      }
      if (toInsert.isNotEmpty) {
        await _isar.tagDictionaryEntrys.putAll(toInsert);
      }
    });
  }

  Future<void> recordUsage(String tag) async {
    await _ensureSeeded();
    final normalized = normalizeTag(tag);
    if (normalized.isEmpty) return;

    await _isar.writeTxn(() async {
      final direct = await _isar.tagDictionaryEntrys
          .where()
          .canonicalTagEqualTo(normalized)
          .findFirst();
      if (direct != null) {
        final now = DateTime.now();
        if (direct.isDeleted) {
          direct.isDeleted = false;
        }
        direct
          ..useCount = direct.useCount + 1
          ..lastUsedAt = now;
        _markDirty(direct, now);
        await _isar.tagDictionaryEntrys.put(direct);
        return;
      }

      final aliasMatch = await _isar.tagDictionaryEntrys
          .filter()
          .aliasesElementEqualTo(normalized)
          .findFirst();
      if (aliasMatch != null) {
        final now = DateTime.now();
        if (aliasMatch.isDeleted) {
          aliasMatch.isDeleted = false;
        }
        aliasMatch
          ..useCount = aliasMatch.useCount + 1
          ..lastUsedAt = now;
        _markDirty(aliasMatch, now);
        await _isar.tagDictionaryEntrys.put(aliasMatch);
        return;
      }

      final now = DateTime.now();
      final entry = _newEntry(normalized, now)
        ..useCount = 1
        ..lastUsedAt = now;
      await _isar.tagDictionaryEntrys.put(entry);
    });
  }

  Stream<int> watchDirtyCount() {
    return _isar.tagDictionaryEntrys
        .filter()
        .isDirtyEqualTo(true)
        .watch(fireImmediately: true)
        .map((items) => items.length);
  }

  Future<List<TagDictionaryEntry>> listDirtyEntries() async {
    await _ensureSeeded();
    return _isar.tagDictionaryEntrys.filter().isDirtyEqualTo(true).findAll();
  }

  Future<void> markClean({
    required Map<String, DateTime> serverUpdatedAtById,
    required Map<String, String> canonicalById,
  }) async {
    if (serverUpdatedAtById.isEmpty) return;

    await _isar.writeTxn(() async {
      for (final entry in serverUpdatedAtById.entries) {
        final remoteId = entry.key;
        final serverUpdatedAt = entry.value;
        final remoteCanonical = normalizeTag(canonicalById[remoteId] ?? '');
        if (remoteCanonical.isEmpty) continue;

        var local = await _isar.tagDictionaryEntrys
            .where()
            .uuidEqualTo(remoteId)
            .findFirst();
        local ??= await _isar.tagDictionaryEntrys
            .where()
            .canonicalTagEqualTo(remoteCanonical)
            .findFirst();
        if (local == null) continue;

        local
          ..uuid = remoteId
          ..canonicalTag = remoteCanonical
          ..serverUpdatedAt = serverUpdatedAt
          ..isDirty = false;
        await _isar.tagDictionaryEntrys.put(local);
      }
    });
  }

  Future<void> markCleanLocal({required List<String> ids}) async {
    if (ids.isEmpty) return;
    await _isar.writeTxn(() async {
      for (final id in ids) {
        final local = await _isar.tagDictionaryEntrys
            .where()
            .uuidEqualTo(id)
            .findFirst();
        if (local == null) continue;
        local.isDirty = false;
        await _isar.tagDictionaryEntrys.put(local);
      }
    });
  }

  Future<void> upsertFromRemote(
    List<TagDictionaryEntry> remoteEntries, {
    Set<String> overwriteDirtyIds = const {},
    Set<String> overwriteDirtyCanonicals = const {},
  }) async {
    if (remoteEntries.isEmpty) return;

    await _isar.writeTxn(() async {
      for (final remote in remoteEntries) {
        final remoteId = remote.uuid;
        final remoteCanonical = normalizeTag(remote.canonicalTag);
        if (remoteCanonical.isEmpty || remoteId.isEmpty) continue;

        var local = await _isar.tagDictionaryEntrys
            .where()
            .uuidEqualTo(remoteId)
            .findFirst();
        local ??= await _isar.tagDictionaryEntrys
            .where()
            .canonicalTagEqualTo(remoteCanonical)
            .findFirst();

        final shouldOverwrite =
            overwriteDirtyIds.contains(local?.uuid) ||
            overwriteDirtyCanonicals.contains(local?.canonicalTag);

        if (local != null && local.isDirty && !shouldOverwrite) {
          continue;
        }

        final next = local ?? TagDictionaryEntry();
        next
          ..uuid = remoteId
          ..canonicalTag = remoteCanonical
          ..aliases = remote.aliases
          ..useCount = remote.useCount
          ..lastUsedAt = remote.lastUsedAt
          ..createdAt = remote.createdAt
          ..localUpdatedAt = remote.localUpdatedAt
          ..serverUpdatedAt = remote.serverUpdatedAt
          ..syncVersion = remote.syncVersion
          ..clientId = remote.clientId
          ..isDeleted = remote.isDeleted
          ..isDirty = false;
        await _isar.tagDictionaryEntrys.put(next);
      }
    });
  }

  Future<void> purgeDeletedBefore(DateTime cutoff) async {
    await _isar.writeTxn(() async {
      final deleted = await _isar.tagDictionaryEntrys
          .filter()
          .isDeletedEqualTo(true)
          .findAll();
      final targets = deleted.where((entry) {
        final server = entry.serverUpdatedAt;
        if (server == null) return false;
        return server.isBefore(cutoff);
      });
      final ids = targets.map((e) => e.id).toList(growable: false);
      if (ids.isNotEmpty) {
        await _isar.tagDictionaryEntrys.deleteAll(ids);
      }
    });
  }

  Future<List<String>> buildAiCandidates({
    required String text,
    required List<String> existingTags,
    int limit = 120,
  }) async {
    await _ensureSeeded();
    final entries = await _isar.tagDictionaryEntrys
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    if (entries.isEmpty) return const [];

    final existingSet = existingTags
        .map(normalizeTag)
        .where((t) => t.isNotEmpty)
        .toSet();
    final lowerText = text.toLowerCase();
    final tokens = _tokenize(lowerText);

    final scored = <_ScoredTag>[];
    for (final entry in entries) {
      final canonical = entry.canonicalTag;
      if (canonical.isEmpty) continue;
      if (existingSet.contains(canonical)) continue;

      var score = entry.useCount.toDouble() * 0.2;
      if (lowerText.contains(canonical)) {
        score += 8;
      }
      for (final alias in entry.aliases) {
        final normalizedAlias = normalizeTag(alias);
        if (normalizedAlias.isEmpty) continue;
        if (lowerText.contains(normalizedAlias)) {
          score += 6;
        }
      }
      for (final token in tokens) {
        if (token.length < 2) continue;
        if (canonical.contains(token)) {
          score += 3;
        }
      }
      if (score <= 0) continue;
      scored.add(
        _ScoredTag(tag: canonical, score: score, useCount: entry.useCount),
      );
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.useCount.compareTo(a.useCount);
    });

    final result = <String>[];
    for (final item in scored) {
      if (result.contains(item.tag)) continue;
      result.add(item.tag);
      if (result.length >= limit) break;
    }

    if (result.length < limit) {
      final fallback = await listCanonicalTags(limit: limit);
      for (final tag in fallback) {
        if (existingSet.contains(tag)) continue;
        if (result.contains(tag)) continue;
        result.add(tag);
        if (result.length >= limit) break;
      }
    }

    return result.take(limit).toList(growable: false);
  }

  Future<List<TagSummary>> listTagSummaries({int limit = 200}) async {
    await _ensureSeeded();
    final entries = await _isar.tagDictionaryEntrys
        .filter()
        .isDeletedEqualTo(false)
        .findAll();
    final notes = await _isar.notes.filter().isDeletedEqualTo(false).findAll();

    final entryByCanonical = <String, TagDictionaryEntry>{};
    final aliasToCanonical = <String, String>{};
    for (final entry in entries) {
      final canonical = normalizeTag(entry.canonicalTag);
      if (canonical.isEmpty) continue;
      entryByCanonical[canonical] = entry;
      aliasToCanonical[canonical] = canonical;
      for (final alias in entry.aliases) {
        final normalizedAlias = normalizeTag(alias);
        if (normalizedAlias.isEmpty) continue;
        aliasToCanonical[normalizedAlias] = canonical;
      }
    }

    String canonicalize(String raw) {
      final normalized = normalizeTag(raw);
      if (normalized.isEmpty) return '';
      return aliasToCanonical[normalized] ?? normalized;
    }

    final noteCounts = <String, int>{};
    for (final note in notes) {
      final seenInNote = <String>{};
      for (final raw in [...note.manualTags, ...note.autoTags]) {
        final canonical = canonicalize(raw);
        if (canonical.isEmpty) continue;
        seenInNote.add(canonical);
      }
      for (final canonical in seenInNote) {
        noteCounts.update(canonical, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    final allCanonicals = <String>{
      ...entryByCanonical.keys,
      ...noteCounts.keys,
    };

    final summaries = <TagSummary>[];
    for (final canonical in allCanonicals) {
      final entry = entryByCanonical[canonical];
      summaries.add(
        TagSummary(
          tag: canonical,
          noteCount: noteCounts[canonical] ?? 0,
          useCount: entry?.useCount ?? 0,
        ),
      );
    }

    summaries.sort((a, b) {
      final byNotes = b.noteCount.compareTo(a.noteCount);
      if (byNotes != 0) return byNotes;
      final byUse = b.useCount.compareTo(a.useCount);
      if (byUse != 0) return byUse;
      return a.tag.compareTo(b.tag);
    });
    return summaries.take(limit).toList(growable: false);
  }

  Stream<List<TagSummary>> watchTagSummaries({int limit = 200}) async* {
    await _ensureSeeded();

    final controller = StreamController<List<TagSummary>>();

    Future<void> emit() async {
      controller.add(await listTagSummaries(limit: limit));
    }

    final subNotes = _isar.notes.watchLazy().listen((_) => emit());
    final subDict = _isar.tagDictionaryEntrys.watchLazy().listen((_) => emit());
    emit();

    controller.onCancel = () async {
      await subNotes.cancel();
      await subDict.cancel();
    };

    yield* controller.stream;
  }

  Future<void> renameTag({required String from, required String to}) async {
    await _ensureSeeded();
    final fromCanonical = normalizeTag(from);
    final toCanonical = normalizeTag(to);
    if (fromCanonical.isEmpty || toCanonical.isEmpty) return;
    if (fromCanonical == toCanonical) return;

    await _isar.writeTxn(() async {
      final now = DateTime.now();
      final notes = await _isar.notes
          .filter()
          .isDeletedEqualTo(false)
          .findAll();

      for (final note in notes) {
        final manual = _renameInTags(
          note.manualTags,
          fromCanonical,
          toCanonical,
        );
        final auto = _renameInTags(note.autoTags, fromCanonical, toCanonical);
        if (_listEquals(note.manualTags, manual) &&
            _listEquals(note.autoTags, auto)) {
          continue;
        }
        note
          ..manualTags = manual
          ..autoTags = auto
          ..localUpdatedAt = now
          ..syncVersion = note.syncVersion + 1
          ..isDirty = note.isDraft ? false : true;
        await _isar.notes.put(note);
      }

      final fromEntry = await _isar.tagDictionaryEntrys
          .where()
          .canonicalTagEqualTo(fromCanonical)
          .findFirst();
      final toEntry = await _isar.tagDictionaryEntrys
          .where()
          .canonicalTagEqualTo(toCanonical)
          .findFirst();

      if (fromEntry == null && toEntry == null) {
        final entry = _newEntry(toCanonical, now)
          ..aliases = [fromCanonical]
          ..lastUsedAt = now;
        await _isar.tagDictionaryEntrys.put(entry);
        return;
      }

      if (fromEntry != null && toEntry == null) {
        final nextAliases = <String>{
          for (final alias in fromEntry.aliases) normalizeTag(alias),
          fromCanonical,
        }..remove(toCanonical);
        fromEntry
          ..canonicalTag = toCanonical
          ..aliases = nextAliases.where((a) => a.isNotEmpty).toList()
          ..lastUsedAt = now
          ..isDeleted = false;
        _markDirty(fromEntry, now);
        await _isar.tagDictionaryEntrys.put(fromEntry);
        return;
      }

      if (toEntry != null) {
        final mergedAliases = <String>{
          for (final alias in toEntry.aliases) normalizeTag(alias),
          if (fromEntry != null) ...fromEntry.aliases.map(normalizeTag),
          fromCanonical,
        }..remove(toCanonical);
        toEntry
          ..aliases = mergedAliases.where((a) => a.isNotEmpty).toList()
          ..useCount = toEntry.useCount + (fromEntry?.useCount ?? 0)
          ..lastUsedAt = now
          ..isDeleted = false;
        _markDirty(toEntry, now);
        await _isar.tagDictionaryEntrys.put(toEntry);
        if (fromEntry != null) {
          fromEntry
            ..isDeleted = true
            ..lastUsedAt = now;
          _markDirty(fromEntry, now);
          await _isar.tagDictionaryEntrys.put(fromEntry);
        }
      }
    });
  }

  Future<void> deleteTag(String tag) async {
    await _ensureSeeded();
    final canonical = await resolveToCanonical(tag);
    if (canonical.isEmpty) return;

    await _isar.writeTxn(() async {
      final now = DateTime.now();
      final notes = await _isar.notes
          .filter()
          .isDeletedEqualTo(false)
          .findAll();
      for (final note in notes) {
        final manual = _removeFromTags(note.manualTags, canonical);
        final auto = _removeFromTags(note.autoTags, canonical);
        if (_listEquals(note.manualTags, manual) &&
            _listEquals(note.autoTags, auto)) {
          continue;
        }
        note
          ..manualTags = manual
          ..autoTags = auto
          ..localUpdatedAt = now
          ..syncVersion = note.syncVersion + 1
          ..isDirty = note.isDraft ? false : true;
        await _isar.notes.put(note);
      }

      final entry = await _isar.tagDictionaryEntrys
          .where()
          .canonicalTagEqualTo(canonical)
          .findFirst();
      if (entry != null) {
        entry
          ..isDeleted = true
          ..lastUsedAt = now;
        _markDirty(entry, now);
        await _isar.tagDictionaryEntrys.put(entry);
      }
    });
  }

  TagDictionaryEntry _newEntry(String canonical, DateTime now) {
    return TagDictionaryEntry()
      ..uuid = _uuid.v4()
      ..canonicalTag = canonical
      ..aliases = const []
      ..useCount = 0
      ..createdAt = now
      ..localUpdatedAt = now
      ..syncVersion = 1
      ..clientId = _clientId
      ..isDirty = true
      ..isDeleted = false;
  }

  void _markDirty(TagDictionaryEntry entry, DateTime now) {
    entry
      ..localUpdatedAt = now
      ..clientId = _clientId
      ..isDirty = true
      ..syncVersion = entry.syncVersion + 1;
  }

  List<String> _renameInTags(List<String> tags, String from, String to) {
    final result = <String>{};
    for (final raw in tags) {
      final normalized = normalizeTag(raw);
      if (normalized.isEmpty) continue;
      result.add(normalized == from ? to : normalized);
    }
    final list = result.toList()..sort();
    return list;
  }

  List<String> _removeFromTags(List<String> tags, String target) {
    final result = <String>{};
    for (final raw in tags) {
      final normalized = normalizeTag(raw);
      if (normalized.isEmpty || normalized == target) continue;
      result.add(normalized);
    }
    final list = result.toList()..sort();
    return list;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<String> _tokenize(String text) {
    final sanitized = text.replaceAll(RegExp(r'[^0-9a-zA-Zぁ-んァ-ン一-龥]+'), ' ');
    final tokens = sanitized
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    if (tokens.length <= 40) return tokens;
    return tokens.take(40).toList(growable: false);
  }
}

class TagSummary {
  const TagSummary({
    required this.tag,
    required this.noteCount,
    required this.useCount,
  });

  final String tag;
  final int noteCount;
  final int useCount;
}

class TagResolution {
  const TagResolution({required this.canonicalTag, required this.isNew});

  const TagResolution.empty() : canonicalTag = '', isNew = false;

  final String canonicalTag;
  final bool isNew;
}

class _ScoredTag {
  const _ScoredTag({
    required this.tag,
    required this.score,
    required this.useCount,
  });

  final String tag;
  final double score;
  final int useCount;
}
