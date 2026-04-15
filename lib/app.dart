import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/app_settings.dart';
import 'domain/quick_launch_event.dart';
import 'presentation/providers/app_settings_controller.dart';
import 'presentation/providers/auto_sync_provider.dart';
import 'presentation/providers/note_repository_provider.dart';
import 'presentation/providers/notes_providers.dart';
import 'presentation/providers/quick_launch_provider.dart';
import 'presentation/providers/shortcut_provider.dart';
import 'presentation/screens/note_editor_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/notes_home_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/tag_manager_screen.dart';
import 'presentation/theme/patto_theme.dart';

class PattoApp extends ConsumerStatefulWidget {
  const PattoApp({super.key});

  @override
  ConsumerState<PattoApp> createState() => _PattoAppState();
}

class _PattoAppState extends ConsumerState<PattoApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  ProviderSubscription<AppSettings>? _macShortcutSub;
  ProviderSubscription<AsyncValue<int>>? _dirtyNotesSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final shortcutService = ref.read(shortcutServiceProvider);
    shortcutService.setOnQuickLaunch(_handleQuickLaunch);
    shortcutService.setOnExternalPaste(_handleExternalPaste);

    final settings = ref.read(appSettingsProvider);
    _configureMacShortcuts(settings);

    _macShortcutSub = ref.listenManual<AppSettings>(appSettingsProvider, (
      prev,
      next,
    ) {
      if (prev == null ||
          prev.macModifierKey != next.macModifierKey ||
          prev.macShowHideKeyBinding != next.macShowHideKeyBinding) {
        _configureMacShortcuts(next);
      }
    });

    final autoSync = ref.read(autoSyncControllerProvider);
    _dirtyNotesSub = ref.listenManual<AsyncValue<int>>(
      dirtyNotesCountProvider,
      (prev, next) {
        final count = next.valueOrNull ?? 0;
        if (count > 0) {
          autoSync.schedule();
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _macShortcutSub?.close();
    _dirtyNotesSub?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(autoSyncControllerProvider).schedule(delay: Duration.zero);
      if (Platform.isMacOS) {
        // 外部ツール（クリップボード履歴/音声入力など）からの入力が届く前に
        // テキストフィールドのfirst responderを取り戻すために、編集画面へフォーカス要求を通知する。
        ref.read(quickLaunchEventProvider.notifier).state++;
      }
    }
  }

  void _handleExternalPaste(String content) {
    ref.read(externalPasteContentProvider.notifier).state = content;
    ref.read(externalPasteEventProvider.notifier).state++;
  }

  void _configureMacShortcuts(AppSettings settings) {
    final shortcutService = ref.read(shortcutServiceProvider);
    shortcutService.configureMac(
      modifierKey: settings.macModifierKey,
      showHideKeyBinding: settings.macShowHideKeyBinding,
    );
  }

  void _showHomeRoute() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  Future<String> _resolveQuickLaunchNewNoteId() async {
    final repo = ref.read(noteRepositoryProvider);
    final selectedId = ref.read(selectedNoteIdProvider);
    if (selectedId != null) {
      final current = await repo.getNote(selectedId);
      if (current != null &&
          !current.isDraft &&
          !current.isDeleted &&
          current.title.trim().isEmpty &&
          current.content.trim().isEmpty &&
          current.attachments.isEmpty &&
          current.manualTags.isEmpty &&
          current.autoTags.isEmpty) {
        return current.uuid;
      }
    }

    final note = await repo.createNote();
    return note.uuid;
  }

  Future<void> _handleQuickLaunch(QuickLaunchEvent event) async {
    if (event.action == QuickLaunchAction.hide) {
      return;
    }

    ref.read(quickLaunchSourceProvider.notifier).state = event.source;
    final shouldRestoreCurrentScreen =
        (_navigatorKey.currentState?.canPop() ?? false) ||
        ref.read(selectedNoteIdProvider) != null;
    if (shouldRestoreCurrentScreen) {
      ref.read(quickLaunchEventProvider.notifier).state++;
      return;
    }

    final settings = ref.read(appSettingsProvider);
    _showHomeRoute();
    switch (settings.quickLaunchOpenMode) {
      case QuickLaunchOpenMode.newNote:
        final noteId = await _resolveQuickLaunchNewNoteId();
        await ref
            .read(appSettingsProvider.notifier)
            .setLastOpenedNoteId(noteId);
        if (Platform.isMacOS) {
          ref.read(selectedNoteIdProvider.notifier).state = noteId;
        } else {
          ref.read(selectedNoteIdProvider.notifier).state = null;
        }
        ref.read(quickLaunchEventProvider.notifier).state++;
        if (!Platform.isMacOS) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: noteId)),
          );
        }
        return;
      case QuickLaunchOpenMode.lastNote:
        final last = settings.lastOpenedNoteId;
        if (last == null) {
          ref.read(selectedNoteIdProvider.notifier).state = null;
          ref.read(quickLaunchEventProvider.notifier).state++;
          return;
        }

        await ref.read(appSettingsProvider.notifier).setLastOpenedNoteId(last);
        if (Platform.isMacOS) {
          ref.read(selectedNoteIdProvider.notifier).state = last;
        } else {
          ref.read(selectedNoteIdProvider.notifier).state = null;
        }

        ref.read(quickLaunchEventProvider.notifier).state++;

        if (!Platform.isMacOS) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: last)),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      title: 'Patto!',
      theme: buildPattoTheme(settings.themeStyle),
      darkTheme: buildPattoTheme(
        settings.themeStyle,
        brightness: Brightness.dark,
      ),
      themeMode: settings.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      themeAnimationCurve: Curves.easeOutCubic,
      themeAnimationDuration: const Duration(milliseconds: 260),
      navigatorKey: _navigatorKey,
      routes: {
        '/': (_) => const NotesHomeScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/auth': (_) => const AuthScreen(),
        '/tags': (_) => const TagManagerScreen(),
      },
    );
  }
}
