import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/app_settings.dart';

class ShortcutService {
  ShortcutService() : _channel = const MethodChannel(_channelName);

  final MethodChannel _channel;

  Future<void> configureMac({required MacModifierKey modifierKey}) async {
    if (!Platform.isMacOS) return;
    await _channel.invokeMethod<void>('configure', {
      'modifierKey': modifierKey.toStorageString(),
    });
    await _channel.invokeMethod<void>('start');
  }

  Future<void> stopMac() async {
    if (!Platform.isMacOS) return;
    await _channel.invokeMethod<void>('stop');
  }

  void setOnQuickLaunch(void Function(String? source) onQuickLaunch) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickLaunch') {
        final args = call.arguments;
        String? source;
        if (args is Map && args['source'] is String) {
          source = args['source'] as String;
        }
        onQuickLaunch(source);
      }
    });
  }
}

const _channelName = 'com.patto/quick_launch';
