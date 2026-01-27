import 'package:isar/isar.dart';

part 'note.g.dart';

@collection
class Note {
  Note();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  /// true の場合、このメモは「下書き（クイックメモInbox）」として扱う。
  /// 同期対象からは除外する。
  bool isDraft = false;

  String title = '';
  String content = '';

  bool isDeleted = false;

  /// ユーザーが手動で付与したタグ（自動整理では変更しない）。
  List<String> manualTags = [];

  /// 自動整理（AI等）で提案・適用されたタグ。
  List<String> autoTags = [];

  /// 本文から抽出したリンク（例: [[noteId]] / URL など）。
  List<String> linksOut = [];

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
