import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note.dart';
import 'note_repository_provider.dart';

final notesSearchQueryProvider = StateProvider<String>((ref) => '');

final notesProvider = StreamProvider<List<Note>>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  final query = ref.watch(notesSearchQueryProvider);
  return repo.watchNotes(query: query);
});

final selectedNoteIdProvider = StateProvider<String?>((ref) => null);

final selectedNoteProvider = StreamProvider<Note?>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  final noteId = ref.watch(selectedNoteIdProvider);
  if (noteId == null) {
    return Stream<Note?>.value(null);
  }
  return repo.watchNote(noteId);
});

final noteByIdProvider = StreamProvider.family<Note?, String>((ref, id) {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchNote(id);
});

final dirtyNotesCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  return repo.watchDirtyCount();
});
