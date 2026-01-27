import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/app_settings.dart';
import '../domain/quick_launch_event.dart';

// test write

class ShortcutService {
  ShortcutService() : _channel = const MethodChannel(_channelName);

  final MethodChannel _channel;
  void Function(QuickLaunchEvent event)? _onQuickLaunch;
  void Function(String content)? _onExternalPaste;

  Future<void> configureMac({
    required MacModifierKey modifierKey,
    MacKeyBinding? showHideKeyBinding,
  }) async {
    if (!Platform.isMacOS) return;
    await _channel.invokeMethod<void>('configure', {
      'modifierKey': modifierKey.toStorageString(),
      'showHideKeyBinding': showHideKeyBinding?.toMap(),
    });
    await _channel.invokeMethod<void>('start');
  }

  Future<void> stopMac() async {
    if (!Platform.isMacOS) return;
    await _channel.invokeMethod<void>('stop');
  }

  void setOnQuickLaunch(void Function(QuickLaunchEvent event) onQuickLaunch) {
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
        String? actionRaw;
        if (args is Map) {
          if (args['source'] is String) {
            source = args['source'] as String;
          }
          if (args['action'] is String) {
            actionRaw = args['action'] as String;
          }
        }
        final action = QuickLaunchActionCodec.fromString(actionRaw);
        _onQuickLaunch?.call(QuickLaunchEvent(action: action, source: source));
        return;
      }

      if (call.method == 'onExternalPaste') {
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
