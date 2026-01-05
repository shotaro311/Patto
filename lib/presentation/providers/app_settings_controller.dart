import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../domain/app_settings.dart';

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final uuid = ref.watch(uuidProvider);
  return AppSettingsController(prefs: prefs, uuid: uuid);
});

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController({
    required SharedPreferences prefs,
    required Uuid uuid,
  })  : _prefs = prefs,
        super(_load(prefs: prefs, uuid: uuid));

  final SharedPreferences _prefs;

  static AppSettings _load({
    required SharedPreferences prefs,
    required Uuid uuid,
  }) {
    final clientId = prefs.getString(_kClientId) ?? uuid.v4();
    prefs.setString(_kClientId, clientId);

    return AppSettings(
      clientId: clientId,
      syncEnabled: prefs.getBool(_kSyncEnabled) ?? false,
      quickLaunchOpenMode: QuickLaunchOpenModeCodec.fromString(
        prefs.getString(_kQuickLaunchOpenMode),
      ),
      macModifierKey: MacModifierKeyCodec.fromString(
        prefs.getString(_kMacModifierKey),
      ),
      aiEnabled: prefs.getBool(_kAiEnabled) ?? true,
      lastOpenedNoteId: prefs.getString(_kLastOpenedNoteId),
      lastSyncAt: _readDateTime(prefs, _kLastSyncAt),
    );
  }

  static DateTime? _readDateTime(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> _writeDateTime(
    SharedPreferences prefs,
    String key,
    DateTime? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, value.toIso8601String());
  }

  Future<void> setSyncEnabled(bool enabled) async {
    await _prefs.setBool(_kSyncEnabled, enabled);
    state = state.copyWith(syncEnabled: enabled);
  }

  Future<void> setQuickLaunchOpenMode(QuickLaunchOpenMode mode) async {
    await _prefs.setString(_kQuickLaunchOpenMode, mode.toStorageString());
    state = state.copyWith(quickLaunchOpenMode: mode);
  }

  Future<void> setMacModifierKey(MacModifierKey key) async {
    await _prefs.setString(_kMacModifierKey, key.toStorageString());
    state = state.copyWith(macModifierKey: key);
  }

  Future<void> setAiEnabled(bool enabled) async {
    await _prefs.setBool(_kAiEnabled, enabled);
    state = state.copyWith(aiEnabled: enabled);
  }

  Future<void> setLastOpenedNoteId(String? noteId) async {
    if (noteId == null) {
      await _prefs.remove(_kLastOpenedNoteId);
    } else {
      await _prefs.setString(_kLastOpenedNoteId, noteId);
    }
    state = state.copyWith(lastOpenedNoteId: noteId);
  }

  Future<void> setLastSyncAt(DateTime? value) async {
    await _writeDateTime(_prefs, _kLastSyncAt, value);
    state = state.copyWith(lastSyncAt: value);
  }
}

const _kClientId = 'clientId';
const _kSyncEnabled = 'syncEnabled';
const _kQuickLaunchOpenMode = 'quickLaunchOpenMode';
const _kMacModifierKey = 'macModifierKey';
const _kAiEnabled = 'aiEnabled';
const _kLastOpenedNoteId = 'lastOpenedNoteId';
const _kLastSyncAt = 'lastSyncAt';

