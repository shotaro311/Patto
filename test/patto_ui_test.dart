import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:patto/app.dart';
import 'package:patto/core/providers.dart';
import 'package:patto/data/models/note.dart';
import 'package:patto/data/repositories/note_repository.dart';
import 'package:patto/domain/app_settings.dart';
import 'package:patto/domain/quick_launch_event.dart';
import 'package:patto/presentation/providers/ai_providers.dart';
import 'package:patto/presentation/providers/app_settings_controller.dart';
import 'package:patto/presentation/providers/note_repository_provider.dart';
import 'package:patto/presentation/providers/notes_providers.dart';
import 'package:patto/presentation/providers/shortcut_provider.dart';
import 'package:patto/presentation/screens/note_editor_pane.dart';
import 'package:patto/presentation/screens/notes_home_screen.dart';
import 'package:patto/presentation/screens/settings_screen.dart';
import 'package:patto/presentation/theme/patto_theme.dart';
import 'package:patto/services/ai_key_repository.dart';
import 'package:patto/services/shortcut_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PattoApp reflects soft pastel theme', (tester) async {
    await tester.pumpWidget(
      await _buildPattoApp(themeStyle: AppThemeStyle.softPastel),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme.primary, const Color(0xFF7FAE98));
  });

  testWidgets('PattoApp reflects plain soft theme', (tester) async {
    await tester.pumpWidget(
      await _buildPattoApp(themeStyle: AppThemeStyle.plainSoft),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.colorScheme.primary, const Color(0xFF7B8A9A));
  });

  testWidgets('PattoApp enables dark mode', (tester) async {
    await tester.pumpWidget(
      await _buildPattoApp(
        themeStyle: AppThemeStyle.softPastel,
        darkModeEnabled: true,
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme?.colorScheme.brightness, Brightness.dark);
  });

  testWidgets('NotesHomeScreen smoke test', (tester) async {
    final note = _buildNote(
      id: 'note-home',
      title: '会議メモ',
      content: 'やることを整理する',
    );

    await tester.pumpWidget(
      await _buildScreenShell(const NotesHomeScreen(), notes: [note]),
    );
    await tester.pumpAndSettle();

    expect(find.text('検索'), findsOneWidget);
    expect(find.text('会議メモ'), findsOneWidget);
    expect(find.text('やることを整理する'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('NotesHomeScreen note menu opens on right click', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final note = _buildNote(
      id: 'note-menu',
      title: '右クリック確認',
      content: '本文は一覧に出ない',
    );

    await tester.pumpWidget(
      await _buildScreenShell(const NotesHomeScreen(), notes: [note]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('右クリック確認'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('タイトル変更'), findsOneWidget);
    expect(find.text('削除'), findsOneWidget);
  });

  testWidgets('NotesHomeScreen keeps editor visible on narrow width', (
    tester,
  ) async {
    final note = _buildNote(
      id: 'note-selected',
      title: '編集中メモ',
      content: 'この内容を維持したい',
    );

    await tester.pumpWidget(
      await _buildScreenShell(
        const NotesHomeScreen(),
        notes: [note],
        selectedNoteId: note.uuid,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('この内容を維持したい'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('NotesHomeScreen returns to list after closing mobile editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final note = _buildNote(
      id: 'note-mobile',
      title: 'モバイル確認',
      content: '戻ると一覧に戻りたい',
    );

    await tester.pumpWidget(
      await _buildScreenShell(const NotesHomeScreen(), notes: [note]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('モバイル確認'));
    await tester.pumpAndSettle();
    expect(find.text('戻ると一覧に戻りたい'), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.text('検索'), findsOneWidget);
    expect(find.text('モバイル確認'), findsOneWidget);
    expect(find.text('戻ると一覧に戻りたい'), findsNothing);
  });

  testWidgets('SettingsScreen smoke test', (tester) async {
    await tester.pumpWidget(await _buildScreenShell(const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Soft Pastel'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Soft Pastel'), findsOneWidget);
    expect(find.text('Plain Soft'), findsOneWidget);
    expect(find.text('起動とショートカット'), findsOneWidget);
  });

  testWidgets('SettingsScreen renders on narrow width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildScreenShell(const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Soft Pastel'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Soft Pastel'), findsOneWidget);
    expect(find.text('Plain Soft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsScreen desktop nav jumps to chat prompt section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildScreenShell(const SettingsScreen()));
    await tester.pumpAndSettle();

    final chatPromptFinder = find.text('AIチャットプロンプト');
    final initialDy = tester.getTopLeft(chatPromptFinder).dy;
    expect(initialDy, greaterThan(700));

    await tester.tap(find.text('AIチャット文面').first);
    await tester.pumpAndSettle();

    final jumpedDy = tester.getTopLeft(chatPromptFinder).dy;
    expect(jumpedDy, lessThan(initialDy));
    expect(jumpedDy, lessThan(initialDy - 250));
  });

  testWidgets('NoteEditorPane smoke test', (tester) async {
    final note = _buildNote(
      id: 'note-editor',
      title: '今日やること',
      content: '朝に企画書を作る',
    );

    await tester.pumpWidget(
      await _buildScreenShell(
        Scaffold(body: NoteEditorPane(noteId: note.uuid)),
        notes: [note],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日やること'), findsOneWidget);
    expect(find.text('朝に企画書を作る'), findsOneWidget);
    expect(find.byTooltip('新規メモ'), findsOneWidget);
  });

  testWidgets('NoteEditorPane AI chat menu includes no-prompt option', (
    tester,
  ) async {
    final note = _buildNote(
      id: 'note-editor-ai',
      title: '相談メモ',
      content: 'このメモを元に相談したい',
    );

    await tester.pumpWidget(
      await _buildScreenShell(
        Scaffold(body: NoteEditorPane(noteId: note.uuid)),
        notes: [note],
        aiEnabled: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('プロンプトなし'), findsOneWidget);
    expect(find.text('標準'), findsOneWidget);
  });

  testWidgets('NoteEditorPane shows mac submit shortcut hint', (tester) async {
    final note = _buildNote(
      id: 'note-editor-chat-submit',
      title: '送信テスト',
      content: 'コマンドエンターを確認したい',
    );

    await tester.pumpWidget(
      await _buildScreenShell(
        Scaffold(body: NoteEditorPane(noteId: note.uuid)),
        notes: [note],
        aiEnabled: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cmd+Enterで送信'), findsOneWidget);
  });

  testWidgets('NoteEditorPane resets AI chat from header button', (
    tester,
  ) async {
    final note = _buildNote(
      id: 'note-editor-chat-reset',
      title: 'リセット確認',
      content: 'チャット履歴を消したい',
    );

    await tester.pumpWidget(
      await _buildScreenShell(
        Scaffold(body: NoteEditorPane(noteId: note.uuid)),
        notes: [note],
        aiEnabled: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '途中の入力');
    await tester.pump();
    expect(find.text('途中の入力'), findsOneWidget);

    await tester.tap(find.byTooltip('チャットをリセット'));
    await tester.pump();

    expect(find.text('途中の入力'), findsNothing);
    expect(find.text('AIに相談したい内容を入力してください'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}

Future<Widget> _buildPattoApp({
  required AppThemeStyle themeStyle,
  bool darkModeEnabled = false,
  List<Note>? notes,
  List<Note>? drafts,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('themeStyle', themeStyle.toStorageString());
  await prefs.setBool('darkModeEnabled', darkModeEnabled);

  final controller = AppSettingsController(prefs: prefs, uuid: const Uuid());
  final repository = _FakeNoteRepository(
    notes: notes ?? const [],
    drafts: drafts ?? const [],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseConfigProvider.overrideWithValue(null),
      appSettingsProvider.overrideWith((ref) => controller),
      noteRepositoryProvider.overrideWithValue(repository),
      shortcutServiceProvider.overrideWithValue(_TestShortcutService()),
      aiKeyRepositoryProvider.overrideWithValue(_TestAiKeyRepository()),
    ],
    child: const PattoApp(),
  );
}

Future<Widget> _buildScreenShell(
  Widget child, {
  AppThemeStyle themeStyle = AppThemeStyle.softPastel,
  bool darkModeEnabled = false,
  bool aiEnabled = false,
  List<Note>? notes,
  List<Note>? drafts,
  String? selectedNoteId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('themeStyle', themeStyle.toStorageString());
  await prefs.setBool('darkModeEnabled', darkModeEnabled);
  await prefs.setBool('aiExternalApiEnabled', aiEnabled);

  final controller = AppSettingsController(prefs: prefs, uuid: const Uuid());
  final repository = _FakeNoteRepository(
    notes: notes ?? const [],
    drafts: drafts ?? const [],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      supabaseConfigProvider.overrideWithValue(null),
      appSettingsProvider.overrideWith((ref) => controller),
      selectedNoteIdProvider.overrideWith((ref) => selectedNoteId),
      noteRepositoryProvider.overrideWithValue(repository),
      shortcutServiceProvider.overrideWithValue(_TestShortcutService()),
      aiKeyRepositoryProvider.overrideWithValue(_TestAiKeyRepository()),
    ],
    child: MaterialApp(
      theme: buildPattoTheme(
        controller.state.themeStyle,
        brightness: controller.state.darkModeEnabled
            ? Brightness.dark
            : Brightness.light,
      ),
      home: child,
    ),
  );
}

class _FakeNoteRepository implements NoteRepository {
  _FakeNoteRepository({required List<Note> notes, required List<Note> drafts})
    : _notes = List<Note>.from(notes),
      _drafts = List<Note>.from(drafts);

  final List<Note> _notes;
  final List<Note> _drafts;

  @override
  Stream<List<Note>> watchNotes({required String query}) =>
      Stream.value(_notes);

  @override
  Stream<Note?> watchNote(String id) {
    Note? note;
    for (final item in [..._notes, ..._drafts]) {
      if (item.uuid == id) {
        note = item;
        break;
      }
    }
    return Stream.value(note);
  }

  @override
  Stream<int> watchDirtyCount() => Stream.value(0);

  @override
  Stream<List<Note>> watchDrafts({
    int limit = NoteRepository.defaultMaxDrafts,
  }) {
    return Stream.value(_drafts.take(limit).toList(growable: false));
  }

  @override
  Future<bool> isTitleDuplicate({
    required String title,
    required String excludeId,
  }) async {
    return false;
  }

  @override
  Future<void> updateTitle(String id, String title) async {}

  @override
  Future<void> softDelete(String id) async {}

  @override
  Future<Note?> getNote(String id) async {
    try {
      return [..._notes, ..._drafts].firstWhere((item) => item.uuid == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> autoArchiveDrafts({required int maxDrafts}) async {}

  @override
  Future<Note> createDraft({required String initialContent}) async {
    final note = _buildNote(
      id: 'draft-${_drafts.length + 1}',
      title: '',
      content: initialContent,
      isDraft: true,
    );
    _drafts.insert(0, note);
    return note;
  }

  @override
  Future<void> updateContent(String id, String content) async {}

  @override
  Future<Note> createNote({String? initialContent}) async {
    final note = _buildNote(
      id: 'note-${_notes.length + 1}',
      title: '',
      content: initialContent ?? '',
    );
    _notes.insert(0, note);
    return note;
  }

  @override
  Future<Note?> promoteDraftToNote(String id) async {
    return getNote(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestShortcutService extends ShortcutService {
  @override
  Future<void> configureMac({
    required MacModifierKey modifierKey,
    MacKeyBinding? showHideKeyBinding,
  }) async {}

  @override
  void setOnQuickLaunch(void Function(QuickLaunchEvent event) onQuickLaunch) {}

  @override
  void setOnExternalPaste(void Function(String content) onExternalPaste) {}
}

class _TestAiKeyRepository extends AiKeyRepository {
  _TestAiKeyRepository() : super(const FlutterSecureStorage());

  @override
  Future<String?> readKey() async => null;

  @override
  Future<void> writeKey(String value) async {}

  @override
  Future<void> deleteKey() async {}
}

Note _buildNote({
  required String id,
  required String title,
  required String content,
  bool isDraft = false,
}) {
  final now = DateTime(2026, 4, 14, 9, 0);
  return Note()
    ..uuid = id
    ..title = title
    ..content = content
    ..isDraft = isDraft
    ..isDeleted = false
    ..isDirty = false
    ..createdAt = now
    ..localUpdatedAt = now
    ..clientId = 'test-client';
}
