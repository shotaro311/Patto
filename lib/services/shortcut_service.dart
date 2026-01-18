import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/app_settings.dart';

class ShortcutService {
  ShortcutService() : _channel = const MethodChannel(_channelName);

  final MethodChannel _channel;
  void Function(String? source)? _onQuickLaunch;
  void Function(String content)? _onExternalPaste;

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
    _onQuickLaunch = onQuickLaunch;
    _setupHandler();
  }

  void setOnExternalPaste(void Function(String content) onExternalPaste) {
    _onExternalPaste = onExternalPaste;
    _setupHandler();
  }

  void _setupHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onQuickLaunch') {
        final args = call.arguments;
        String? source;
        if (args is Map && args['source'] is String) {
          source = args['source'] as String;
        }
        _onQuickLaunch?.call(source);
      } else if (call.method == 'onExternalPaste') {
        final args = call.arguments;
        if (args is Map && args['content'] is String) {
          final content = args['content'] as String;
          _onExternalPaste?.call(content);
        }
      }
    });
  }
}

const _channelName = 'com.patto/quick_launch';
