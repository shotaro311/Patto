import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

import '../core/config/env.dart';
import '../domain/app_settings.dart';
import 'ai_key_repository.dart';
import 'apple_intelligence_client.dart';

const aiChatContextWindowOptions = <int>[4092, 8192, 16384, 32768];

String expandAiTitleRulePrompt(String rulePrompt, {DateTime? now}) {
  final value = now ?? DateTime.now();
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final today = '$year$month$day';
  return rulePrompt.replaceAll('{{today}}', today).trim();
}

String normalizeAiGeneratedTitle(String raw) {
  var text = raw.trim();
  if (text.isEmpty) {
    throw const AiException('AIの応答が空でした');
  }

  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isNotEmpty) {
    text = lines.first;
  }

  text = text.replaceFirst(RegExp(r'^タイトル\s*[:：]\s*'), '');
  text = text.replaceFirst(RegExp(r'^(?:[-*]\s+|\d+[.)]\s+)'), '');
  text = text.replaceAll(RegExp(r'''^["'「『【]+|["'」』】]+$'''), '');
  text = text.trim();
  if (text.isEmpty) {
    throw const AiException('AIの応答が空でした');
  }
  return text;
}

enum AiChatRole { user, assistant }

class AiChatMessageInput {
  const AiChatMessageInput({
    required this.role,
    required this.text,
    this.images = const [],
  });

  final AiChatRole role;
  final String text;
  final List<AiImageInput> images;
}

class AiService {
  const AiService(this._keyRepository, this._appleClient, this._settings);

  final AiKeyRepository _keyRepository;
  final AppleIntelligenceClient _appleClient;
  final AppSettings _settings;

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

