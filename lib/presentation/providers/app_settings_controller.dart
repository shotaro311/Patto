import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/env.dart';
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
  AppSettingsController({required SharedPreferences prefs, required Uuid uuid})
    : _prefs = prefs,
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
      aiExternalProvider: AiExternalProviderCodec.fromString(
        prefs.getString(_kAiExternalProvider),
      ),
      aiExternalBaseUrl:
          prefs.getString(_kAiExternalBaseUrl) ?? _defaultAiExternalBaseUrl,
      aiExternalModel: prefs.getString(_kAiExternalModel) ?? Env.aiModelName,
      aiPreviewEnabled: prefs.getBool(_kAiPreviewEnabled) ?? true,
      aiEditKeyBinding: _readKeyBinding(prefs.getString(_kAiEditKeyBinding)),
      aiPromptSendKey: AiPromptSendKeyCodec.fromString(
        prefs.getString(_kAiPromptSendKey),
      ),
      aiPromptPresets: _readAiPresets(prefs.getString(_kAiPromptPresets)),
      aiTitleRules: _readAiTitleRules(prefs.getString(_kAiTitleRules)),
      aiChatSystemPrompts: _readAiChatSystemPrompts(
        prefs.getString(_kAiChatSystemPrompts),
      ),
      aiChatContextWindowSize: _readAiChatContextWindowSize(prefs),
      aiImageSendLimit: _readAiImageSendLimit(prefs),
      lastOpenedNoteId: prefs.getString(_kLastOpenedNoteId),
      lastSyncAt: _readDateTime(prefs, _kLastSyncAt),
    );
  }

  static int _readAiImageSendLimit(SharedPreferences prefs) {
    final raw = prefs.getInt(_kAiImageSendLimit);
    if (raw == null || raw < 1) return 3;
    return raw;
  }

  static int _readAiChatContextWindowSize(SharedPreferences prefs) {
    final raw = prefs.getInt(_kAiChatContextWindowSize);
    if (raw == null || raw < 4092) return 8192;
    return raw;
  }

  static const _defaultAiExternalBaseUrl = 'http://127.0.0.1:1234/v1';

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

  static List<AiTitleRule> _defaultAiTitleRules() {
    return const [
      AiTitleRule(name: '簡潔', prompt: '本文の要点をつかみ、20文字以内の日本語タイトルを1つだけ付けてください。'),
      AiTitleRule(name: '', prompt: ''),
      AiTitleRule(name: '', prompt: ''),
    ];
  }

  static List<AiChatSystemPrompt> _defaultAiChatSystemPrompts() {
    return const [
      AiChatSystemPrompt(
        name: '標準',
        prompt:
            'あなたはメモ編集を支援するAIチャットです。現在のメモ本文と添付画像を常に参考にし、ユーザーの指示に沿って、編集案・追記案・改善案を日本語で簡潔に返してください。本文に反映しやすい完成文を優先してください。',
      ),
      AiChatSystemPrompt(name: '', prompt: ''),
      AiChatSystemPrompt(name: '', prompt: ''),
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

  static List<AiTitleRule> _readAiTitleRules(String? raw) {
    if (raw == null || raw.isEmpty) return _defaultAiTitleRules();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return _defaultAiTitleRules();
      final rules = decoded
          .map((item) => AiTitleRule.fromMap(item))
          .whereType<AiTitleRule>()
          .toList();
      if (rules.isEmpty) return _defaultAiTitleRules();
      while (rules.length < 3) {
        rules.add(const AiTitleRule(name: '', prompt: ''));
      }
      if (rules.length > 3) {
        return rules.take(3).toList();
      }
      return rules;
    } catch (_) {
      return _defaultAiTitleRules();
    }
  }

  static List<AiChatSystemPrompt> _readAiChatSystemPrompts(String? raw) {
    if (raw == null || raw.isEmpty) return _defaultAiChatSystemPrompts();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return _defaultAiChatSystemPrompts();
      final prompts = decoded
          .map((item) => AiChatSystemPrompt.fromMap(item))
          .whereType<AiChatSystemPrompt>()
          .toList();
      if (prompts.isEmpty) return _defaultAiChatSystemPrompts();
      while (prompts.length < 3) {
        prompts.add(const AiChatSystemPrompt(name: '', prompt: ''));
      }
      if (prompts.length > 3) {
        return prompts.take(3).toList();
      }
      return prompts;
    } catch (_) {
      return _defaultAiChatSystemPrompts();
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

  Future<void> setAiExternalProvider(AiExternalProvider provider) async {
    await _prefs.setString(_kAiExternalProvider, provider.toStorageString());
    state = state.copyWith(aiExternalProvider: provider);
  }

  Future<void> setAiExternalBaseUrl(String value) async {
    final next = value.trim();
    await _prefs.setString(_kAiExternalBaseUrl, next);
    state = state.copyWith(aiExternalBaseUrl: next);
  }

  Future<void> setAiExternalModel(String value) async {
    final next = value.trim();
    await _prefs.setString(_kAiExternalModel, next);
    state = state.copyWith(aiExternalModel: next);
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

  Future<void> setAiImageSendLimit(int value) async {
    final next = value < 1 ? 1 : value;
    await _prefs.setInt(_kAiImageSendLimit, next);
    state = state.copyWith(aiImageSendLimit: next);
  }

  Future<void> setAiChatContextWindowSize(int value) async {
    final next = value < 4092 ? 4092 : value;
    await _prefs.setInt(_kAiChatContextWindowSize, next);
    state = state.copyWith(aiChatContextWindowSize: next);
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

  Future<void> setAiTitleRules(List<AiTitleRule> rules) async {
    final trimmed = rules
        .map((rule) => AiTitleRule(name: rule.name, prompt: rule.prompt))
        .toList();
    final normalized = List<AiTitleRule>.from(trimmed);
    while (normalized.length < 3) {
      normalized.add(const AiTitleRule(name: '', prompt: ''));
    }
    if (normalized.length > 3) {
      normalized.removeRange(3, normalized.length);
    }
    final payload = jsonEncode(normalized.map((rule) => rule.toMap()).toList());
    await _prefs.setString(_kAiTitleRules, payload);
    state = state.copyWith(aiTitleRules: normalized);
  }

  Future<void> setAiChatSystemPrompts(List<AiChatSystemPrompt> prompts) async {
    final trimmed = prompts
        .map(
          (prompt) =>
              AiChatSystemPrompt(name: prompt.name, prompt: prompt.prompt),
        )
        .toList();
    final normalized = List<AiChatSystemPrompt>.from(trimmed);
    while (normalized.length < 3) {
      normalized.add(const AiChatSystemPrompt(name: '', prompt: ''));
    }
    if (normalized.length > 3) {
      normalized.removeRange(3, normalized.length);
    }
    final payload = jsonEncode(
      normalized.map((prompt) => prompt.toMap()).toList(),
    );
    await _prefs.setString(_kAiChatSystemPrompts, payload);
    state = state.copyWith(aiChatSystemPrompts: normalized);
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
const _kAiExternalProvider = 'aiExternalProvider';
const _kAiExternalBaseUrl = 'aiExternalBaseUrl';
const _kAiExternalModel = 'aiExternalModel';
const _kAiPreviewEnabled = 'aiPreviewEnabled';
const _kAiEditKeyBinding = 'aiEditKeyBinding';
const _kAiPromptSendKey = 'aiPromptSendKey';
const _kAiPromptPresets = 'aiPromptPresets';
const _kAiTitleRules = 'aiTitleRules';
const _kAiChatSystemPrompts = 'aiChatSystemPrompts';
const _kAiChatContextWindowSize = 'aiChatContextWindowSize';
const _kAiImageSendLimit = 'aiImageSendLimit';
const _kLastOpenedNoteId = 'lastOpenedNoteId';
const _kLastSyncAt = 'lastSyncAt';
