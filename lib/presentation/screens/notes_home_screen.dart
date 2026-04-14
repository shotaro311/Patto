import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note.dart';
import '../providers/app_settings_controller.dart';
import '../providers/note_repository_provider.dart';
import '../providers/notes_providers.dart';
import '../theme/patto_theme.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/patto_surface.dart';
import 'note_editor_pane.dart';
import 'note_editor_screen.dart';

class NotesHomeScreen extends ConsumerStatefulWidget {
  const NotesHomeScreen({super.key});

  @override
  ConsumerState<NotesHomeScreen> createState() => _NotesHomeScreenState();
}

class _NotesHomeScreenState extends ConsumerState<NotesHomeScreen> {
  bool _isSidebarVisible = true;
  static const double _sidebarWidth = 340;
  static const double _sidebarPeekWidth = 14;
  static const double _sidebarHoverWidth = 28;

  void _showSidebar() {
    if (_isSidebarVisible) return;
    setState(() {
      _isSidebarVisible = true;
    });
  }

  void _hideSidebar() {
    if (!_isSidebarVisible) return;
    setState(() {
      _isSidebarVisible = false;
    });
  }

  Future<void> _createNewNote(
    BuildContext context, {
    required bool isWide,
  }) async {
    try {
      final note = await ref.read(noteRepositoryProvider).createNote();
      await ref
          .read(appSettingsProvider.notifier)
          .setLastOpenedNoteId(note.uuid);
      if (isWide) {
        ref.read(selectedNoteIdProvider.notifier).state = note.uuid;
      } else if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoteEditorScreen(noteId: note.uuid),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('メモを作成できませんでした: $e')));
    }
  }

  PreferredSizeWidget _buildMobileAppBar(
    BuildContext context, {
    required bool showingEditor,
  }) {
    return AppBar(
      leading: showingEditor
          ? IconButton(
              tooltip: 'メモ一覧に戻る',
              onPressed: () {
                ref.read(selectedNoteIdProvider.notifier).state = null;
              },
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      title: Text(
        'Patto!',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontSize: 30),
      ),
      actions: [
        IconButton(
          tooltip: '設定',
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }

  Widget _buildWideSidebar(Widget list) {
    return MouseRegion(
      onEnter: (_) => _showSidebar(),
      onExit: (_) => _hideSidebar(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Column(
          children: [
            PattoSurface(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              color: context.pattoTokens.panelStrongColor,
              floating: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Patto!',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: '設定',
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/settings'),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: PattoSurface(
                padding: EdgeInsets.zero,
                floating: true,
                child: list,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySelection(BuildContext context, {required bool isWide}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PattoSurface(
            padding: const EdgeInsets.all(28),
            floating: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  tooltip: '新規メモを作成',
                  onPressed: () => _createNewNote(context, isWide: isWide),
                  icon: const Icon(Icons.add_rounded, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    minimumSize: const Size(56, 56),
                  ),
                ),
                const SizedBox(height: 14),
                Text('メモを作成する', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  '左端にマウスをホバーするとメモ一覧が開きます。\n上の＋ボタンから新しいメモを作成できます。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final notesAsync = ref.watch(notesProvider);
    final selectedId = ref.watch(selectedNoteIdProvider);

    return Scaffold(
      appBar: isWide
          ? null
          : _buildMobileAppBar(context, showingEditor: selectedId != null),
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          bottom: false,
          child: notesAsync.when(
            data: (notes) {
              final list = _NotesList(
                notes: notes,
                selectedId: selectedId,
                bottomPadding: 18,
                onSelect: (noteId) async {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setLastOpenedNoteId(noteId);
                  if (isWide) {
                    ref.read(selectedNoteIdProvider.notifier).state = noteId;
                  } else if (context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(noteId: noteId),
                      ),
                    );
                  }
                },
              );

              if (!isWide) {
                if (selectedId != null) {
                  return NoteEditorPane(noteId: selectedId);
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: list,
                );
              }

              return Stack(
                children: [
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: _isSidebarVisible
                            ? _sidebarWidth + 28
                            : _sidebarPeekWidth,
                        child: ClipRect(
                          child: Stack(
                            children: [
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                left: _isSidebarVisible
                                    ? 0
                                    : -(_sidebarWidth + 28 - _sidebarPeekWidth),
                                top: 0,
                                bottom: 0,
                                width: _sidebarWidth + 28,
                                child: _buildWideSidebar(list),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: MouseRegion(
                          onEnter: (_) => _hideSidebar(),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: selectedId == null
                                ? _buildEmptySelection(context, isWide: isWide)
                                : NoteEditorPane(noteId: selectedId),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_isSidebarVisible)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _sidebarHoverWidth,
                      child: MouseRegion(
                        onEnter: (_) => _showSidebar(),
                        child: const ColoredBox(
                          color: Colors.transparent,
                          child: SizedBox.expand(),
                        ),
                      ),
                    ),
                ],
              );
            },
            error: (e, _) => Center(child: Text('エラー: $e')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({
    required this.notes,
    required this.selectedId,
    this.bottomPadding = 0,
    required this.onSelect,
  });

  final List<Note> notes;
  final String? selectedId;
  final double bottomPadding;
  final Future<void> Function(String noteId) onSelect;

  Future<void> _showNoteMenu(
    BuildContext context,
    WidgetRef ref,
    Note note,
    Offset position,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<_NoteMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: const [
        PopupMenuItem(value: _NoteMenuAction.rename, child: Text('タイトル変更')),
        PopupMenuItem(value: _NoteMenuAction.delete, child: Text('削除')),
      ],
    );
    if (!context.mounted) return;
    if (action == null) return;
    if (!context.mounted) return;
    switch (action) {
      case _NoteMenuAction.rename:
        await _renameNote(context, ref, note);
      case _NoteMenuAction.delete:
        await _deleteNote(context, ref, note);
    }
  }

  Future<void> _renameNote(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final controller = TextEditingController(text: note.title);
    final focusNode = FocusNode();
    final repo = ref.read(noteRepositoryProvider);

    Future<void> submit(BuildContext dialogContext) async {
      final next = controller.text.trim();
      if (next.isNotEmpty) {
        final duplicated = await repo.isTitleDuplicate(
          title: next,
          excludeId: note.uuid,
        );
        if (duplicated) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('同じタイトルのメモが既にあります')));
            focusNode.requestFocus();
          }
          return;
        }
      }
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop(next);
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('タイトル変更'),
          content: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            decoration: appInputDecoration(hintText: 'タイトルを入力'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => submit(dialogContext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => submit(dialogContext),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    focusNode.dispose();

    if (result == null) return;
    final trimmed = result.trim();
    if (trimmed == note.title.trim()) return;
    await repo.updateTitle(note.uuid, trimmed);
  }

  Future<void> _deleteNote(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.softDelete(note.uuid);
    if (!context.mounted) return;
    if (ref.read(selectedNoteIdProvider) == note.uuid) {
      ref.read(selectedNoteIdProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (notes.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: TextField(
              decoration: appInputDecoration(
                hintText: '検索',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) =>
                  ref.read(notesSearchQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: PattoSurface(
                  padding: const EdgeInsets.all(24),
                  muted: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text('まだメモがありません', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '右下のボタンから、最初のメモを気軽に作れます。',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: TextField(
            decoration: appInputDecoration(
              hintText: '検索',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
            ),
            onChanged: (v) =>
                ref.read(notesSearchQueryProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(20, 6, 20, bottomPadding),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final title = note.title.trim();
              final display = title.isEmpty ? '（無題）' : title;
              final selected = note.uuid == selectedId;
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (event.buttons & kSecondaryMouseButton == 0) {
                    return;
                  }
                  _showNoteMenu(context, ref, note, event.position);
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PattoSurface(
                    selected: selected,
                    muted: !selected,
                    floating: selected,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    onTap: () => onSelect(note.uuid),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 42,
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _NoteMenuAction { rename, delete }
