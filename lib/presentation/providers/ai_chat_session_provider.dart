import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ai_service.dart';
import 'ai_providers.dart';
import 'app_settings_controller.dart';

const _aiChatSessionUnset = Object();

@immutable
class AiChatDraftImageState {
  const AiChatDraftImageState({
    required this.bytes,
    required this.mimeType,
    required this.label,
  });

  final Uint8List bytes;
  final String mimeType;
  final String label;

  AiImageInput toInput() {
    return AiImageInput(bytes: bytes, mimeType: mimeType);
  }
}

@immutable
class AiChatMessageState {
  const AiChatMessageState({
    required this.role,
    required this.text,
    this.images = const <AiChatDraftImageState>[],
    this.isLoading = false,
  });

  final AiChatRole role;
  final String text;
  final List<AiChatDraftImageState> images;
  final bool isLoading;

  AiChatMessageInput toInput() {
    return AiChatMessageInput(
      role: role,
      text: text,
      images: images.map((image) => image.toInput()).toList(growable: false),
    );
  }
}

@immutable
class AiChatSessionState {
  const AiChatSessionState({
    this.isOpen = false,
    this.isBusy = false,
    this.includeImageContext = false,
    this.includeNoteContext = true,
    this.preferredWidth = 520,
    this.selectedPromptIndex = 0,
    this.messages = const <AiChatMessageState>[],
    this.draftImages = const <AiChatDraftImageState>[],
    this.draftText = '',
  });

  final bool isOpen;
  final bool isBusy;
  final bool includeImageContext;
  final bool includeNoteContext;
  final double preferredWidth;
  final int selectedPromptIndex;
  final List<AiChatMessageState> messages;
  final List<AiChatDraftImageState> draftImages;
  final String draftText;

  AiChatSessionState copyWith({
    bool? isOpen,
    bool? isBusy,
    bool? includeImageContext,
    bool? includeNoteContext,
    double? preferredWidth,
    int? selectedPromptIndex,
    Object? messages = _aiChatSessionUnset,
    Object? draftImages = _aiChatSessionUnset,
    Object? draftText = _aiChatSessionUnset,
  }) {
    return AiChatSessionState(
      isOpen: isOpen ?? this.isOpen,
      isBusy: isBusy ?? this.isBusy,
      includeImageContext: includeImageContext ?? this.includeImageContext,
      includeNoteContext: includeNoteContext ?? this.includeNoteContext,
      preferredWidth: preferredWidth ?? this.preferredWidth,
      selectedPromptIndex: selectedPromptIndex ?? this.selectedPromptIndex,
      messages: identical(messages, _aiChatSessionUnset)
          ? this.messages
          : messages as List<AiChatMessageState>,
      draftImages: identical(draftImages, _aiChatSessionUnset)
          ? this.draftImages
          : draftImages as List<AiChatDraftImageState>,
      draftText: identical(draftText, _aiChatSessionUnset)
          ? this.draftText
          : draftText as String,
    );
  }
}

class AiChatSessionController extends StateNotifier<AiChatSessionState> {
  AiChatSessionController(this._ref, this.noteId)
    : super(const AiChatSessionState());

  final Ref _ref;
  final String noteId;

  int _requestToken = 0;

  void open() {
    if (state.isOpen) return;
    state = state.copyWith(isOpen: true);
  }

  void close() {
    if (!state.isOpen) return;
    state = state.copyWith(isOpen: false);
  }

  void setDraftText(String value) {
    if (state.draftText == value) return;
    state = state.copyWith(draftText: value);
  }

  void setSelectedPromptIndex(int value) {
    if (state.selectedPromptIndex == value) return;
    state = state.copyWith(selectedPromptIndex: value);
  }

  void setIncludeImageContext(bool value) {
    if (state.includeImageContext == value) return;
    state = state.copyWith(includeImageContext: value);
  }

  void setIncludeNoteContext(bool value) {
    if (state.includeNoteContext == value) return;
    state = state.copyWith(includeNoteContext: value);
  }

  void addDraftImages(List<AiChatDraftImageState> images) {
    if (images.isEmpty) return;
    state = state.copyWith(
      isOpen: true,
      draftImages: [...state.draftImages, ...images],
    );
  }

  void removeDraftImageAt(int index) {
    if (index < 0 || index >= state.draftImages.length) return;
    final next = [...state.draftImages]..removeAt(index);
    state = state.copyWith(draftImages: next);
  }

  void setPreferredWidth(double value) {
    if (state.preferredWidth == value) return;
    state = state.copyWith(preferredWidth: value);
  }

  void reset() {
    _requestToken++;
    state = state.copyWith(
      isOpen: true,
      isBusy: false,
      messages: const <AiChatMessageState>[],
      draftImages: const <AiChatDraftImageState>[],
      draftText: '',
    );
  }

  Future<String?> send({
    required String noteTitle,
    required String noteContent,
    required List<AiImageInput> noteImages,
    required String systemPrompt,
  }) async {
    if (state.isBusy) return null;

    final text = state.draftText.trim();
    final draftImages = List<AiChatDraftImageState>.from(state.draftImages);
    if (text.isEmpty && draftImages.isEmpty) return null;

    final previousMessages = state.messages
        .where((message) => !message.isLoading)
        .toList(growable: false);
    final userMessage = AiChatMessageState(
      role: AiChatRole.user,
      text: text,
      images: draftImages,
    );
    final token = ++_requestToken;

    state = state.copyWith(
      isBusy: true,
      isOpen: true,
      draftText: '',
      draftImages: const <AiChatDraftImageState>[],
      messages: [
        ...state.messages,
        userMessage,
        const AiChatMessageState(
          role: AiChatRole.assistant,
          text: '',
          isLoading: true,
        ),
      ],
    );

    try {
      final settings = _ref.read(appSettingsProvider);
      final ai = _ref.read(aiServiceProvider);
      final response = await ai.chatWithNote(
        noteTitle: noteTitle,
        noteContent: noteContent,
        noteImages: noteImages,
        history: [
          ...previousMessages.map((message) => message.toInput()),
          userMessage.toInput(),
        ],
        systemPrompt: systemPrompt,
        includeNoteContext: state.includeNoteContext,
        useAppleIntelligence: settings.aiAppleIntelligenceEnabled,
        useExternalApi: settings.aiExternalApiEnabled,
      );

      if (token != _requestToken) return null;

      final nextMessages = List<AiChatMessageState>.from(state.messages);
      final loadingIndex = nextMessages.lastIndexWhere(
        (message) => message.role == AiChatRole.assistant && message.isLoading,
      );
      if (loadingIndex >= 0) {
        nextMessages[loadingIndex] = AiChatMessageState(
          role: AiChatRole.assistant,
          text: response,
        );
      } else {
        nextMessages.add(
          AiChatMessageState(role: AiChatRole.assistant, text: response),
        );
      }
      state = state.copyWith(isBusy: false, messages: nextMessages);
      return null;
    } catch (e) {
      if (token != _requestToken) return null;
      final message = e is AiException ? e.message : 'AIチャットに失敗しました。';
      state = state.copyWith(
        isBusy: false,
        messages: state.messages
            .where((entry) => !entry.isLoading)
            .toList(growable: false),
        draftText: text,
        draftImages: draftImages,
      );
      return message;
    }
  }
}

final aiChatSessionProvider =
    StateNotifierProvider.family<
      AiChatSessionController,
      AiChatSessionState,
      String
    >((ref, noteId) {
      return AiChatSessionController(ref, noteId);
    });
