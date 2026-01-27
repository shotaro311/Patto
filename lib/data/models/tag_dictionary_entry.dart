import 'package:isar/isar.dart';

part 'tag_dictionary_entry.g.dart';

@collection
class TagDictionaryEntry {
  TagDictionaryEntry();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  @Index(unique: true, replace: true)
  late String canonicalTag;

  /// 同義語や表記揺れを canonicalTag に寄せるための別名。
  List<String> aliases = [];

  int useCount = 0;
  DateTime? lastUsedAt;
  late DateTime createdAt;

  DateTime? serverUpdatedAt;
  late DateTime localUpdatedAt;
  int syncVersion = 1;
  String? clientId;
  bool isDirty = true;
  bool isDeleted = false;
}
