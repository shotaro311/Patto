import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/note.dart';
import '../../data/repositories/note_repository.dart';
import 'note_repository_provider.dart';

final quickMemoControllerProvider =
    StateNotifierProvider<QuickMemoController, QuickMemoState>((ref) {
  return QuickMemoController(ref);
});

final quickMemoOpenProvider = StateProvider<bool>((ref) => false);

class QuickMemoState {
  static const _unset = Object();

  const QuickMemoState({
    required this.content,
    required this.currentDraftId,
    required this.loaded,
  });

  final String content;
  final String? currentDraftId;
  final bool loaded;

  QuickMemoState copyWith({
    String? content,
    Object? currentDraftId = _unset,
    bool? loaded,
  }) {
    return QuickMemoState(
      content: content ?? this.content,
      currentDraftId:
          identical(currentDraftId, _unset) ? this.currentDraftId : currentDraftId as String?,
      loaded: loaded ?? this.loaded,
    );
  }

  static const initial = QuickMemoState(
    content: '',
    currentDraftId: null,
    loaded: false,
  );
}

class QuickMemoController extends StateNotifier<QuickMemoState> {
  QuickMemoController(this._ref) : super(QuickMemoState.initial) {
    _init();
  }

  final Ref _ref;
  Timer? _debounce;
  StreamSubscription<List<Note>>? _draftsSub;

  static const _legacyDraftKey = 'quickMemoDraft';

  Future<void> _init() async {
    final repo = _ref.read(noteRepositoryProvider);
    _draftsSub = repo.watchDrafts(limit: 1).listen((drafts) {
      final next = state.copyWith(loaded: true);
      if (next.currentDraftId == null &&
          next.content.trim().isEmpty &&
          drafts.isNotEmpty) {
        final latest = drafts.first;
        state = next.copyWith(
          currentDraftId: latest.uuid,
          content: latest.content,
        );
        return;
      }
      state = next;
    });

    await _migrateLegacyDraftIfNeeded();
    if (!state.loaded) {
      state = state.copyWith(loaded: true);
    }
  }

  Future<void> _migrateLegacyDraftIfNeeded() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final legacy = prefs.getString(_legacyDraftKey);
    if (legacy == null || legacy.trim().isEmpty) return;

    await prefs.remove(_legacyDraftKey);

    final repo = _ref.read(noteRepositoryProvider);
    final draft = await repo.createDraft(initialContent: legacy);
    await repo.autoArchiveDrafts(maxDrafts: NoteRepository.defaultMaxDrafts);

    state = state.copyWith(
      currentDraftId: draft.uuid,
      content: legacy,
    );
  }

  void startNewDraft() {
    _debounce?.cancel();
    state = state.copyWith(currentDraftId: null, content: '');
  }

  Future<void> discardCurrentDraft() async {
    _debounce?.cancel();
    final id = state.currentDraftId;
    if (id != null) {
      await _ref.read(noteRepositoryProvider).deleteDraft(id);
    }
    state = state.copyWith(currentDraftId: null, content: '');
  }

  void updateContent(String value) {
    state = state.copyWith(content: value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final noteRepo = _ref.read(noteRepositoryProvider);
      final id = state.currentDraftId;
      if (id == null) {
        if (value.trim().isEmpty) return;
        final created = await noteRepo.createDraft(initialContent: value);
        await noteRepo.autoArchiveDrafts(maxDrafts: NoteRepository.defaultMaxDrafts);
        state = state.copyWith(currentDraftId: created.uuid);
        return;
      }
      await noteRepo.updateContent(id, value);
    });
  }

  Future<Note?> ensureDraftExists() async {
    final id = state.currentDraftId;
    if (id != null) {
      return _ref.read(noteRepositoryProvider).getNote(id);
    }
    final text = state.content.trim();
    if (text.isEmpty) return null;
    final created = await _ref.read(noteRepositoryProvider).createDraft(initialContent: text);
    await _ref.read(noteRepositoryProvider).autoArchiveDrafts(
          maxDrafts: NoteRepository.defaultMaxDrafts,
        );
    state = state.copyWith(currentDraftId: created.uuid);
    return created;
  }

  Future<Note?> saveAsNote() async {
    final id = state.currentDraftId;
    if (state.content.trim().isEmpty) return null;

    final repo = _ref.read(noteRepositoryProvider);
    if (id == null) {
      final note = await repo.createNote(initialContent: state.content);
      startNewDraft();
      return note;
    }

    final note = await repo.promoteDraftToNote(id);
    startNewDraft();
    return note;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _draftsSub?.cancel();
    super.dispose();
  }
}
