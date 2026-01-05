import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/shortcut_service.dart';

final shortcutServiceProvider = Provider<ShortcutService>((ref) {
  return ShortcutService();
});

