import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import '../../models/note.dart';

Future<Isar> openIsar() async {
  final dir = await getApplicationSupportDirectory();
  final isar = await Isar.open(
    [NoteSchema],
    directory: dir.path,
  );
  if (kDebugMode) {
    try {
      final total = await isar.notes.where().count();
      final drafts = await isar.notes.filter().isDraftEqualTo(true).count();
      debugPrint('[Isar] dir=${dir.path} total=$total drafts=$drafts');
    } catch (e) {
      debugPrint('[Isar] inspect failed: $e');
    }
  }
  return isar;
}
