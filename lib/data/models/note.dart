import 'package:isar/isar.dart';

part 'note.g.dart';

@collection
class Note {
  Note();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  String title = '';
  String content = '';

  bool isDeleted = false;

  late DateTime createdAt;
  late DateTime localUpdatedAt;
  DateTime? serverUpdatedAt;

  int syncVersion = 1;
  String? clientId;

  bool isDirty = true;
}

String deriveTitleFromContent(String content) {
  final trimmed = content.trimLeft();
  if (trimmed.isEmpty) return '';
  final firstLine = trimmed.split('\n').first.trim();
  return firstLine.length <= 80 ? firstLine : firstLine.substring(0, 80);
}
