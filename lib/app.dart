import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/app_settings.dart';
import 'presentation/providers/app_settings_controller.dart';
import 'presentation/providers/auto_sync_provider.dart';
import 'presentation/providers/note_repository_provider.dart';
import 'presentation/providers/notes_providers.dart';
import 'presentation/providers/quick_launch_provider.dart';
import 'presentation/providers/quick_memo_provider.dart';
import 'presentation/providers/shortcut_provider.dart';
import 'presentation/screens/note_editor_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/notes_home_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/quick_memo_screen.dart';

class PattoApp extends ConsumerStatefulWidget {
  const PattoApp({super.key});

  @override
  ConsumerState<PattoApp> createState() => _PattoAppState();
}

class _PattoAppState extends ConsumerState<PattoApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  ProviderSubscription<MacModifierKey>? _macModifierKeySub;
  ProviderSubscription<AsyncValue<int>>? _dirtyNotesSub;

  @override
  void initState() {
    super.initState();

    final shortcutService = ref.read(shortcutServiceProvider);
    shortcutService.setOnQuickLaunch(_handleQuickLaunch);

    final settings = ref.read(appSettingsProvider);
    shortcutService.configureMac(modifierKey: settings.macModifierKey);

    _macModifierKeySub = ref.listenManual<MacModifierKey>(
      appSettingsProvider.select((s) => s.macModifierKey),
      (prev, next) => shortcutService.configureMac(modifierKey: next),
    );

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
    _macModifierKeySub?.close();
    _dirtyNotesSub?.close();
    super.dispose();
  }

  Future<void> _handleQuickLaunch() async {
    final settings = ref.read(appSettingsProvider);
    switch (settings.quickLaunchOpenMode) {
      case QuickLaunchOpenMode.newNote:
        ref.read(quickMemoControllerProvider);
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const QuickMemoScreen()),
        );
        ref.read(quickLaunchEventProvider.notifier).state++;
        return;
      case QuickLaunchOpenMode.lastNote:
        final repo = ref.read(noteRepositoryProvider);
        late final String noteId;
        final last = settings.lastOpenedNoteId;
        if (last == null) {
          final note = await repo.createNote();
          noteId = note.uuid;
        } else {
          noteId = last;
        }

        ref.read(selectedNoteIdProvider.notifier).state = noteId;
        await ref.read(appSettingsProvider.notifier).setLastOpenedNoteId(noteId);

        ref.read(quickLaunchEventProvider.notifier).state++;

        if (!Platform.isMacOS) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
          _navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: noteId)),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patto',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      navigatorKey: _navigatorKey,
      routes: {
        '/': (_) => const NotesHomeScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/auth': (_) => const AuthScreen(),
      },
    );
  }
}
