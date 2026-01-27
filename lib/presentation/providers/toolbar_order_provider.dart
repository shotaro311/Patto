import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';

const toolbarOrderDefault = <String>[
  'custom_prompts',
  'add_tag',
  'ai_tag_suggest',
  'ai_edit',
  'delete',
];

final toolbarOrderProvider =
    StateNotifierProvider<ToolbarOrderController, List<String>>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return ToolbarOrderController(prefs);
});

class ToolbarOrderController extends StateNotifier<List<String>> {
  ToolbarOrderController(this._prefs) : super(toolbarOrderDefault) {
    _load();
  }

  final SharedPreferences _prefs;

  static const _kToolbarOrder = 'toolbarOrder';

  void _load() {
    final raw = _prefs.getStringList(_kToolbarOrder);
    if (raw == null || raw.isEmpty) return;
    state = _normalize(raw);
  }

  void setOrder(List<String> next) {
    final normalized = _normalize(next);
    state = normalized;
    _prefs.setStringList(_kToolbarOrder, normalized);
  }

  List<String> _normalize(List<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final id in raw) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      if (!seen.add(trimmed)) continue;
      result.add(trimmed);
    }
    for (final id in toolbarOrderDefault) {
      if (seen.add(id)) result.add(id);
    }
    return result;
  }
}