  Future<List<String>> fetchLocalModels() async {
    final uri = _resolveOpenAiCompatibleModelsEndpoint();
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final apiKey = await _keyRepository.readKey();
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${apiKey.trim()}',
        );
      }

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiException(_extractOpenAiCompatibleError(body));
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const AiException('モデル一覧の応答形式が不正です');
      }
      final data = decoded['data'];
      if (data is! List) {
        throw const AiException('モデル一覧の応答形式が不正です');
      }

      final models = <String>[];
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final id = item['id'];
        if (id is! String) continue;
        final normalized = id.trim();
        if (normalized.isEmpty || models.contains(normalized)) continue;
        models.add(normalized);
      }
      models.sort();
      return models;
    } on FormatException {
      throw const AiException('モデル一覧の応答形式が不正です');
    } on SocketException {
      throw const AiException('ローカルLLMサーバーに接続できませんでした');
    } on HandshakeException {
      throw const AiException('ローカルLLMサーバーとの通信に失敗しました');
    } finally {
      client.close(force: true);
    }
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

  Future<String> generateTitle({
    required String content,
    required String rulePrompt,
    required bool useAppleIntelligence,
    required bool useExternalApi,
  }) async {
    final body = content.trim();
    if (body.isEmpty) {
      throw const AiException('本文が空のためタイトルを生成できません');
    }

    final resolvedRulePrompt = expandAiTitleRulePrompt(rulePrompt);

    final prompt = _buildTitlePrompt(
      content: body,
      rulePrompt: resolvedRulePrompt,
    );
    final appleInstruction = [
      '次の本文からメモのタイトルを1つだけ作成してください。',
      '出力はタイトルのみで、説明・前置き・改行は不要です。',
      '【タイトルルール】',
      resolvedRulePrompt,
    ].join('\n');

    if (useAppleIntelligence) {
      final availability = await _appleClient.checkAvailability();
      if (availability.isAvailable) {
        try {
          final result = await _appleClient.editText(
            instruction: appleInstruction,
            originalText: body,
          );
          return normalizeAiGeneratedTitle(result);
        } on PlatformException catch (e) {
          if (!useExternalApi) {
            throw AiException(_platformExceptionToMessage(e));
          }
        }
      } else if (!useExternalApi) {
        throw AiException(availability.localizedMessage);
      }
    }

    if (!useExternalApi) {
      throw const AiException('AIが有効化されていません。設定を確認してください');
    }

    final result = switch (_settings.aiExternalProvider) {
      AiExternalProvider.openAiCompatible =>
        await _generateTextWithOpenAiCompatible(
          systemPrompt: 'あなたはメモのタイトル作成アシスタントです。出力はタイトルのみです。',
          prompt: prompt,
        ),
      AiExternalProvider.gemini => await _generateTextWithGemini(prompt),
    };
    return normalizeAiGeneratedTitle(result);
  }

  Future<String> chatWithNote({
    required String noteTitle,
    required String noteContent,
    required List<AiImageInput> noteImages,
    required List<AiChatMessageInput> history,
    required String systemPrompt,
    required bool includeNoteContext,
    required bool useAppleIntelligence,
    required bool useExternalApi,
  }) async {
    if (history.isEmpty) {
      throw const AiException('送信するメッセージがありません');
    }

    final hasImages =
        noteImages.isNotEmpty ||
        history.any((message) => message.images.isNotEmpty);

    if (useAppleIntelligence) {
      final availability = await _appleClient.checkAvailability();
      if (availability.isAvailable) {
        if (hasImages) {
          if (!useExternalApi) {
            throw const AiException(
              '現在のAIでは画像チャットに対応していません。ビジョン対応モデルを選択してください。',
            );
          }
        } else {
          try {
            return await _chatWithAppleIntelligence(
              noteTitle: noteTitle,
              noteContent: noteContent,
              history: history,
              systemPrompt: systemPrompt,
              includeNoteContext: includeNoteContext,
            );
          } on PlatformException catch (e) {
            if (!useExternalApi) {
              throw AiException(_platformExceptionToMessage(e));
            }
          }
        }
      } else if (!useExternalApi) {
        throw AiException(availability.localizedMessage);
      }
    }

    if (!useExternalApi) {
      throw const AiException('AIが有効化されていません。設定を確認してください');
    }

    final normalizedNoteImages = _normalizeImageInputs(noteImages);
    final normalizedHistory = history
        .map(
          (message) => AiChatMessageInput(
            role: message.role,
            text: message.text,
            images: _normalizeImageInputs(message.images),
          ),
        )
        .toList(growable: false);
    final normalizedSystemPrompt = systemPrompt.trim();

    return switch (_settings.aiExternalProvider) {
      AiExternalProvider.openAiCompatible => await _chatWithOpenAiCompatible(
        noteTitle: noteTitle,
        noteContent: noteContent,
        noteImages: normalizedNoteImages,
        history: normalizedHistory,
        systemPrompt: normalizedSystemPrompt,
        includeNoteContext: includeNoteContext,
      ),
      AiExternalProvider.gemini => await _chatWithGemini(
        noteTitle: noteTitle,
        noteContent: noteContent,
        noteImages: normalizedNoteImages,
        history: normalizedHistory,
        systemPrompt: normalizedSystemPrompt,
        includeNoteContext: includeNoteContext,
      ),
    };
  }

  Future<List<String>> _suggestTagsWithExternal({
    required String text,
    required List<String> existingTags,
    required List<String> dictionaryTags,
  }) async {
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

    final raw = switch (_settings.aiExternalProvider) {
      AiExternalProvider.openAiCompatible =>
        await _generateTextWithOpenAiCompatible(
          systemPrompt: 'あなたはメモ整理アシスタントです。出力はJSONのみです。',
          prompt: prompt,
        ),
      AiExternalProvider.gemini => await _generateTextWithGemini(prompt),
    };
    if (raw.isEmpty) {
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

  Future<String> _chatWithAppleIntelligence({
    required String noteTitle,
    required String noteContent,
    required List<AiChatMessageInput> history,
    required String systemPrompt,
    required bool includeNoteContext,
  }) async {
    final transcript = _buildChatTranscript(history);
    final noteContext = includeNoteContext
        ? _buildChatNoteContext(
            noteTitle: noteTitle,
            noteContent: noteContent,
          )
        : '';
    final instructionLines = <String>[
      if (systemPrompt.trim().isNotEmpty) systemPrompt.trim(),
      '最後のユーザー発話に日本語で返答してください。',
    ];
    final originalText = [
      if (noteContext.isNotEmpty) noteContext,
      if (noteContext.isNotEmpty) '',
      '【会話履歴】',
      transcript,
    ].join('\n');
    return _appleClient.editText(
      instruction: instructionLines.join('\n'),
      originalText: originalText,
    );
  }

  Future<String> _chatWithGemini({
    required String noteTitle,
    required String noteContent,
    required List<AiImageInput> noteImages,
    required List<AiChatMessageInput> history,
    required String systemPrompt,
    required bool includeNoteContext,
  }) async {
    final apiKey = await _keyRepository.readKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiException('AI APIキーが未設定です');
    }

    final noteContext = includeNoteContext
        ? _buildChatNoteContext(
            noteTitle: noteTitle,
            noteContent: noteContent,
          )
        : '';
    final model = GenerativeModel(
      model: _resolvedExternalModel(),
      apiKey: apiKey,
      systemInstruction: systemPrompt.isEmpty ? null : Content.system(systemPrompt),
    );
    final prompt = <Content>[
      if (noteContext.isNotEmpty || noteImages.isNotEmpty)
        Content.multi([
          if (noteContext.isNotEmpty) TextPart(noteContext),
          for (final image in noteImages) DataPart(image.mimeType, image.bytes),
        ]),
      ...history.map(_toGeminiChatContent),
    ];
    final response = await model.generateContent(prompt);
    final text = response.text?.trim() ?? '';
    if (text.isEmpty) {
      throw const AiException('AIの応答が空でした');
    }
    return text;
  }

  Future<String> _chatWithOpenAiCompatible({
    required String noteTitle,
    required String noteContent,
    required List<AiImageInput> noteImages,
    required List<AiChatMessageInput> history,
    required String systemPrompt,
    required bool includeNoteContext,
  }) async {
    final noteContext = includeNoteContext
        ? _buildChatNoteContext(
            noteTitle: noteTitle,
            noteContent: noteContent,
          )
        : '';
    final trimmed = _trimChatHistoryForLocalModel(
      noteContext: noteContext,
      noteImages: noteImages,
      history: history,
      limit: _settings.aiChatContextWindowSize,
    );
    final messages = <Map<String, dynamic>>[
      if (systemPrompt.isNotEmpty) {'role': 'system', 'content': systemPrompt},
      if (trimmed.noteContext.isNotEmpty || trimmed.noteImages.isNotEmpty)
        _toOpenAiCompatibleMessage(
          role: 'user',
          text: trimmed.noteContext,
          images: trimmed.noteImages,
        ),
      ...trimmed.history.map(_toOpenAiCompatibleChatMessage),
    ];
    try {
      return await _sendOpenAiCompatibleMessages(messages);
    } on AiException catch (e) {
      if ((trimmed.noteImages.isNotEmpty ||
              trimmed.history.any((message) => message.images.isNotEmpty)) &&
          _looksLikeImageUnsupportedError(e.message)) {
        throw const AiException('現在のモデルは画像入力に対応していません。ビジョン対応モデルを選択してください。');
      }
      rethrow;
    }
  }

  Content _toGeminiChatContent(AiChatMessageInput message) {
    if (message.role == AiChatRole.assistant) {
      return Content.model([TextPart(message.text)]);
    }
    return Content.multi([
      if (message.text.trim().isNotEmpty) TextPart(message.text),
      for (final image in message.images) DataPart(image.mimeType, image.bytes),
    ]);
  }

  Map<String, dynamic> _toOpenAiCompatibleChatMessage(
    AiChatMessageInput message,
  ) {
    return _toOpenAiCompatibleMessage(
      role: message.role == AiChatRole.assistant ? 'assistant' : 'user',
      text: message.text,
      images: message.images,
    );
  }

  Map<String, dynamic> _toOpenAiCompatibleMessage({
    required String role,
    required String text,
    List<AiImageInput> images = const [],
  }) {
    final normalizedText = text.trim();
    if (images.isEmpty) {
      return {'role': role, 'content': normalizedText};
    }
    return {
      'role': role,
      'content': <Map<String, dynamic>>[
        if (normalizedText.isNotEmpty) {'type': 'text', 'text': normalizedText},
        for (final image in images)
          {
            'type': 'image_url',
            'image_url': {
              'url':
                  'data:${image.mimeType};base64,${base64Encode(image.bytes)}',
            },
          },
      ],
    };
  }

  _TrimmedChatContext _trimChatHistoryForLocalModel({
    required String noteContext,
    required List<AiImageInput> noteImages,
    required List<AiChatMessageInput> history,
    required int limit,
  }) {
    final safeLimit = limit < 4092 ? 4092 : limit;
    final maxNoteChars = noteContext.trim().isEmpty
        ? 0
        : (safeLimit * 0.55).round().clamp(1500, safeLimit);
    final trimmedNote = maxNoteChars == 0
        ? ''
        : _truncateTextForContext(noteContext, maxNoteChars);
    final kept = <AiChatMessageInput>[];
    final noteCost =
        trimmedNote.length +
        (noteImages.length * 900) +
        ((trimmedNote.isNotEmpty || noteImages.isNotEmpty) ? 120 : 0);
    var remaining = safeLimit - noteCost;
    for (final message in history.reversed) {
      final cost = _estimateChatMessageCost(message);
      if (kept.isEmpty || remaining - cost >= 0) {
        kept.add(message);
        remaining -= cost;
      }
    }
    return _TrimmedChatContext(
      noteContext: trimmedNote,
      noteImages: noteImages,
      history: kept.reversed.toList(growable: false),
    );
  }

  int _estimateChatMessageCost(AiChatMessageInput message) {
    return message.text.length + (message.images.length * 900) + 120;
  }

  String _truncateTextForContext(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    if (maxLength <= 80) return text.substring(text.length - maxLength);
    final headLength = (maxLength * 0.45).floor();
    final tailLength = maxLength - headLength - 16;
    final head = text.substring(0, headLength);
    final tail = text.substring(text.length - tailLength);
    return '$head\n\n[中略]\n\n$tail';
  }

  String _buildChatNoteContext({
    required String noteTitle,
    required String noteContent,
  }) {
    final displayTitle = noteTitle.trim().isEmpty ? '（無題）' : noteTitle.trim();
    return [
      '【現在のメモ】',
      'タイトル: $displayTitle',
      '本文:',
      noteContent.trim().isEmpty ? '（本文なし）' : noteContent,
    ].join('\n');
  }

  String _buildChatTranscript(List<AiChatMessageInput> history) {
    return history
        .map((message) {
          final speaker = switch (message.role) {
            AiChatRole.user => 'ユーザー',
            AiChatRole.assistant => 'AI',
          };
          final imageLabel = message.images.isEmpty
              ? ''
              : ' [画像${message.images.length}枚]';
          return '$speaker$imageLabel: ${message.text.trim()}';
        })
        .join('\n');
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
    final prompt = _buildEditPrompt(
      instruction: instruction,
      originalText: originalText,
    );
    final text = switch (_settings.aiExternalProvider) {
      AiExternalProvider.openAiCompatible =>
        await _generateTextWithOpenAiCompatible(
          systemPrompt: 'あなたは文章編集アシスタントです。出力は編集後の本文のみです。',
          prompt: prompt,
        ),
      AiExternalProvider.gemini => await _generateTextWithGemini(prompt),
    };
    if (text.isEmpty) {
      throw const AiException('AIの応答が空でした');
    }
    return text;
  }

  Future<String> _editTextWithExternalImages({
    required String instruction,
    required String originalText,
    required List<AiImageInput> images,
  }) async {
    final normalized = _normalizeImageInputs(images);
    if (normalized.isEmpty) {
      return _editTextWithExternal(
        instruction: instruction,
        originalText: originalText,
      );
    }

    final prompt = _buildEditPrompt(
      instruction: instruction,
      originalText: originalText,
    );
    final text = switch (_settings.aiExternalProvider) {
      AiExternalProvider.openAiCompatible =>
        await _generateTextWithOpenAiCompatible(
          systemPrompt: 'あなたは文章編集アシスタントです。出力は編集後の本文のみです。',
          prompt: prompt,
          images: normalized,
        ),
      AiExternalProvider.gemini => await _generateTextWithGemini(
        prompt,
        images: normalized,
      ),
    };
    if (text.isEmpty) {
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

  String _buildTitlePrompt({
    required String content,
    required String rulePrompt,
  }) {
    return [
      'あなたはメモのタイトル作成アシスタントです。',
      '本文を読み、タイトルを1つだけ作成してください。',
      '出力はタイトルのみです。説明、箇条書き、引用符、改行は不要です。',
      '',
      '【タイトルルール】',
      rulePrompt,
      '',
      '【本文】',
      content,
    ].join('\n');
  }

  List<AiImageInput> _normalizeImageInputs(List<AiImageInput> images) {
    final normalized = <AiImageInput>[];
    for (final image in images) {
      if (image.bytes.isEmpty) continue;
      if (image.mimeType == 'image/png' || image.mimeType == 'image/jpeg') {
        normalized.add(image);
        continue;
      }
      final decoded = img.decodeImage(image.bytes);
      if (decoded == null) continue;
      final png = img.encodePng(decoded);
      normalized.add(
        AiImageInput(bytes: Uint8List.fromList(png), mimeType: 'image/png'),
      );
    }
    return normalized;
  }

  String _resolvedExternalModel() {
    final configured = _settings.aiExternalModel.trim();
    if (configured.isNotEmpty) return configured;
    return Env.aiModelName;
  }

  Future<String> _generateTextWithGemini(
    String prompt, {
    List<AiImageInput> images = const [],
  }) async {
    final apiKey = await _keyRepository.readKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiException('AI APIキーが未設定です');
    }

    final model = GenerativeModel(
      model: _resolvedExternalModel(),
      apiKey: apiKey,
    );
    if (images.isEmpty) {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? '';
    }

    final parts = <Part>[TextPart(prompt)];
    for (final image in images) {
      parts.add(DataPart(image.mimeType, image.bytes));
    }
    final response = await model.generateContent([Content.multi(parts)]);
    return response.text?.trim() ?? '';
  }

  Uri _resolveOpenAiCompatibleEndpoint() {
    final base = _normalizedOpenAiCompatibleBaseUrl();
    if (base.isEmpty) {
      throw const AiException('AIのベースURLが未設定です');
    }
    final endpoint = base.endsWith('/chat/completions')
        ? base
        : '$base/chat/completions';
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AiException('AIのベースURLが不正です');
    }
    return uri;
  }

  Uri _resolveOpenAiCompatibleModelsEndpoint() {
    final base = _normalizedOpenAiCompatibleBaseUrl();
    if (base.isEmpty) {
      throw const AiException('AIのベースURLが未設定です');
    }
    final endpoint = base.endsWith('/models') ? base : '$base/models';
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AiException('AIのベースURLが不正です');
    }
    return uri;
  }

  String _normalizedOpenAiCompatibleBaseUrl() {
    final base = _settings.aiExternalBaseUrl.trim();
    if (base.isEmpty) return '';
    var normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    if (normalized.endsWith('/chat/completions')) {
      normalized = normalized.substring(
        0,
        normalized.length - '/chat/completions'.length,
      );
    } else if (normalized.endsWith('/models')) {
      normalized = normalized.substring(
        0,
        normalized.length - '/models'.length,
      );
    }
    return normalized;
  }

  Future<String> _generateTextWithOpenAiCompatible({
    required String systemPrompt,
    required String prompt,
    List<AiImageInput> images = const [],
  }) async {
    return _sendOpenAiCompatibleMessages([
      {'role': 'system', 'content': systemPrompt},
      _toOpenAiCompatibleMessage(role: 'user', text: prompt, images: images),
    ]);
  }

  Future<String> _sendOpenAiCompatibleMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final model = _resolvedExternalModel();
    if (model.isEmpty) {
      throw const AiException('AIのモデル名が未設定です');
    }

    final uri = _resolveOpenAiCompatibleEndpoint();
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final apiKey = await _keyRepository.readKey();
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${apiKey.trim()}',
        );
      }

      final payload = jsonEncode({'model': model, 'messages': messages});
      request.add(utf8.encode(payload));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiException(_extractOpenAiCompatibleError(body));
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const AiException('AIの応答形式が不正です');
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const AiException('AIの応答が空でした');
      }

      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        throw const AiException('AIの応答形式が不正です');
      }

      final message = first['message'];
      if (message is! Map<String, dynamic>) {
        throw const AiException('AIの応答形式が不正です');
      }

      final text = _extractOpenAiCompatibleContent(message['content']).trim();
      if (text.isEmpty) {
        throw const AiException('AIの応答が空でした');
      }
      return text;
    } on FormatException {
      throw const AiException('AIの応答形式が不正です');
    } on SocketException {
      throw const AiException('AIサーバーに接続できませんでした');
    } on HandshakeException {
      throw const AiException('AIサーバーとの通信に失敗しました');
    } finally {
      client.close(force: true);
    }
  }

  String _extractOpenAiCompatibleContent(Object? raw) {
    if (raw is String) return raw;
    if (raw is List) {
      final buffer = StringBuffer();
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final type = item['type'];
          if (type == 'text' && item['text'] is String) {
            buffer.write(item['text'] as String);
          }
        }
      }
      return buffer.toString();
    }
    return '';
  }

  String _extractOpenAiCompatibleError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic> && error['message'] is String) {
          return error['message'] as String;
        }
      }
    } catch (_) {}
    return 'AIサーバーでエラーが発生しました';
  }

  bool _looksLikeImageUnsupportedError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('image') ||
        lower.contains('vision') ||
        lower.contains('multimodal') ||
        lower.contains('unsupported content') ||
        lower.contains('input modality') ||
        lower.contains('画像');
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
  const AiImageInput({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

class _TrimmedChatContext {
  const _TrimmedChatContext({
    required this.noteContext,
    required this.noteImages,
    required this.history,
  });

  final String noteContext;
  final List<AiImageInput> noteImages;
  final List<AiChatMessageInput> history;
}

class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => 'AiException: $message';
}
