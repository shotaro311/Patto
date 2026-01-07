import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/note.dart';
import '../../data/repositories/quick_memo_repository.dart';
import '../../data/repositories/note_repository.dart';
import 'note_repository_provider.dart';

final quickMemoRepositoryProvider = Provider<QuickMemoRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return QuickMemoRepository(prefs);
});

final quickMemoControllerProvider =
    StateNotifierProvider<QuickMemoController, QuickMemoState>((ref) {
  return QuickMemoController(ref);
});

final quickMemoOpenProvider = StateProvider<bool>((ref) => false);

class QuickMemoState {
  const QuickMemoState({
    required this.content,
    required this.loaded,
  });

  final String content;
  final bool loaded;

  QuickMemoState copyWith({
    String? content,
    bool? loaded,
  }) {
    return QuickMemoState(
      content: content ?? this.content,
      loaded: loaded ?? this.loaded,
    );
  }

  static const initial = QuickMemoState(content: '', loaded: false);
}

class QuickMemoController extends StateNotifier<QuickMemoState> {
  QuickMemoController(this._ref) : super(QuickMemoState.initial) {
    _load();
  }

  final Ref _ref;
  Timer? _debounce;

  void _load() {
    final repo = _ref.read(quickMemoRepositoryProvider);
    state = state.copyWith(content: repo.loadDraft(), loaded: true);
  }

  void updateContent(String value) {
    state = state.copyWith(content: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final repo = _ref.read(quickMemoRepositoryProvider);
      await repo.saveDraft(value);
    });
  }

  Future<Note?> saveAsNote() async {
    final content = state.content.trim();
    if (content.isEmpty) return null;

    final repo = _ref.read(noteRepositoryProvider);
    final note = await repo.createNote(initialContent: state.content);

    final memoRepo = _ref.read(quickMemoRepositoryProvider);
    await memoRepo.clearDraft();
    state = state.copyWith(content: '');
    return note;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final repo = _ref.read(quickMemoRepositoryProvider);
    repo.saveDraft(state.content);
    super.dispose();
  }
}
