import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/note.dart';

Future<Isar> openIsar() async {
  final dir = await getApplicationSupportDirectory();
  return Isar.open(
    [NoteSchema],
    directory: dir.path,
  );
}

