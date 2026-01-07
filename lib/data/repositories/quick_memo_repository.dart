import 'package:shared_preferences/shared_preferences.dart';

class QuickMemoRepository {
  QuickMemoRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kDraftKey = 'quickMemoDraft';

  String loadDraft() {
    return _prefs.getString(_kDraftKey) ?? '';
  }

  Future<void> saveDraft(String value) async {
    if (value.trim().isEmpty) {
      await _prefs.remove(_kDraftKey);
      return;
    }
    await _prefs.setString(_kDraftKey, value);
  }

  Future<void> clearDraft() async {
    await _prefs.remove(_kDraftKey);
  }
}
