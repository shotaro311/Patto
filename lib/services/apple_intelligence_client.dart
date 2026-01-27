import 'dart:io';

import 'package:flutter/services.dart';

enum AppleIntelligenceAvailability {
  available,
  notSupported,
  notEligible,
  notEnabled,
  modelNotReady,
  unknown;

  bool get isAvailable => this == AppleIntelligenceAvailability.available;

  String get localizedMessage => switch (this) {
    AppleIntelligenceAvailability.available => 'Apple Intelligenceが利用可能です',
    AppleIntelligenceAvailability.notSupported =>
      'Apple Intelligenceはこのプラットフォームではサポートされていません',
    AppleIntelligenceAvailability.notEligible =>
      'このデバイスはApple Intelligenceに対応していません',
    AppleIntelligenceAvailability.notEnabled =>
      'Apple Intelligenceが有効化されていません。システム設定で有効にしてください',
    AppleIntelligenceAvailability.modelNotReady =>
      'Apple Intelligenceのモデルが準備中です。しばらくお待ちください',
    AppleIntelligenceAvailability.unknown => 'Apple Intelligenceの状態を確認できませんでした',
  };
}

class AppleIntelligenceClient {
  const AppleIntelligenceClient();

  static const MethodChannel _channel = MethodChannel(
    'com.patto/apple_intelligence',
  );

  static const _refusalPatterns = [
    // English patterns
    "i'm sorry",
    "i am sorry",
    "i can't assist",
    "i cannot assist",
    "i can't help",
    "i cannot help",
    "i'm unable",
    "i am unable",
    "sorry, but i can't",
    "sorry, but i cannot",
    "i'm not able",
    "i am not able",
    "as an ai",
    "as a language model",
    // Japanese patterns
    "申し訳",
    "お手伝いできません",
    "対応できません",
    "できかねます",
    "お応えできません",
    "お答えできません",
    "サポートできません",
    "ご要望にお応えできません",
    "aiとして",
    "言語モデルとして",
  ];

  Future<AppleIntelligenceAvailability> checkAvailability() async {
    if (!Platform.isMacOS) {
      return AppleIntelligenceAvailability.notSupported;
    }
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'checkAvailability',
      );
      final status = result?['status'] as String?;
      return _mapStatus(status);
    } on PlatformException catch (_) {
      return AppleIntelligenceAvailability.unknown;
    }
  }

  Future<String> editText({
    required String instruction,
    required String originalText,
  }) async {
    if (!Platform.isMacOS) {
      throw PlatformException(
        code: 'not_supported',
        message: 'Apple Intelligenceはこのプラットフォームではサポートされていません',
      );
    }
    final result = await _channel.invokeMethod<String>('editText', {
      'instruction': instruction,
      'text': originalText,
    });
    final trimmed = result?.trim() ?? '';
    if (trimmed.isEmpty) {
      throw PlatformException(
        code: 'empty_response',
        message: 'Apple Intelligenceから応答がありませんでした',
      );
    }
    if (_looksLikeRefusal(trimmed)) {
      throw PlatformException(
        code: 'refused',
        message: 'Apple Intelligenceがこのリクエストを拒否しました',
      );
    }
    return trimmed;
  }

  Future<List<String>> suggestTags({
    required String text,
    required List<String> existingTags,
    required List<String> dictionaryTags,
  }) async {
    if (!Platform.isMacOS) {
      throw PlatformException(
        code: 'not_supported',
        message: 'Apple Intelligenceはこのプラットフォームではサポートされていません',
      );
    }
    final result = await _channel.invokeMethod<List<dynamic>>('suggestTags', {
      'text': text,
      'existingTags': existingTags,
      'dictionaryTags': dictionaryTags,
    });
    if (result == null) return const [];
    return result.whereType<String>().toList(growable: false);
  }

  AppleIntelligenceAvailability _mapStatus(String? status) {
    return switch (status) {
      'available' => AppleIntelligenceAvailability.available,
      'notEligible' => AppleIntelligenceAvailability.notEligible,
      'notEnabled' => AppleIntelligenceAvailability.notEnabled,
      'modelNotReady' => AppleIntelligenceAvailability.modelNotReady,
      'notAvailable' => AppleIntelligenceAvailability.unknown,
      'notSupported' => AppleIntelligenceAvailability.notSupported,
      _ => AppleIntelligenceAvailability.unknown,
    };
  }

  bool _looksLikeRefusal(String text) {
    final lower = text.toLowerCase();
    return _refusalPatterns.any(lower.contains);
  }
}
