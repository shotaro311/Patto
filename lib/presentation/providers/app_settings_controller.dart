import 'dart:convert';

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
      macShowHideKeyBinding: _readKeyBinding(
        prefs.getString(_kMacShowHideKeyBinding),
      ),
      charCountEnabled: prefs.getBool(_kCharCountEnabled) ?? true,
      charCountExcludeSymbols:
          prefs.getBool(_kCharCountExcludeSymbols) ?? false,
      aiAppleIntelligenceEnabled:
          prefs.getBool(_kAiAppleIntelligenceEnabled) ?? false,
      aiExternalApiEnabled:
          prefs.getBool(_kAiExternalApiEnabled) ??
              prefs.getBool(_kAiEnabled) ??
              false,
      aiPreviewEnabled: prefs.getBool(_kAiPreviewEnabled) ?? true,
      aiEditKeyBinding: _readKeyBinding(
        prefs.getString(_kAiEditKeyBinding),
      ),
      aiPromptSendKey: AiPromptSendKeyCodec.fromString(
        prefs.getString(_kAiPromptSendKey),
      ),
      aiPromptPresets: _readAiPresets(prefs.getString(_kAiPromptPresets)),
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

  static MacKeyBinding? _readKeyBinding(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return MacKeyBinding.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeKeyBinding(
    SharedPreferences prefs,
    String key,
    MacKeyBinding? binding,
  ) async {
    if (binding == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, jsonEncode(binding.toMap()));
  }

  static List<AiPromptPreset> _defaultAiPresets() {
    return const [
      AiPromptPreset(name: '翻訳', prompt: '入力された内容を日本語に翻訳してください。'),
      AiPromptPreset(
        name: '構成',
        prompt: '入力された文章の内容や、癖、テイストは変えずに、誤字や脱字などの致命的なミスのみ修正してください。',
      ),
      AiPromptPreset(name: '', prompt: ''),
      AiPromptPreset(name: '', prompt: ''),
      AiPromptPreset(name: '', prompt: ''),
      AiPromptPreset(name: '', prompt: ''),
    ];
  }

  static List<AiPromptPreset> _readAiPresets(String? raw) {
    if (raw == null || raw.isEmpty) return _defaultAiPresets();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return _defaultAiPresets();
      final presets = decoded
          .map((item) => AiPromptPreset.fromMap(item))
          .whereType<AiPromptPreset>()
          .toList();
      if (presets.isEmpty) return _defaultAiPresets();
      while (presets.length < 6) {
        presets.add(const AiPromptPreset(name: '', prompt: ''));
      }
      if (presets.length > 6) {
        return presets.take(6).toList();
      }
      return presets;
    } catch (_) {
      return _defaultAiPresets();
    }
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

  Future<void> setMacShowHideKeyBinding(MacKeyBinding? binding) async {
    state = state.copyWith(macShowHideKeyBinding: binding);
    await _writeKeyBinding(_prefs, _kMacShowHideKeyBinding, binding);
  }

  Future<void> setCharCountEnabled(bool enabled) async {
    await _prefs.setBool(_kCharCountEnabled, enabled);
    state = state.copyWith(charCountEnabled: enabled);
  }

  Future<void> setCharCountExcludeSymbols(bool enabled) async {
    await _prefs.setBool(_kCharCountExcludeSymbols, enabled);
    state = state.copyWith(charCountExcludeSymbols: enabled);
  }

  Future<void> setAiExternalApiEnabled(bool enabled) async {
    await _prefs.setBool(_kAiExternalApiEnabled, enabled);
    state = state.copyWith(aiExternalApiEnabled: enabled);
  }

  Future<void> setAiAppleIntelligenceEnabled(bool enabled) async {
    await _prefs.setBool(_kAiAppleIntelligenceEnabled, enabled);
    state = state.copyWith(aiAppleIntelligenceEnabled: enabled);
  }

  Future<void> setAiPreviewEnabled(bool enabled) async {
    await _prefs.setBool(_kAiPreviewEnabled, enabled);
    state = state.copyWith(aiPreviewEnabled: enabled);
  }

  Future<void> setAiEditKeyBinding(MacKeyBinding? binding) async {
    state = state.copyWith(aiEditKeyBinding: binding);
    await _writeKeyBinding(_prefs, _kAiEditKeyBinding, binding);
  }

  Future<void> setAiPromptSendKey(AiPromptSendKey key) async {
    await _prefs.setString(_kAiPromptSendKey, key.toStorageString());
    state = state.copyWith(aiPromptSendKey: key);
  }

  Future<void> setAiPromptPresets(List<AiPromptPreset> presets) async {
    final trimmed = presets
        .map((p) => AiPromptPreset(name: p.name, prompt: p.prompt))
        .toList();
    final normalized = List<AiPromptPreset>.from(trimmed);
    while (normalized.length < 6) {
      normalized.add(const AiPromptPreset(name: '', prompt: ''));
    }
    if (normalized.length > 6) {
      normalized.removeRange(6, normalized.length);
    }
    final payload = jsonEncode(normalized.map((p) => p.toMap()).toList());
    await _prefs.setString(_kAiPromptPresets, payload);
    state = state.copyWith(aiPromptPresets: normalized);
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
const _kMacShowHideKeyBinding = 'macShowHideKeyBinding';
const _kCharCountEnabled = 'charCountEnabled';
const _kCharCountExcludeSymbols = 'charCountExcludeSymbols';
const _kAiEnabled = 'aiEnabled';
const _kAiExternalApiEnabled = 'aiExternalApiEnabled';
const _kAiAppleIntelligenceEnabled = 'aiAppleIntelligenceEnabled';
const _kAiPreviewEnabled = 'aiPreviewEnabled';
const _kAiEditKeyBinding = 'aiEditKeyBinding';
const _kAiPromptSendKey = 'aiPromptSendKey';
const _kAiPromptPresets = 'aiPromptPresets';
const _kLastOpenedNoteId = 'lastOpenedNoteId';
const _kLastSyncAt = 'lastSyncAt';
