import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note.dart';
import '../providers/app_settings_controller.dart';
import '../providers/note_repository_provider.dart';
import '../providers/notes_providers.dart';
import '../widgets/app_input_decoration.dart';
import 'note_editor_pane.dart';
import 'note_editor_screen.dart';

class NotesHomeScreen extends ConsumerWidget {
  const NotesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final notesAsync = ref.watch(notesProvider);
    final selectedId = ref.watch(selectedNoteIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patto!'),
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: notesAsync.when(
        data: (notes) {
          final list = _NotesList(
            notes: notes,
            selectedId: selectedId,
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

          return Row(
            children: [
              SizedBox(width: 340, child: list),
              const VerticalDivider(width: 1),
              Expanded(
                child: selectedId == null
                    ? const Center(child: Text('メモを選択してください'))
                    : NoteEditorPane(noteId: selectedId),
              ),
            ],
          );
        },
        error: (e, _) => Center(child: Text('エラー: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新規メモ',
        onPressed: () async {
          final repo = ref.read(noteRepositoryProvider);
          final note = await repo.createNote();
          ref.read(selectedNoteIdProvider.notifier).state = note.uuid;
          await ref.read(appSettingsProvider.notifier).setLastOpenedNoteId(note.uuid);
          if (!isWide && context.mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: note.uuid)),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NotesList extends ConsumerWidget {
  const _NotesList({
    required this.notes,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Note> notes;
  final String? selectedId;
  final Future<void> Function(String noteId) onSelect;

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
            onChanged: (v) => ref.read(notesSearchQueryProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: notes.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final note = notes[index];
              final title = note.title.trim();
              final display = title.isEmpty ? '（無題）' : title;
              final selected = note.uuid == selectedId;
              return ListTile(
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
              );
            },
          ),
        ),
      ],
    );
  }
}
