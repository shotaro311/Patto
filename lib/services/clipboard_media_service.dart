import 'package:flutter/services.dart';

class ClipboardMediaService {
  const ClipboardMediaService();

  static const MethodChannel _channel = MethodChannel(
    'com.patto/clipboard_media',
  );

  Future<Uint8List?> readImagePng() async {
    try {
      return await _channel.invokeMethod<Uint8List>('readImagePng');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
