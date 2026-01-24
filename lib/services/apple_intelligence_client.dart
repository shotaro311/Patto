import 'dart:io';

import 'package:flutter/services.dart';

enum AppleIntelligenceAvailability {
  available,
  notSupported,
  notEligible,
  notEnabled,
  modelNotReady,
  unknown,
}

extension AppleIntelligenceAvailabilityX on AppleIntelligenceAvailability {
  bool get isAvailable => this == AppleIntelligenceAvailability.available;
}

class AppleIntelligenceClient {
  const AppleIntelligenceClient();

  static const MethodChannel _channel =
      MethodChannel('com.patto/apple_intelligence');

  Future<AppleIntelligenceAvailability> checkAvailability() async {
    if (!Platform.isMacOS) {
      return AppleIntelligenceAvailability.notSupported;
    }
    try {
      final result =
          await _channel.invokeMethod<Map<Object?, Object?>>('checkAvailability');
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
        message: 'Apple Intelligence is not supported on this platform.',
      );
    }
    final result = await _channel.invokeMethod<String>('editText', {
      'instruction': instruction,
      'text': originalText,
    });
    if (result == null || result.trim().isEmpty) {
      throw PlatformException(
        code: 'empty_response',
        message: 'Apple Intelligence returned empty response.',
      );
    }
    return result;
  }

  Future<List<String>> suggestTags({
    required String text,
    required List<String> existingTags,
  }) async {
    if (!Platform.isMacOS) {
      throw PlatformException(
        code: 'not_supported',
        message: 'Apple Intelligence is not supported on this platform.',
      );
    }
    final result = await _channel.invokeMethod<List<dynamic>>('suggestTags', {
      'text': text,
      'existingTags': existingTags,
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
}
