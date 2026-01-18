import 'package:flutter_riverpod/flutter_riverpod.dart';

final quickLaunchEventProvider = StateProvider<int>((ref) => 0);
final quickLaunchSourceProvider = StateProvider<String?>((ref) => null);

/// 外部ペースト（Clip、Aqua Voice等）のイベントを通知するプロバイダー
final externalPasteEventProvider = StateProvider<int>((ref) => 0);

/// 外部ペーストのコンテンツを保持するプロバイダー
final externalPasteContentProvider = StateProvider<String?>((ref) => null);
