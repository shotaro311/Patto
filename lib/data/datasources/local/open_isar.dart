import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import '../../models/note.dart';
import '../../models/tag_dictionary_entry.dart';

Future<Isar> openIsar() async {
  final dir = await getApplicationSupportDirectory();
  final isar = await Isar.open([
    NoteSchema,
    TagDictionaryEntrySchema,
  ], directory: dir.path);
  if (kDebugMode) {
    try {
      final total = await isar.notes.where().count();
      final draftsActive = await isar.notes
          .filter()
          .isDraftEqualTo(true)
          .and()
          .isDeletedEqualTo(false)
          .count();
      final notesActive = await isar.notes
          .filter()
          .isDraftEqualTo(false)
          .and()
          .isDeletedEqualTo(false)
          .count();
      final deleted = await isar.notes.filter().isDeletedEqualTo(true).count();
      debugPrint(
        '[Isar] dir=${dir.path} total=$total notes=$notesActive drafts=$draftsActive deleted=$deleted',
      );
    } catch (e) {
      debugPrint('[Isar] inspect failed: $e');
    }
  }
  return isar;
}
