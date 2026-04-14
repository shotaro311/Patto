import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:patto/domain/app_settings.dart';
import 'package:patto/presentation/providers/app_settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppSettingsController persists theme style', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = AppSettingsController(prefs: prefs, uuid: const Uuid());

    expect(controller.state.themeStyle, AppThemeStyle.softPastel);

    await controller.setThemeStyle(AppThemeStyle.plainSoft);

    expect(controller.state.themeStyle, AppThemeStyle.plainSoft);

    final reloaded = AppSettingsController(prefs: prefs, uuid: const Uuid());

    expect(reloaded.state.themeStyle, AppThemeStyle.plainSoft);
  });

  test('AppSettingsController persists dark mode', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = AppSettingsController(prefs: prefs, uuid: const Uuid());

    expect(controller.state.darkModeEnabled, isFalse);

    await controller.setDarkModeEnabled(true);

    expect(controller.state.darkModeEnabled, isTrue);

    final reloaded = AppSettingsController(prefs: prefs, uuid: const Uuid());

    expect(reloaded.state.darkModeEnabled, isTrue);
  });

  test('AppSettingsController exposes default AI chat prompt in settings', () async {
    final prefs = await SharedPreferences.getInstance();
    final controller = AppSettingsController(prefs: prefs, uuid: const Uuid());

    final prompt = controller.state.aiChatSystemPrompts.first;

    expect(prompt.name, '標準');
    expect(prompt.prompt, contains('メモ編集を支援するAIチャット'));
    expect(prompt.prompt, contains('本文に反映しやすい完成文'));
  });
}
