import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

import '../core/config/env.dart';
import 'ai_key_repository.dart';
import 'apple_intelligence_client.dart';

class AiService {
  const AiService(this._keyRepository, this._appleClient);

  final AiKeyRepository _keyRepository;
  final AppleIntelligenceClient _appleClient;

  Future<String> editTextWithImages({
    required String instruction,
    required String originalText,
    required List<AiImageInput> images,
    required bool useAppleIntelligence,
    required bool useExternalApi,
  }) {
    return _editTextInternal(
      instruction: instruction,
      originalText: originalText,
      images: images,
      useAppleIntelligence: useAppleIntelligence,
      useExternalApi: useExternalApi,
    );
  }

  Future<AppleIntelligenceAvailability> checkAppleIntelligenceAvailability() {
    return _appleClient.checkAvailability();
  }

  Future<List<String>> suggestTags({
    required String text,
    required List<String> existingTags,
    required List<String> dictionaryTags,
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
            dictionaryTags: dictionaryTags,
          );
          return _limitTags(tags, existingTags);
        } on PlatformException catch (e) {
          if (useExternalApi) {
            return _suggestTagsWithExternal(
              text: text,
              existingTags: existingTags,
              dictionaryTags: dictionaryTags,
            );
          }
          throw AiException(_platformExceptionToMessage(e));
        }
      }
      if (useExternalApi) {
        return _suggestTagsWithExternal(
          text: text,
          existingTags: existingTags,
          dictionaryTags: dictionaryTags,
        );
      }
      throw AiException(availability.localizedMessage);
    }
    if (useExternalApi) {
      return _suggestTagsWithExternal(
        text: text,
        existingTags: existingTags,
        dictionaryTags: dictionaryTags,
      );
    }
    throw const AiException('AIが有効化されていません。設定を確認してください');
  }

  Future<List<String>> _suggestTagsWithExternal({
    required String text,
    required List<String> existingTags,
    required List<String> dictionaryTags,
  }) async {
    final apiKey = await _keyRepository.readKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiException('AI APIキーが未設定です');
    }

    final model = GenerativeModel(model: Env.aiModelName, apiKey: apiKey);

    final existing = existingTags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .take(50)
        .toList();
    final existingSet = existing.toSet();
    final dictionary = dictionaryTags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty && !existingSet.contains(t))
        .take(120)
        .toList(growable: false);

    final prompt = [
      'あなたはメモ整理アシスタントです。',
      '本文からタグ候補を提案してください。',
      '出力は次のJSONのみです（説明や前置きは不要）。',
      '{"tags":["tag1","tag2"]}',
      '',
      '制約:',
      '- tags は 1〜5件',
      '- 各 tag は短く（20文字以内）',
      '- 既存タグは含めない',
      '- 絵文字や記号だけのタグは避ける',
      '- タグ辞書に合うものがあれば辞書のタグを優先する',
      '',
      '既存タグ: ${existing.join(', ')}',
      if (dictionary.isNotEmpty) 'タグ辞書: ${dictionary.join(', ')}',
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
    return _limitTags(tags, existingTags);
  }

  Future<String> editText({
    required String instruction,
    required String originalText,
    required bool useAppleIntelligence,
    required bool useExternalApi,
  }) async {
    return _editTextInternal(
      instruction: instruction,
      originalText: originalText,
      images: const [],
      useAppleIntelligence: useAppleIntelligence,
      useExternalApi: useExternalApi,
    );
  }

  Future<String> _editTextInternal({
    required String instruction,
    required String originalText,
    required List<AiImageInput> images,
    required bool useAppleIntelligence,
    required bool useExternalApi,
  }) async {
    if (useAppleIntelligence) {
      final availability = await _appleClient.checkAvailability();
      if (availability.isAvailable) {
        if (images.isNotEmpty && useExternalApi) {
          try {
            return await _editTextWithExternalImages(
              instruction: instruction,
              originalText: originalText,
              images: images,
            );
          } catch (_) {
            // Fallback to Apple Intelligence when external API fails.
          }
        }
        try {
          return await _appleClient.editText(
            instruction: instruction,
            originalText: originalText,
          );
        } on PlatformException catch (e) {
          if (useExternalApi) {
            return _editTextWithExternalMaybeImages(
              instruction: instruction,
              originalText: originalText,
              images: images,
            );
          }
          throw AiException(_platformExceptionToMessage(e));
        }
      }
      if (useExternalApi) {
        return _editTextWithExternalMaybeImages(
          instruction: instruction,
          originalText: originalText,
          images: images,
        );
      }
      throw AiException(availability.localizedMessage);
    }
    if (useExternalApi) {
      return _editTextWithExternalMaybeImages(
        instruction: instruction,
        originalText: originalText,
        images: images,
      );
    }
    throw const AiException('AIが有効化されていません。設定を確認してください');
  }

  Future<String> _editTextWithExternalMaybeImages({
    required String instruction,
    required String originalText,
    required List<AiImageInput> images,
  }) {
    if (images.isEmpty) {
      return _editTextWithExternal(
        instruction: instruction,
        originalText: originalText,
      );
    }
    return _editTextWithExternalImages(
      instruction: instruction,
      originalText: originalText,
      images: images,
    );
  }

  Future<String> _editTextWithExternal({
    required String instruction,
    required String originalText,
  }) async {
    final apiKey = await _keyRepository.readKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiException('AI APIキーが未設定です');
    }

    final model = GenerativeModel(model: Env.aiModelName, apiKey: apiKey);

    final prompt = _buildEditPrompt(
      instruction: instruction,
      originalText: originalText,
    );
    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw const AiException('AIの応答が空でした');
    }
    return text;
  }

  Future<String> _editTextWithExternalImages({
    required String instruction,
    required String originalText,
    required List<AiImageInput> images,
  }) async {
    final apiKey = await _keyRepository.readKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiException('AI APIキーが未設定です');
    }

    final normalized = _normalizeImageInputs(images);
    if (normalized.isEmpty) {
      return _editTextWithExternal(
        instruction: instruction,
        originalText: originalText,
      );
    }

    final model = GenerativeModel(model: Env.aiModelName, apiKey: apiKey);
    final prompt = _buildEditPrompt(
      instruction: instruction,
      originalText: originalText,
    );
    final parts = <Part>[TextPart(prompt)];
    for (final image in normalized) {
      parts.add(DataPart(image.mimeType, image.bytes));
    }

    final response = await model.generateContent([Content.multi(parts)]);
    final text = response.text?.trim();
    if (text == null || text.isEmpty) {
      throw const AiException('AIの応答が空でした');
    }
    return text;
  }

  String _buildEditPrompt({
    required String instruction,
    required String originalText,
  }) {
    return [
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
  }

  List<AiImageInput> _normalizeImageInputs(List<AiImageInput> images) {
    final normalized = <AiImageInput>[];
    for (final image in images) {
      if (image.bytes.isEmpty) continue;
      if (image.mimeType == 'image/png' ||
          image.mimeType == 'image/jpeg') {
        normalized.add(image);
        continue;
      }
      final decoded = img.decodeImage(image.bytes);
      if (decoded == null) continue;
      final png = img.encodePng(decoded);
      normalized.add(
        AiImageInput(
          bytes: Uint8List.fromList(png),
          mimeType: 'image/png',
        ),
      );
    }
    return normalized;
  }

  String _extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end < 0 || end <= start) {
      throw const AiException('AIの応答形式が不正です');
    }
    return raw.substring(start, end + 1);
  }

  List<String> _limitTags(List<String> rawTags, List<String> existingTags) {
    final existingSet = existingTags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet();
    final tags = <String>[];
    for (final tag in rawTags) {
      final normalized = tag.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (normalized.length > 20) continue;
      if (existingSet.contains(normalized)) continue;
      if (tags.contains(normalized)) continue;
      tags.add(normalized);
    }
    return tags.take(5).toList(growable: false);
  }

  String _platformExceptionToMessage(PlatformException e) {
    return switch (e.code) {
      'refused' => 'Apple Intelligenceがこの指示を実行できませんでした',
      'empty_response' => 'Apple Intelligenceから応答がありませんでした',
      'not_available' => 'Apple Intelligenceが利用できません',
      'not_supported' => 'Apple Intelligenceはこのプラットフォームではサポートされていません',
      'invalid_format' => 'Apple Intelligenceの応答形式が不正です',
      _ => e.message ?? 'Apple Intelligenceでエラーが発生しました',
    };
  }
}

class AiImageInput {
  const AiImageInput({
    required this.bytes,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String mimeType;
}

class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => 'AiException: $message';
}
