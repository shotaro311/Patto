import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/config/env.dart';
import 'ai_key_repository.dart';
import 'apple_intelligence_client.dart';

class AiService {
  const AiService(this._keyRepository, this._appleClient);

  final AiKeyRepository _keyRepository;
  final AppleIntelligenceClient _appleClient;

  Future<AppleIntelligenceAvailability> checkAppleIntelligenceAvailability() {
    return _appleClient.checkAvailability();
  }

  Future<List<String>> suggestTags({
    required String text,
    required List<String> existingTags,
    required bool useAppleIntelligence,
    required bool useExternalApi,
  }) async {
    if (useAppleIntelligence) {
      final availability = await _appleClient.checkAvailability();
      if (availability.isAvailable) {
        try {
          final tags = await _appleClient.suggestTags(
            text: text,
            existingTags: existingTags,
          );
          return tags;
        } catch (_) {
          if (useExternalApi) {
            return _suggestTagsWithExternal(
              text: text,
              existingTags: existingTags,
            );
          }
          rethrow;
        }
      }
      if (useExternalApi) {
        return _suggestTagsWithExternal(
          text: text,
          existingTags: existingTags,
        );
      }
      throw const AiException('Apple Intelligenceを利用できません');
    }
    if (useExternalApi) {
      return _suggestTagsWithExternal(
        text: text,
        existingTags: existingTags,
      );
    }
    throw const AiException('AIが利用できません');
  }

  Future<List<String>> _suggestTagsWithExternal({
    required String text,
    required List<String> existingTags,
  }) async {
    final apiKey = await _keyRepository.readKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiException('AI APIキーが未設定です');
    }

    final model = GenerativeModel(
      model: Env.aiModelName,
      apiKey: apiKey,
    );

    final existing = existingTags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .take(50)
        .toList();

    final prompt = [
      'あなたはメモ整理アシスタントです。',
      '本文からタグ候補を提案してください。',
      '出力は次のJSONのみです（説明や前置きは不要）。',
      '{"tags":["tag1","tag2"]}',
      '',
      '制約:',
      '- tags は 1〜7件',
      '- 各 tag は短く（20文字以内）',
      '- 既存タグは含めない',
      '- 絵文字や記号だけのタグは避ける',
      '',
      '既存タグ: ${existing.join(', ')}',
      '',
      '本文:',
      text,
    ].join('\n');

    final response = await model.generateContent([Content.text(prompt)]);
    final raw = response.text?.trim();
    if (raw == null || raw.isEmpty) {
      throw const AiException('AIの応答が空でした');
    }

    final jsonText = _extractJsonObject(raw);
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const AiException('AIの応答形式が不正です');
    }
    final tagsRaw = decoded['tags'];
    if (tagsRaw is! List) {
      throw const AiException('AIの応答形式が不正です');
    }

    final existingSet = existing.toSet();
    final tags = <String>[];
    for (final item in tagsRaw) {
      if (item is! String) continue;
      final normalized = item.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (normalized.length > 20) continue;
      if (existingSet.contains(normalized)) continue;
      if (tags.contains(normalized)) continue;
      tags.add(normalized);
    }
    return tags.take(10).toList(growable: false);
  }

  Future<String> editText({
    required String instruction,
    required String originalText,
    required bool useAppleIntelligence,
    required bool useExternalApi,
  }) async {
    if (useAppleIntelligence) {
      final availability = await _appleClient.checkAvailability();
      if (availability.isAvailable) {
        try {
          return await _appleClient.editText(
            instruction: instruction,
            originalText: originalText,
          );
        } catch (_) {
          if (useExternalApi) {
            return _editTextWithExternal(
              instruction: instruction,
              originalText: originalText,
            );
          }
          rethrow;
        }
      }
      if (useExternalApi) {
        return _editTextWithExternal(
          instruction: instruction,
          originalText: originalText,
        );
      }
      throw const AiException('Apple Intelligenceを利用できません');
    }
    if (useExternalApi) {
      return _editTextWithExternal(
        instruction: instruction,
        originalText: originalText,
      );
    }
    throw const AiException('AIが利用できません');
  }

  Future<String> _editTextWithExternal({
    required String instruction,
    required String originalText,
  }) async {
    final apiKey = await _keyRepository.readKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiException('AI APIキーが未設定です');
    }

    final model = GenerativeModel(
      model: Env.aiModelName,
      apiKey: apiKey,
    );

    final prompt = [
      'あなたは文章編集アシスタントです。',
      'ユーザーの指示に従って文章を編集してください。',
      '出力は編集後の本文のみ（説明や前置きは不要）です。',
      '',
      '【指示】',
      instruction,
      '',
      '【本文】',
      originalText,
    ].join('\n');

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw const AiException('AIの応答が空でした');
    }
    return text;
  }

  String _extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end < 0 || end <= start) {
      throw const AiException('AIの応答形式が不正です');
    }
    return raw.substring(start, end + 1);
  }
}

class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => 'AiException: $message';
}
