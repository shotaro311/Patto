import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note.dart';
import '../providers/app_settings_controller.dart';
import '../providers/note_repository_provider.dart';
import '../providers/notes_providers.dart';
import '../providers/quick_memo_provider.dart';
import '../routes/quick_memo_route_args.dart';
import '../widgets/app_input_decoration.dart';
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

  Future<void> _openQuickMemo(BuildContext context) async {
    await Navigator.of(
      context,
    ).pushNamed('/quick-memo', arguments: const QuickMemoRouteArgs());
  }

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

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, bool hasDraft) {
    return AppBar(
      title: const Text('Patto!'),
      actions: [
        if (hasDraft)
          TextButton(
            onPressed: () => _openQuickMemo(context),
            child: const Text('下書き'),
          ),
        IconButton(
          tooltip: '設定',
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
          icon: const Icon(Icons.settings),
        ),
      ],
    );
  }

  Widget _buildWideSidebar(Widget list) {
    return MouseRegion(
      onEnter: (_) => _showSidebar(),
      onExit: (_) => _hideSidebar(),
      child: Stack(
        children: [
          Positioned.fill(child: list),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              tooltip: 'クイックメモ',
              onPressed: () => _openQuickMemo(context),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final notesAsync = ref.watch(notesProvider);
    final selectedId = ref.watch(selectedNoteIdProvider);
    final quickMemoState = ref.watch(quickMemoControllerProvider);
    final hasDraft =
        quickMemoState.loaded && quickMemoState.content.trim().isNotEmpty;

    return Scaffold(
      appBar: isWide ? null : _buildMobileAppBar(context, hasDraft),
      body: SafeArea(
        top: isWide,
        bottom: false,
        child: notesAsync.when(
          data: (notes) {
            final list = _NotesList(
              notes: notes,
              selectedId: selectedId,
              bottomPadding: isWide ? 88 : 0,
              onSelect: (noteId) async {
                ref.read(selectedNoteIdProvider.notifier).state = noteId;
                await ref
                    .read(appSettingsProvider.notifier)
                    .setLastOpenedNoteId(noteId);
                if (!isWide && context.mounted) {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(noteId: noteId),
                    ),
                  );
                }
              },
            );

            if (!isWide) return list;

            return Stack(
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: _isSidebarVisible ? _sidebarWidth + 1 : 0,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: _sidebarWidth + 1,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: _sidebarWidth,
                                  child: _buildWideSidebar(list),
                                ),
                                const VerticalDivider(width: 1),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: MouseRegion(
                        onEnter: (_) => _hideSidebar(),
                        child: selectedId == null
                            ? const Center(child: Text('メモを選択してください'))
                            : NoteEditorPane(noteId: selectedId),
                      ),
                    ),
                  ],
                ),
                if (!_isSidebarVisible)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 12,
                    child: MouseRegion(
                      opaque: false,
                      cursor: SystemMouseCursors.resizeLeftRight,
                      onEnter: (_) => _showSidebar(),
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            );
          },
          error: (e, _) => Center(child: Text('エラー: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
      floatingActionButton: isWide
          ? null
          : FloatingActionButton(
              tooltip: 'クイックメモ',
              onPressed: () => _openQuickMemo(context),
              child: const Icon(Icons.add),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: appInputDecoration(
              hintText: '検索',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) =>
                ref.read(notesSearchQueryProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(bottom: bottomPadding),
            itemCount: notes.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final note = notes[index];
              final title = note.title.trim();
              final display = title.isEmpty ? '（無題）' : title;
              final selected = note.uuid == selectedId;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTapDown: (details) =>
                    _showNoteMenu(context, ref, note, details.globalPosition),
                child: ListTile(
                  selected: selected,
                  title: Text(
                    display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    note.content.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelect(note.uuid),
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
