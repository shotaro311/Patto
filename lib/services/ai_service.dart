import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/config/env.dart';
import 'ai_key_repository.dart';

class AiService {
  const AiService(this._keyRepository);

  final AiKeyRepository _keyRepository;

  Future<String> editText({
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
}

class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => 'AiException: $message';
}

