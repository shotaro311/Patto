import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/note.dart';
import '../../domain/app_settings.dart';
import '../../services/ai_service.dart';
import '../../services/clipboard_media_service.dart';
import '../../data/repositories/tag_dictionary_repository.dart';
import '../providers/attachment_repository_provider.dart';
import '../providers/ai_providers.dart';
import '../providers/app_settings_controller.dart';
import '../providers/note_repository_provider.dart';
import '../providers/notes_providers.dart';
import '../providers/quick_launch_provider.dart';
import '../providers/tag_dictionary_repository_provider.dart';
import '../widgets/app_input_decoration.dart';
import 'external_paste_guard.dart';
import '../widgets/animated_dots_text.dart';
import '../widgets/ai_prompt_presets_hover_menu.dart';
import '../widgets/ai_title_rules_hover_menu.dart';
import '../widgets/reorderable_icon_toolbar.dart';
import '../widgets/top_right_toast.dart';
import '../widgets/inline_attachment_controller.dart';
import '../widgets/inline_attachment_view.dart';

class NoteEditorPane extends ConsumerStatefulWidget {
  const NoteEditorPane({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorPane> createState() => _NoteEditorPaneState();
}

class _NoteEditorPaneState extends ConsumerState<NoteEditorPane> {
  static const EdgeInsets _editorContentPadding = EdgeInsets.all(12);
  static const double _minEditorPaneWidth = 320;
  static const double _minAiChatPaneWidth = 360;
  static const double _maxAiChatPaneWidth = 720;
  static final RegExp _symbolPattern = RegExp(r'[\p{P}\p{S}]', unicode: true);
  static final RegExp _hashTagPattern = RegExp(
    r'(?<!\w)#([\p{L}\p{N}_-]+)',
    unicode: true,
  );
  static final RegExp _wikiLinkPattern = RegExp(r'\[\[([^\]]+)\]\]');
  static final RegExp _urlPattern = RegExp(r'https?://[^\s)>\"]+');
  final _focusNode = FocusNode();
  final _titleFocusNode = FocusNode();
  late final InlineAttachmentEditingController _controller;
  late final TextEditingController _titleController;
  late final TextEditingController _aiChatController;
  late final ExternalPasteGuard _externalPasteGuard;
  final _aiChatFocusNode = FocusNode();
  final _aiChatScrollController = ScrollController();
  final _clipboardMediaService = const ClipboardMediaService();
  ProviderSubscription<int>? _quickLaunchSub;
  ProviderSubscription<int>? _externalPasteSub;

  Timer? _debounce;
  Timer? _titleDebounce;
  bool _pendingFocus = true;
  String _lastLoaded = '';
  String _lastTitleLoaded = '';
  List<String> _lastSavedLinksOut = const <String>[];
  List<String> _aiSuggestedTags = const <String>[];
  bool _aiTagSuggesting = false;
  int _aiTagSuggestToken = 0;
  bool _editingTitle = false;
  String? _lastDuplicateTitle;
  bool _aiBusy = false;
  bool _titleAiBusy = false;
  bool _inlineBusy = false;
  int _inlineToken = 0;
  int _titleAiToken = 0;
  int? _runningPresetIndex;
  AiEditScope _promptScope = AiEditScope.full;
  String _lastScopeKey = '';
  bool _aiImageContextEnabled = false;
  bool _isDragOver = false;
  bool _isChatDragOver = false;
  Note? _attachmentNote;
  double _editorWidth = 0;
  bool _aiChatOpen = false;
  bool _aiChatBusy = false;
  bool _isResizingAiChat = false;
  double _aiChatPreferredWidth = 520;
  int _aiChatToken = 0;
  int _selectedChatSystemPromptIndex = 0;
  List<_AiChatMessage> _aiChatMessages = const [];
  List<_AiChatDraftImage> _aiChatDraftImages = const [];

  int _countText(String text, bool excludeSymbols) {
    if (!excludeSymbols) return text.runes.length;
    var count = 0;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      if (_symbolPattern.hasMatch(ch)) continue;
      count++;
    }
    return count;
  }

  AiEditScope _autoScopeForSelection(TextSelection selection) {
    final hasSelection = selection.isValid && !selection.isCollapsed;
    return hasSelection ? AiEditScope.selection : AiEditScope.full;
  }

  void _syncPromptScope(TextSelection selection) {
    final key =
        '${selection.baseOffset}-${selection.extentOffset}-${selection.isCollapsed}';
    if (key == _lastScopeKey) return;
    _lastScopeKey = key;
    _promptScope = _autoScopeForSelection(selection);
  }

  AiEditTarget? _buildTargetForScope(AiEditScope scope) {
    final selection = _controller.selection;
    final currentText = _controller.text;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final baseOffset = selection.baseOffset >= 0
        ? selection.baseOffset
        : currentText.length;
    final extentOffset = selection.extentOffset >= 0
        ? selection.extentOffset
        : currentText.length;
    final start = hasSelection
        ? (baseOffset < extentOffset ? baseOffset : extentOffset)
        : baseOffset;
    final end = hasSelection
        ? (baseOffset < extentOffset ? extentOffset : baseOffset)
        : extentOffset;

    if (scope == AiEditScope.selection && !hasSelection) {
      showTopRightToast(context, '選択範囲がありません。');
      return null;
    }

    switch (scope) {
      case AiEditScope.full:
        return AiEditTarget(
          originalText: currentText,
          selectionStart: 0,
          selectionEnd: currentText.length,
          cursorOffset: baseOffset,
          hasSelection: true,
        );
      case AiEditScope.selection:
        return AiEditTarget(
          originalText: currentText.substring(start, end),
          selectionStart: start,
          selectionEnd: end,
          cursorOffset: baseOffset,
          hasSelection: true,
        );
      case AiEditScope.cursor:
        return AiEditTarget(
          originalText: '',
          selectionStart: baseOffset,
          selectionEnd: baseOffset,
          cursorOffset: baseOffset,
          hasSelection: false,
        );
    }
  }

  Future<void> _runInlineAiEdit(
    Note note,
    AiPromptPreset preset,
    int index,
  ) async {
    if (_inlineBusy) return;
    final target = _buildTargetForScope(_promptScope);
    if (target == null) return;

    final token = ++_inlineToken;
    setState(() {
      _inlineBusy = true;
      _runningPresetIndex = index;
    });

    try {
      final settings = ref.read(appSettingsProvider);
      final ai = ref.read(aiServiceProvider);
      final images = await _collectAiImages(note);
      final result = await ai.editTextWithImages(
        instruction: preset.prompt,
        originalText: target.originalText,
        images: images,
        useAppleIntelligence: settings.aiAppleIntelligenceEnabled,
        useExternalApi: settings.aiExternalApiEnabled,
      );
      if (!mounted || token != _inlineToken) return;
      _applyAiResult(target, result);
    } catch (_) {
      if (!mounted || token != _inlineToken) return;
      showTopRightToast(context, 'AI編集に失敗しました。');
    } finally {
      if (mounted && token == _inlineToken) {
        setState(() {
          _inlineBusy = false;
          _runningPresetIndex = null;
        });
      }
    }
  }

  void _cancelInlineAiEdit() {
    _inlineToken++;
    if (!mounted) return;
    setState(() {
      _inlineBusy = false;
      _runningPresetIndex = null;
    });
  }

  void _requestEditorFocus({Duration delay = Duration.zero}) {
    Future<void>.delayed(delay, () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_focusNode);
      });
    });
  }

  void _markFocusPending({Duration delay = Duration.zero}) {
    _pendingFocus = true;
    _requestEditorFocus(delay: delay);
  }

  @override
  void initState() {
    super.initState();
    _controller = InlineAttachmentEditingController(
      attachmentBuilder: (context, attachment, token) {
        final note = _attachmentNote;
        return _buildInlineAttachment(context, note, attachment, token);
      },
    );
    _titleController = TextEditingController();
    _aiChatController = TextEditingController();
    _externalPasteGuard = ExternalPasteGuard(
      controller: _controller,
      focusNode: _focusNode,
    );
    _controller.addListener(_onTextChanged);

    _quickLaunchSub = ref.listenManual<int>(quickLaunchEventProvider, (
      previous,
      next,
    ) {
      _markFocusPending(delay: const Duration(milliseconds: 80));
    });

    _externalPasteSub = ref.listenManual<int>(externalPasteEventProvider, (
      previous,
      next,
    ) {
      final content = ref.read(externalPasteContentProvider);
      if (content == null || content.isEmpty) return;
      _externalPasteGuard.queueExternalPaste(content, _scheduleSave);
    });

    _markFocusPending();
  }

  void _onTextChanged() {
    _externalPasteGuard.onTextChanged();
  }

  @override
  void didUpdateWidget(covariant NoteEditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) {
      _titleDebounce?.cancel();
      _lastLoaded = '';
      _lastTitleLoaded = '';
      _lastSavedLinksOut = const <String>[];
      _aiSuggestedTags = const <String>[];
      _aiTagSuggesting = false;
      _aiTagSuggestToken++;
      _controller.text = '';
      _titleController.text = '';
      _editingTitle = false;
      _lastDuplicateTitle = null;
      _aiChatController.clear();
      _aiChatMessages = const [];
      _aiChatDraftImages = const [];
      _aiChatOpen = false;
      _aiChatBusy = false;
      _selectedChatSystemPromptIndex = 0;
      _markFocusPending();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleDebounce?.cancel();
    _externalPasteGuard.dispose();
    _quickLaunchSub?.close();
    _externalPasteSub?.close();
    _controller.dispose();
    _titleController.dispose();
    _aiChatController.dispose();
    _titleFocusNode.dispose();
    _aiChatFocusNode.dispose();
    _aiChatScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    if (_aiSuggestedTags.isNotEmpty) {
      setState(() => _aiSuggestedTags = const <String>[]);
    }
    _debounce?.cancel();
    final linksOut = _extractLinksOut(_controller.text);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final repo = ref.read(noteRepositoryProvider);
      await repo.updateContent(widget.noteId, _controller.text);
      if (!listEquals(_lastSavedLinksOut, linksOut)) {
        await repo.setLinksOut(widget.noteId, linksOut);
        _lastSavedLinksOut = linksOut;
      }
    });
  }

  List<String> _extractLinksOut(String text) {
    final result = <String>[];
    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      if (result.contains(trimmed)) return;
      result.add(trimmed);
    }

    for (final m in _wikiLinkPattern.allMatches(text)) {
      final v = m.group(1);
      if (v != null) add(v);
    }
    for (final m in _urlPattern.allMatches(text)) {
      final v = m.group(0);
      if (v != null) add(v);
    }
    return result;
  }

  List<String> _suggestTags(Note note, String text) {
    final existing = <String>{
      for (final t in note.manualTags) _normalizeTag(t),
      for (final t in note.autoTags) _normalizeTag(t),
    };

    final result = <String>[];
    for (final m in _hashTagPattern.allMatches(text)) {
      final raw = m.group(1);
      if (raw == null) continue;
      final normalized = _normalizeTag(raw);
      if (normalized.isEmpty) continue;
      if (existing.contains(normalized)) continue;
      if (result.contains(normalized)) continue;
      result.add(normalized);
      if (result.length >= 10) break;
    }
    return result;
  }

  String _normalizeTag(String value) {
    return TagDictionaryRepository.normalizeTag(value);
  }

  Future<void> _addManualTag(Note note) async {
    if (!mounted) return;
    var input = '';
    final tag = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('タグを追加'),
          content: TextField(
            autofocus: true,
            decoration: appInputDecoration(hintText: '例: todo'),
            textInputAction: TextInputAction.done,
            onChanged: (value) => input = value,
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, input),
              child: const Text('追加'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (tag == null) return;
    final tagRepo = ref.read(tagDictionaryRepositoryProvider);
    final canonical = await tagRepo.resolveToCanonical(tag);
    if (canonical.isEmpty) return;
    if (!mounted) return;
    final existing = await tagRepo.resolveAll(note.manualTags);
    final next = <String>{...existing, canonical}.toList()..sort();
    final repo = ref.read(noteRepositoryProvider);
    await repo.setManualTags(note.uuid, next);
    await tagRepo.recordUsage(canonical);
  }

  Future<void> _removeManualTag(Note note, String tag) async {
    final tagRepo = ref.read(tagDictionaryRepositoryProvider);
    final target = await tagRepo.resolveToCanonical(tag);
    final existing = await tagRepo.resolveAll(note.manualTags);
    final next = existing.where((t) => t != target).toList()..sort();
    final repo = ref.read(noteRepositoryProvider);
    await repo.setManualTags(note.uuid, next);
  }

  Future<void> _applyAutoTag(Note note, String tag) async {
    final tagRepo = ref.read(tagDictionaryRepositoryProvider);
    final canonical = await tagRepo.resolveToCanonical(tag);
    if (canonical.isEmpty) return;
    final existing = await tagRepo.resolveAll(note.autoTags);
    final next = <String>{...existing, canonical}.toList()..sort();
    final repo = ref.read(noteRepositoryProvider);
    await repo.setAutoTags(note.uuid, next);
    await tagRepo.recordUsage(canonical);
    if (!mounted) return;
    setState(() {
      _aiSuggestedTags = _aiSuggestedTags
          .where((t) => _normalizeTag(t) != canonical)
          .toList();
    });
  }

  Future<void> _removeAutoTag(Note note, String tag) async {
    final tagRepo = ref.read(tagDictionaryRepositoryProvider);
    final target = await tagRepo.resolveToCanonical(tag);
    final existing = await tagRepo.resolveAll(note.autoTags);
    final next = existing.where((t) => t != target).toList()..sort();
    final repo = ref.read(noteRepositoryProvider);
    await repo.setAutoTags(note.uuid, next);
  }

  Future<void> _runAiTagSuggest(Note note) async {
    if (_aiTagSuggesting) return;
    if (!mounted) return;

    final token = ++_aiTagSuggestToken;
    setState(() => _aiTagSuggesting = true);

    try {
      final settings = ref.read(appSettingsProvider);
      final ai = ref.read(aiServiceProvider);
      final tagRepo = ref.read(tagDictionaryRepositoryProvider);
      final existingCanonical = await tagRepo.resolveAll([
        ...note.manualTags,
        ...note.autoTags,
      ]);
      final dictionaryCandidates = await tagRepo.buildAiCandidates(
        text: _controller.text,
        existingTags: existingCanonical,
      );
      final tags = await ai.suggestTags(
        text: _controller.text,
        existingTags: existingCanonical,
        dictionaryTags: dictionaryCandidates,
        useAppleIntelligence: settings.aiAppleIntelligenceEnabled,
        useExternalApi: settings.aiExternalApiEnabled,
      );
      if (!mounted || token != _aiTagSuggestToken) return;
      final suggestions = <String>[];
      for (final tag in tags) {
        final canonical = await tagRepo.resolveToCanonical(tag);
        if (canonical.isEmpty) continue;
        if (existingCanonical.contains(canonical)) continue;
        if (suggestions.contains(canonical)) continue;
        suggestions.add(canonical);
        if (suggestions.length >= 5) break;
      }
      if (!mounted || token != _aiTagSuggestToken) return;
      setState(() => _aiSuggestedTags = suggestions);
    } catch (_) {
      if (!mounted || token != _aiTagSuggestToken) return;
      showTopRightToast(context, 'AI提案に失敗しました。');
    } finally {
      if (mounted && token == _aiTagSuggestToken) {
        setState(() => _aiTagSuggesting = false);
      }
    }
  }

  Future<void> _delete() async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.softDelete(widget.noteId);
    ref.read(selectedNoteIdProvider.notifier).state = null;
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _commitTitle(Note note) async {
    await _saveTitle(note, exitOnSuccess: true);
  }

  void _scheduleTitleSave(Note note) {
    _titleDebounce?.cancel();
    _titleDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _saveTitle(note, exitOnSuccess: false);
    });
  }

  Future<bool> _saveTitle(Note note, {required bool exitOnSuccess}) async {
    final next = _titleController.text.trim();
    final current = note.title.trim();
    if (next == current) {
      if (exitOnSuccess && mounted) setState(() => _editingTitle = false);
      return true;
    }

    if (next.isNotEmpty) {
      final repo = ref.read(noteRepositoryProvider);
      final duplicated = await repo.isTitleDuplicate(
        title: next,
        excludeId: note.uuid,
      );
      if (duplicated) {
        if (mounted && _lastDuplicateTitle != next) {
          _lastDuplicateTitle = next;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('同じタイトルのメモが既にあります')));
        }
        if (exitOnSuccess && mounted) {
          FocusScope.of(context).requestFocus(_titleFocusNode);
        }
        return false;
      }
    }

    _lastDuplicateTitle = null;
    final repo = ref.read(noteRepositoryProvider);
    await repo.updateTitle(note.uuid, next);
    if (exitOnSuccess && mounted) setState(() => _editingTitle = false);
    return true;
  }

  Future<void> _generateTitleWithRule(Note note, AiTitleRule rule) async {
    if (_titleAiBusy) return;

    final content = _controller.text.trim();
    if (content.isEmpty) {
      showTopRightToast(context, '本文が空のためタイトルを生成できません。');
      return;
    }

    final settings = ref.read(appSettingsProvider);
    if (!settings.aiEnabled) {
      showTopRightToast(context, 'AIを設定で有効化してください。');
      return;
    }

    final token = ++_titleAiToken;
    final previousTitle = note.title;
    setState(() => _titleAiBusy = true);

    try {
      final ai = ref.read(aiServiceProvider);
      final generated = await ai.generateTitle(
        content: content,
        rulePrompt: rule.prompt,
        useAppleIntelligence: settings.aiAppleIntelligenceEnabled,
        useExternalApi: settings.aiExternalApiEnabled,
      );
      if (!mounted || token != _titleAiToken) return;

      _titleController.text = generated;
      final saved = await _saveTitle(note, exitOnSuccess: false);
      if (!mounted || token != _titleAiToken) return;

      if (!saved) {
        _titleController.text = previousTitle;
        return;
      }
      showTopRightToast(context, 'タイトルを生成しました。');
    } catch (e) {
      if (!mounted || token != _titleAiToken) return;
      final message = e is AiException ? e.message : 'タイトル生成に失敗しました。';
      showTopRightToast(context, message);
      _titleController.text = previousTitle;
    } finally {
      if (mounted && token == _titleAiToken) {
        setState(() => _titleAiBusy = false);
      }
    }
  }

  Future<void> _openAiEditDialog({
    required Note note,
    AiPromptPreset? preset,
    bool fromContextMenu = false,
    AiEditScope? scopeOverride,
    NoteAttachment? imageOverride,
  }) async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.aiEnabled) return;

    final selection = _controller.selection;
    final currentText = _controller.text;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final baseOffset = selection.baseOffset >= 0
        ? selection.baseOffset
        : currentText.length;
    final extentOffset = selection.extentOffset >= 0
        ? selection.extentOffset
        : currentText.length;
    final start = hasSelection
        ? (baseOffset < extentOffset ? baseOffset : extentOffset)
        : baseOffset;
    final end = hasSelection
        ? (baseOffset < extentOffset ? extentOffset : baseOffset)
        : extentOffset;
    final isFullSelection =
        hasSelection &&
        start == 0 &&
        end == currentText.length &&
        fromContextMenu;
    final autoScope = preset != null
        ? (hasSelection
              ? (isFullSelection ? AiEditScope.full : AiEditScope.selection)
              : AiEditScope.full)
        : (hasSelection
              ? (isFullSelection ? AiEditScope.full : AiEditScope.selection)
              : AiEditScope.full);
    final scope = scopeOverride ?? autoScope;
    if (scope == AiEditScope.selection && !hasSelection) {
      showTopRightToast(context, '選択範囲がありません。');
      return;
    }

    final useFullText = scope == AiEditScope.full;
    final treatAsSelection = scope != AiEditScope.cursor;
    final targetText = useFullText
        ? currentText
        : (hasSelection ? currentText.substring(start, end) : '');
    final targetLabel = switch (scope) {
      AiEditScope.full => '全文',
      AiEditScope.selection => '選択範囲',
      AiEditScope.cursor => 'カーソル位置',
    };
    final selectionStart = useFullText ? 0 : start;
    final selectionEnd = useFullText ? currentText.length : end;
    final target = AiEditTarget(
      originalText: targetText,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
      cursorOffset: baseOffset,
      hasSelection: treatAsSelection,
    );

    final images = await _collectAiImages(
      note,
      overrideAttachment: imageOverride,
    );
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiEditDialog(
        targetText: target.originalText,
        targetLabel: targetLabel,
        images: images,
        previewEnabled: settings.aiPreviewEnabled,
        sendKey: settings.aiPromptSendKey,
        initialPrompt: preset?.prompt,
        autoRun: preset != null,
        onBusyChanged: (busy) {
          if (!mounted) return;
          setState(() => _aiBusy = busy);
        },
      ),
    );
    if (result == null) return;
    _applyAiResult(target, result);
  }

  void _applyAiResult(AiEditTarget target, String result) {
    final current = _controller.text;
    if (target.hasSelection) {
      final start = target.selectionStart.clamp(0, current.length);
      final end = target.selectionEnd.clamp(0, current.length);
      final next = current.replaceRange(start, end, result);
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: start + result.length),
      );
    } else {
      final insertAt = target.cursorOffset.clamp(0, current.length);
      final next = current.replaceRange(insertAt, insertAt, result);
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: insertAt + result.length),
      );
    }
    _scheduleSave();
  }

  List<_AiChatPromptOption> _chatPromptOptions(AppSettings settings) {
    final options = <_AiChatPromptOption>[];
    for (var i = 0; i < settings.aiChatSystemPrompts.length; i++) {
      final prompt = settings.aiChatSystemPrompts[i];
      if (prompt.isEmpty) continue;
      options.add(_AiChatPromptOption(index: i, definition: prompt));
    }
    if (options.isEmpty) {
      options.add(
        const _AiChatPromptOption(
          index: 0,
          definition: AiChatSystemPrompt(
            name: '標準',
            prompt:
                'あなたはメモ編集を支援するAIチャットです。ユーザーの指示に沿って、編集案・追記案・改善案を日本語で簡潔に返してください。',
          ),
        ),
      );
    }
    return options;
  }

  _AiChatPromptOption _selectedChatPrompt(AppSettings settings) {
    final options = _chatPromptOptions(settings);
    for (final option in options) {
      if (option.index == _selectedChatSystemPromptIndex) {
        return option;
      }
    }
    return options.first;
  }

  void _openAiChat() {
    if (!_aiChatOpen && mounted) {
      setState(() => _aiChatOpen = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_aiChatFocusNode);
      _scrollAiChatToBottom(jump: true);
    });
  }

  void _closeAiChat() {
    if (!mounted) return;
    setState(() {
      _aiChatOpen = false;
      _isChatDragOver = false;
      _isResizingAiChat = false;
    });
  }

  double _resolveAiChatWidth(double availableWidth) {
    if (!_aiChatOpen) return 0;
    if (availableWidth < 720) return availableWidth;
    final maxWidth = (availableWidth - _minEditorPaneWidth).clamp(
      _minAiChatPaneWidth,
      _maxAiChatPaneWidth,
    );
    return _aiChatPreferredWidth.clamp(_minAiChatPaneWidth, maxWidth);
  }

  void _resizeAiChat(double delta, double availableWidth) {
    if (availableWidth < 720) return;
    final next = (_aiChatPreferredWidth - delta).clamp(
      _minAiChatPaneWidth,
      (availableWidth - _minEditorPaneWidth).clamp(
        _minAiChatPaneWidth,
        _maxAiChatPaneWidth,
      ),
    );
    setState(() => _aiChatPreferredWidth = next);
  }

  void _scrollAiChatToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_aiChatScrollController.hasClients) return;
      final position = _aiChatScrollController.position.maxScrollExtent;
      if (jump) {
        _aiChatScrollController.jumpTo(position);
        return;
      }
      _aiChatScrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _applyAiChatReplace(String text) {
    final next = text.trim();
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _scheduleSave();
    showTopRightToast(context, '本文を置き換えました。');
    _requestEditorFocus(delay: const Duration(milliseconds: 60));
  }

  void _applyAiChatAppend(String text) {
    final addition = text.trim();
    if (addition.isEmpty) return;
    final current = _controller.text;
    final separator = current.trim().isEmpty
        ? ''
        : (current.endsWith('\n') ? '\n' : '\n\n');
    final next = '$current$separator$addition';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _scheduleSave();
    showTopRightToast(context, '本文の末尾に追加しました。');
    _requestEditorFocus(delay: const Duration(milliseconds: 60));
  }

  Future<void> _handleAiChatPaste() async {
    final imageBytes = await _clipboardMediaService.readImagePng();
    if (imageBytes != null && imageBytes.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _aiChatDraftImages = [
          ..._aiChatDraftImages,
          _AiChatDraftImage(
            bytes: imageBytes,
            mimeType: 'image/png',
            label: 'クリップボード画像',
          ),
        ];
      });
      showTopRightToast(context, '画像を追加しました。');
      return;
    }

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final value = _aiChatController.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = selection.start.clamp(0, value.text.length);
    final end = selection.end.clamp(0, value.text.length);
    final nextText = value.text.replaceRange(start, end, text);
    _aiChatController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  KeyEventResult _handleAiChatComposerKey(
    FocusNode node,
    KeyEvent event,
    Note note,
    AppSettings settings,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isPasteKey =
        key == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed);
    if (isPasteKey) {
      unawaited(_handleAiChatPaste());
      return KeyEventResult.handled;
    }

    final isSubmitKey =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (isSubmitKey && HardwareKeyboard.instance.isControlPressed) {
      unawaited(_sendAiChat(note, settings));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String _mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'image/webp';
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index < 0) return normalized;
    return normalized.substring(index + 1);
  }

  Future<_AiChatDraftImage?> _loadChatDraftImageFromPath(
    String path, {
    Uint8List? bookmark,
  }) async {
    if (!_isSupportedImagePath(path)) return null;
    final file = File(path);
    if (!await file.exists()) return null;

    var accessGranted = false;
    if (bookmark != null && bookmark.isNotEmpty) {
      accessGranted = await DesktopDrop.instance
          .startAccessingSecurityScopedResource(bookmark: bookmark);
    }
    try {
      final bytes = await file.readAsBytes();
      return _AiChatDraftImage(
        bytes: bytes,
        mimeType: _mimeTypeFromPath(path),
        label: _basename(path),
      );
    } finally {
      if (bookmark != null && bookmark.isNotEmpty && accessGranted) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(
          bookmark: bookmark,
        );
      }
    }
  }

  Future<void> _handleChatDrop(List<DropItem> items) async {
    final added = <_AiChatDraftImage>[];
    var unsupported = 0;
    for (final item in items) {
      if (item is DropItemDirectory) continue;
      final image = await _loadChatDraftImageFromPath(
        item.path,
        bookmark: item.extraAppleBookmark,
      );
      if (image == null) {
        unsupported++;
        continue;
      }
      added.add(image);
    }
    if (!mounted) return;
    if (added.isNotEmpty) {
      setState(() => _aiChatDraftImages = [..._aiChatDraftImages, ...added]);
      showTopRightToast(context, '画像を追加しました。');
    } else if (unsupported > 0) {
      showTopRightToast(context, '対応形式は png / jpeg / webp です。');
    }
  }

  Future<void> _sendAiChat(Note note, AppSettings settings) async {
    if (_aiChatBusy) return;
    final text = _aiChatController.text.trim();
    final draftImages = List<_AiChatDraftImage>.from(_aiChatDraftImages);
    if (text.isEmpty && draftImages.isEmpty) return;

    final selectedPrompt = _selectedChatPrompt(settings);
    final userMessage = _AiChatMessage(
      role: AiChatRole.user,
      text: text,
      images: draftImages,
    );
    final token = ++_aiChatToken;

    setState(() {
      _aiChatBusy = true;
      _aiChatController.clear();
      _aiChatDraftImages = const [];
      _aiChatOpen = true;
      _aiChatMessages = [
        ..._aiChatMessages,
        userMessage,
        const _AiChatMessage(
          role: AiChatRole.assistant,
          text: '',
          isLoading: true,
        ),
      ];
    });
    _scrollAiChatToBottom();

    try {
      final noteImages = await _collectAiImages(note);
      final history = [
        ..._aiChatMessages.map((message) => message.toInput()),
        userMessage.toInput(),
      ];
      final ai = ref.read(aiServiceProvider);
      final response = await ai.chatWithNote(
        noteTitle: _titleController.text,
        noteContent: _controller.text,
        noteImages: noteImages,
        history: history,
        systemPrompt: selectedPrompt.definition.prompt,
        useAppleIntelligence: settings.aiAppleIntelligenceEnabled,
        useExternalApi: settings.aiExternalApiEnabled,
      );
      if (!mounted || token != _aiChatToken) return;
      setState(() {
        final nextMessages = List<_AiChatMessage>.from(_aiChatMessages);
        final loadingIndex = nextMessages.lastIndexWhere(
          (message) =>
              message.role == AiChatRole.assistant && message.isLoading,
        );
        if (loadingIndex >= 0) {
          nextMessages[loadingIndex] = _AiChatMessage(
            role: AiChatRole.assistant,
            text: response,
          );
        } else {
          nextMessages.add(
            _AiChatMessage(role: AiChatRole.assistant, text: response),
          );
        }
        _aiChatMessages = nextMessages;
        _aiChatBusy = false;
      });
      _scrollAiChatToBottom();
    } catch (e) {
      if (!mounted || token != _aiChatToken) return;
      final message = e is AiException ? e.message : 'AIチャットに失敗しました。';
      setState(() {
        _aiChatBusy = false;
        _aiChatMessages = _aiChatMessages
            .where((entry) => !entry.isLoading)
            .toList(growable: false);
        _aiChatController.text = text;
        _aiChatDraftImages = draftImages;
      });
      showTopRightToast(context, message);
      _openAiChat();
    }
  }

  bool _matchesAiShortcut(KeyEvent event, MacKeyBinding? binding) {
    if (binding == null || event is! KeyDownEvent) return false;
    final label = event.logicalKey.keyLabel.isNotEmpty
        ? event.logicalKey.keyLabel
        : (event.logicalKey.debugName ?? '');
    if (label.isEmpty) return false;
    if (label.toUpperCase() != binding.keyLabel.toUpperCase()) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (binding.command != keyboard.isMetaPressed) return false;
    if (binding.control != keyboard.isControlPressed) return false;
    if (binding.option != keyboard.isAltPressed) return false;
    if (binding.shift != keyboard.isShiftPressed) return false;
    return true;
  }

  bool _handleEnterKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.enter) return false;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isMetaPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed) {
      return false;
    }
    return _convertUrlBeforeEnter();
  }

  bool _isSupportedImagePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  bool _convertUrlBeforeEnter() {
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return false;
    final cursor = selection.baseOffset;
    if (cursor < 0) return false;

    final text = _controller.text;
    final lineStart = text.lastIndexOf('\n', cursor - 1);
    final lineOffset = lineStart < 0 ? 0 : lineStart + 1;
    final linePrefix = text.substring(lineOffset, cursor);
    Match? lastMatch;
    for (final m in _urlPattern.allMatches(linePrefix)) {
      lastMatch = m;
    }
    if (lastMatch == null || lastMatch.end != linePrefix.length) {
      return false;
    }

    final url = linePrefix.substring(lastMatch.start, lastMatch.end);
    final absoluteStart = lineOffset + lastMatch.start;
    final absoluteEnd = lineOffset + lastMatch.end;
    if (_isUrlAlreadyLinked(text, absoluteStart, absoluteEnd)) {
      return false;
    }

    final markdown = '[$url]($url)';
    final replaced = text.replaceRange(absoluteStart, absoluteEnd, markdown);
    final insertAt = absoluteStart + markdown.length;
    final next = replaced.replaceRange(insertAt, insertAt, '\n');
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: insertAt + 1),
    );
    _scheduleSave();
    return true;
  }

  bool _isUrlAlreadyLinked(String text, int start, int end) {
    if (start >= 2 && text.substring(start - 2, start) == '](') {
      return true;
    }
    if (start >= 1 &&
        end < text.length &&
        text[start - 1] == '<' &&
        text[end] == '>') {
      return true;
    }
    return false;
  }

  String? _extractUrlFromSelection(EditableTextState editableTextState) {
    final selection = editableTextState.textEditingValue.selection;
    final text = editableTextState.textEditingValue.text;
    if (!selection.isValid) return null;
    if (!selection.isCollapsed) {
      final selected = text.substring(selection.start, selection.end);
      final match = _urlPattern.firstMatch(selected);
      return match?.group(0);
    }
    final cursor = selection.baseOffset;
    if (cursor < 0) return null;
    for (final match in _urlPattern.allMatches(text)) {
      if (match.start <= cursor && cursor <= match.end) {
        return match.group(0);
      }
    }
    return null;
  }

  Future<void> _copyUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showTopRightToast(context, 'URLをコピーしました。');
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showTopRightToast(context, 'URLが不正です。');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showTopRightToast(context, 'ブラウザで開けませんでした。');
    }
  }

  Future<void> _addImageAttachment(Note note) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) {
      showTopRightToast(context, '画像の取得に失敗しました。');
      return;
    }
    final repo = ref.read(attachmentRepositoryProvider);
    final attachment = await repo.addImageAttachmentFromFile(
      noteId: note.uuid,
      file: File(path),
    );
    if (attachment == null && mounted) {
      showTopRightToast(context, '画像の追加に失敗しました。');
      return;
    }
    if (attachment != null && mounted) {
      showTopRightToast(context, '画像を添付しました。');
    }
  }

  Future<NoteAttachment?> _addImageAttachmentFromPath(
    Note note,
    String path, {
    Uint8List? bookmark,
  }) async {
    if (!_isSupportedImagePath(path)) return null;
    final file = File(path);
    if (!await file.exists()) return null;

    var accessGranted = false;
    if (bookmark != null && bookmark.isNotEmpty) {
      accessGranted = await DesktopDrop.instance
          .startAccessingSecurityScopedResource(bookmark: bookmark);
    }
    try {
      final repo = ref.read(attachmentRepositoryProvider);
      final attachment = await repo.addImageAttachmentFromFile(
        noteId: note.uuid,
        file: file,
      );
      return attachment;
    } finally {
      if (bookmark != null && bookmark.isNotEmpty && accessGranted) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(
          bookmark: bookmark,
        );
      }
    }
  }

  Future<void> _handleDrop(Note note, List<DropItem> items) async {
    var unsupported = 0;
    var added = 0;
    for (final item in items) {
      if (item is DropItemDirectory) continue;
      if (!_isSupportedImagePath(item.path)) {
        unsupported++;
        continue;
      }
      final attachment = await _addImageAttachmentFromPath(
        note,
        item.path,
        bookmark: item.extraAppleBookmark,
      );
      if (attachment != null) {
        added++;
      }
    }
    if (!mounted) return;
    if (added == 0 && unsupported > 0) {
      showTopRightToast(context, '対応形式は png / jpeg / webp です。');
    }
  }

  Future<List<AiImageInput>> _collectAiImages(
    Note note, {
    NoteAttachment? overrideAttachment,
  }) async {
    if (!_aiImageContextEnabled) return const [];
    final limit = ref.read(appSettingsProvider).aiImageSendLimit;
    if (limit <= 0) return const [];
    final source = overrideAttachment != null
        ? [overrideAttachment]
        : note.attachments;
    final targets = source.take(limit).toList();
    final images = <AiImageInput>[];
    for (final attachment in targets) {
      final path = attachment.localPath;
      if (path.isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final mime = attachment.mimeType.isNotEmpty
          ? attachment.mimeType
          : 'image/webp';
      images.add(AiImageInput(bytes: bytes, mimeType: mime));
    }
    return images;
  }

  Future<void> _showAttachmentMenu(
    Note note,
    NoteAttachment attachment,
    Offset position,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & overlay.size,
      ),
      items: const [PopupMenuItem(value: 'ai', child: Text('AI編集…'))],
    );
    if (!mounted || selected == null) return;
    if (selected == 'ai') {
      _openAiEditDialog(
        note: note,
        imageOverride: attachment,
        fromContextMenu: true,
      );
    }
  }

  Future<void> _showAttachmentDialog(Note initialNote) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Consumer(
              builder: (context, ref, _) {
                final noteAsync = ref.watch(noteByIdProvider(widget.noteId));
                final settings = ref.watch(appSettingsProvider);
                final note = noteAsync.valueOrNull ?? initialNote;
                final attachments = note.attachments;

                return AlertDialog(
                  title: const Text('添付画像'),
                  content: SizedBox(
                    width: 520,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('AIに画像を含める'),
                          subtitle: Text(
                            'AI送信時は最大${settings.aiImageSendLimit}枚まで',
                          ),
                          value: _aiImageContextEnabled,
                          onChanged: settings.aiImageSendLimit > 0
                              ? (value) {
                                  setState(
                                    () => _aiImageContextEnabled = value,
                                  );
                                  setDialogState(() {});
                                }
                              : null,
                        ),
                        const SizedBox(height: 8),
                        if (attachments.isEmpty)
                          Container(
                            height: 180,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('添付画像はありません'),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 360),
                            child: GridView.builder(
                              shrinkWrap: true,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1,
                                  ),
                              itemCount: attachments.length,
                              itemBuilder: (context, index) {
                                return _buildAttachmentPreviewCard(
                                  attachments[index],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('閉じる'),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        await _addImageAttachment(note);
                        if (!mounted) return;
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('画像を追加'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAttachmentPreviewCard(NoteAttachment attachment) {
    final file = File(attachment.localPath);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
      ),
    );
  }

  Widget _buildInlineAttachment(
    BuildContext context,
    Note? note,
    NoteAttachment attachment,
    InlineAttachmentToken token,
  ) {
    final maxWidth = _editorWidth > 0
        ? _editorWidth
        : MediaQuery.of(context).size.width - _editorContentPadding.horizontal;
    return InlineAttachmentView(
      key: ValueKey('attachment-${attachment.id}'),
      attachment: attachment,
      token: token,
      maxWidth: maxWidth,
      onResize: (target, size) {
        _controller.replaceAttachmentToken(
          target,
          width: size.width,
          height: size.height,
        );
        _scheduleSave();
      },
      onRequestCaret: (target, after) {
        FocusScope.of(context).requestFocus(_focusNode);
        _controller.setCaretAtTokenEdge(target, after: after);
      },
      onContextMenu: note == null
          ? null
          : (position) => _showAttachmentMenu(note, attachment, position),
    );
  }

  Widget _buildAiContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
    AppSettings settings,
    Note note,
  ) {
    final presets = settings.aiPromptPresets.where((preset) => !preset.isEmpty);
    final url = _extractUrlFromSelection(editableTextState);
    final items = <ContextMenuButtonItem>[
      if (url != null) ...[
        ContextMenuButtonItem(
          label: 'URLをコピー',
          onPressed: () {
            editableTextState.hideToolbar();
            _copyUrl(url);
          },
        ),
        ContextMenuButtonItem(
          label: 'ブラウザで表示',
          onPressed: () {
            editableTextState.hideToolbar();
            _openUrl(url);
          },
        ),
      ],
      ContextMenuButtonItem(
        label: 'AI編集…',
        onPressed: settings.aiEnabled
            ? () {
                editableTextState.hideToolbar();
                _openAiEditDialog(note: note, fromContextMenu: true);
              }
            : null,
      ),
      for (final preset in presets)
        ContextMenuButtonItem(
          label: preset.name,
          onPressed: settings.aiEnabled
              ? () {
                  editableTextState.hideToolbar();
                  _openAiEditDialog(
                    note: note,
                    preset: preset,
                    fromContextMenu: true,
                  );
                }
              : null,
        ),
      ...editableTextState.contextMenuButtonItems,
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  Widget _buildAiChatPanel(Note note, AppSettings settings) {
    final theme = Theme.of(context);
    final promptOptions = _chatPromptOptions(settings);
    final selectedPrompt = _selectedChatPrompt(settings);
    final hasNoteImages = _aiImageContextEnabled && note.attachments.isNotEmpty;
    final modelLabel = settings.aiExternalApiEnabled
        ? 'モデル: ${settings.aiExternalModel.trim().isEmpty ? '未設定' : settings.aiExternalModel.trim()}'
        : 'Apple Intelligence';

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              left: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 6),
                child: Row(
                  children: [
                    Text('AIチャット', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Tooltip(
                      message: 'システムプロンプト: ${selectedPrompt.definition.name}',
                      child: PopupMenuButton<int>(
                        icon: const Icon(Icons.tune_rounded),
                        onSelected: (value) {
                          setState(
                            () => _selectedChatSystemPromptIndex = value,
                          );
                        },
                        itemBuilder: (context) => [
                          for (final option in promptOptions)
                            PopupMenuItem(
                              value: option.index,
                              child: Text(option.definition.name),
                            ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: modelLabel,
                      child: IconButton(
                        onPressed: () => showTopRightToast(context, modelLabel),
                        icon: const Icon(Icons.memory_rounded),
                      ),
                    ),
                    if (hasNoteImages)
                      Tooltip(
                        message: '添付画像 ${note.attachments.length}枚を参照中',
                        child: IconButton(
                          onPressed: () => _showAttachmentDialog(note),
                          icon: const Icon(Icons.image_outlined),
                        ),
                      ),
                    if (_aiChatBusy)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    IconButton(
                      tooltip: '閉じる',
                      onPressed: _closeAiChat,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _aiChatMessages.isEmpty
                    ? Center(
                        child: Text(
                          'AIに相談したい内容を入力してください',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _aiChatScrollController,
                        padding: const EdgeInsets.all(12),
                        itemBuilder: (context, index) {
                          return _buildAiChatMessageCard(
                            _aiChatMessages[index],
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemCount: _aiChatMessages.length,
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Focus(
                  onKeyEvent: (node, event) =>
                      _handleAiChatComposerKey(node, event, note, settings),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_aiChatDraftImages.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final image in _aiChatDraftImages)
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      image.bytes,
                                      width: 68,
                                      height: 68,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: -8,
                                    right: -8,
                                    child: IconButton(
                                      visualDensity: VisualDensity.compact,
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.surface,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _aiChatDraftImages =
                                              _aiChatDraftImages
                                                  .where(
                                                    (draft) => draft != image,
                                                  )
                                                  .toList();
                                        });
                                      },
                                      icon: const Icon(Icons.close, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextField(
                        controller: _aiChatController,
                        focusNode: _aiChatFocusNode,
                        minLines: 2,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration:
                            appInputDecoration(
                              hintText: 'Ctrl+Enterで送信 / 画像はドラッグ&ドロップ・ペーストで追加',
                            ).copyWith(
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                14,
                              ),
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 52,
                                minHeight: 52,
                              ),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(
                                  right: 6,
                                  bottom: 6,
                                ),
                                child: Align(
                                  widthFactor: 1,
                                  heightFactor: 1,
                                  alignment: Alignment.bottomCenter,
                                  child: IconButton.filled(
                                    tooltip: '送信',
                                    onPressed: _aiChatBusy
                                        ? null
                                        : () => _sendAiChat(note, settings),
                                    icon: const Icon(Icons.send_rounded),
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isChatDragOver)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAiChatMessageCard(_AiChatMessage message) {
    final theme = Theme.of(context);
    final isUser = message.role == AiChatRole.user;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final backgroundColor = isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'あなた' : 'AI',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (message.images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final image in message.images)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            image.bytes,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                    ],
                  ),
                ],
                if (message.isLoading) ...[
                  const SizedBox(height: 8),
                  AnimatedDotsText(
                    text: 'AIが応答を作成中',
                    style: theme.textTheme.bodyMedium,
                  ),
                ] else if (message.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText(message.text),
                ],
                if (!isUser &&
                    !message.isLoading &&
                    message.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.outlined(
                        tooltip: '本文を置き換え',
                        onPressed: () => _applyAiChatReplace(message.text),
                        icon: const Icon(Icons.edit_note),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: '末尾に追加',
                        onPressed: () => _applyAiChatAppend(message.text),
                        icon: const Icon(Icons.post_add),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteByIdProvider(widget.noteId));
    final settings = ref.watch(appSettingsProvider);
    final canGoBack = Navigator.of(context).canPop();

    return noteAsync.when(
      data: (note) {
        if (note == null) return const Center(child: Text('メモが見つかりません'));
        if (_pendingFocus) {
          _pendingFocus = false;
          _requestEditorFocus();
        }

        final content = note.content;
        if (_lastLoaded != content && _controller.text == _lastLoaded) {
          _controller.text = content;
          _lastLoaded = content;
        } else if (_lastLoaded.isEmpty && _controller.text.isEmpty) {
          _controller.text = content;
          _lastLoaded = content;
        }

        final title = note.title.trim();
        final display = title.isEmpty ? 'タイトルを入力' : title;
        if (!_editingTitle &&
            (_lastTitleLoaded != note.title ||
                _titleController.text == _lastTitleLoaded)) {
          _titleController.text = note.title;
          _lastTitleLoaded = note.title;
        }

        final selection = _controller.selection;
        _syncPromptScope(selection);

        final existingTags = <String>{
          for (final t in note.manualTags) _normalizeTag(t),
          for (final t in note.autoTags) _normalizeTag(t),
        };
        final suggestions = <String>[];
        for (final t in [
          ..._suggestTags(note, _controller.text),
          ..._aiSuggestedTags,
        ]) {
          final normalized = _normalizeTag(t);
          if (normalized.isEmpty) continue;
          if (existingTags.contains(normalized)) continue;
          if (suggestions.contains(normalized)) continue;
          suggestions.add(normalized);
        }

        final hasTagBar =
            note.manualTags.isNotEmpty ||
            note.autoTags.isNotEmpty ||
            suggestions.isNotEmpty ||
            _aiTagSuggesting;

        _attachmentNote = note;
        _controller.setAttachments(note.attachments);

        final body = Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (canGoBack) ...[
                          IconButton(
                            tooltip: '戻る',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _editingTitle
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _editingTitle
                                      ? TextField(
                                          controller: _titleController,
                                          focusNode: _titleFocusNode,
                                          decoration: const InputDecoration(
                                            hintText: 'タイトルを入力',
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                          ),
                                          onChanged: (_) =>
                                              _scheduleTitleSave(note),
                                          textInputAction: TextInputAction.done,
                                          onEditingComplete: () =>
                                              _commitTitle(note),
                                          onSubmitted: (_) =>
                                              _commitTitle(note),
                                        )
                                      : InkWell(
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                          onTap: () {
                                            setState(
                                              () => _editingTitle = true,
                                            );
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  if (!mounted) return;
                                                  _titleController.selection =
                                                      TextSelection(
                                                        baseOffset: 0,
                                                        extentOffset:
                                                            _titleController
                                                                .text
                                                                .length,
                                                      );
                                                  FocusScope.of(
                                                    context,
                                                  ).requestFocus(
                                                    _titleFocusNode,
                                                  );
                                                });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                            child: Text(
                                              display,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    color: title.isEmpty
                                                        ? Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant
                                                        : null,
                                                  ),
                                            ),
                                          ),
                                        ),
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                                AiTitleRulesHoverMenu(
                                  rules: settings.aiTitleRules,
                                  enabled: settings.aiEnabled,
                                  busy: _titleAiBusy,
                                  onSelect: (rule, _) =>
                                      _generateTitleWithRule(note, rule),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ReorderableIconToolbar(
                          actions: [
                            ToolbarAction(
                              id: 'custom_prompts',
                              builder: (context) => AiPromptPresetsHoverMenu(
                                presets: settings.aiPromptPresets,
                                enabled: settings.aiEnabled,
                                runningIndex: _runningPresetIndex,
                                onCancelRunning: _cancelInlineAiEdit,
                                closeOnSelect: settings.aiPreviewEnabled,
                                keepOpenWhileRunning:
                                    !settings.aiPreviewEnabled,
                                onSelect: (preset, index) {
                                  if (!settings.aiEnabled) return;
                                  if (settings.aiPreviewEnabled) {
                                    _openAiEditDialog(
                                      note: note,
                                      preset: preset,
                                      scopeOverride: _promptScope,
                                    );
                                    return;
                                  }
                                  _runInlineAiEdit(note, preset, index);
                                },
                              ),
                            ),
                            ToolbarAction(
                              id: 'image_tools',
                              builder: (context) => Tooltip(
                                message: note.attachments.isEmpty
                                    ? '添付画像'
                                    : '添付画像（${note.attachments.length}枚）',
                                child: IconButton(
                                  onPressed: () => _showAttachmentDialog(note),
                                  icon: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(
                                        _aiImageContextEnabled
                                            ? Icons.add_photo_alternate
                                            : Icons
                                                  .add_photo_alternate_outlined,
                                      ),
                                      if (note.attachments.isNotEmpty)
                                        Positioned(
                                          right: -6,
                                          top: -4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              '${note.attachments.length}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                  ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ToolbarAction(
                              id: 'add_tag',
                              builder: (context) => IconButton(
                                tooltip: 'タグを追加',
                                onPressed: () => _addManualTag(note),
                                icon: const Icon(Icons.label_outline),
                              ),
                            ),
                            ToolbarAction(
                              id: 'ai_tag_suggest',
                              builder: (context) => Tooltip(
                                message: settings.aiEnabled
                                    ? 'AIでタグ提案'
                                    : 'AI編集は設定で有効化してください',
                                child: IconButton(
                                  onPressed:
                                      settings.aiEnabled && !_aiTagSuggesting
                                      ? () => _runAiTagSuggest(note)
                                      : null,
                                  icon: const Icon(Icons.auto_awesome),
                                ),
                              ),
                            ),
                            ToolbarAction(
                              id: 'ai_edit',
                              builder: (context) => Tooltip(
                                message: settings.aiEnabled
                                    ? 'AIチャット'
                                    : 'AIチャットは設定で有効化してください',
                                child: IconButton(
                                  onPressed: settings.aiEnabled
                                      ? _openAiChat
                                      : null,
                                  icon: const Icon(Icons.chat_bubble_outline),
                                ),
                              ),
                            ),
                            ToolbarAction(
                              id: 'settings',
                              builder: (context) => IconButton(
                                tooltip: '設定',
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed('/settings'),
                                icon: const Icon(Icons.settings_outlined),
                              ),
                            ),
                            ToolbarAction(
                              id: 'delete',
                              builder: (context) => IconButton(
                                tooltip: '削除',
                                onPressed: _delete,
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (hasTagBar) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (_aiTagSuggesting)
                            const Chip(label: Text('AI提案中…')),
                          for (final tag in note.manualTags)
                            InputChip(
                              label: Text('#${_normalizeTag(tag)}'),
                              onDeleted: () => _removeManualTag(note, tag),
                            ),
                          for (final tag in note.autoTags)
                            InputChip(
                              label: Text('#${_normalizeTag(tag)}'),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              onDeleted: () => _removeAutoTag(note, tag),
                            ),
                          for (final tag in suggestions)
                            ActionChip(
                              label: Text('提案: #$tag'),
                              onPressed: () => _applyAutoTag(note, tag),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isResizableLayout =
                      _aiChatOpen && constraints.maxWidth >= 720;
                  final chatWidth = _resolveAiChatWidth(constraints.maxWidth);
                  return Row(
                    children: [
                      Expanded(
                        child: DropTarget(
                          onDragEntered: (_) =>
                              setState(() => _isDragOver = true),
                          onDragExited: (_) =>
                              setState(() => _isDragOver = false),
                          onDragDone: (details) async {
                            setState(() => _isDragOver = false);
                            await _handleDrop(note, details.files);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Stack(
                              children: [
                                Focus(
                                  onKeyEvent: (node, event) {
                                    if (_handleEnterKey(event)) {
                                      return KeyEventResult.handled;
                                    }
                                    if (settings.aiEnabled &&
                                        _matchesAiShortcut(
                                          event,
                                          settings.aiEditKeyBinding,
                                        )) {
                                      _openAiChat();
                                      return KeyEventResult.handled;
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      _editorWidth =
                                          constraints.maxWidth -
                                          _editorContentPadding.horizontal;
                                      if (_editorWidth < 0) _editorWidth = 0;
                                      return TextField(
                                        controller: _controller,
                                        focusNode: _focusNode,
                                        maxLines: null,
                                        expands: true,
                                        textAlign: TextAlign.left,
                                        textAlignVertical:
                                            TextAlignVertical.top,
                                        decoration:
                                            appInputDecoration(
                                              hintText: 'メモを書く…',
                                            ).copyWith(
                                              contentPadding:
                                                  _editorContentPadding,
                                            ),
                                        onChanged: (_) => _scheduleSave(),
                                        contextMenuBuilder:
                                            (context, editableTextState) {
                                              return _buildAiContextMenu(
                                                context,
                                                editableTextState,
                                                settings,
                                                note,
                                              );
                                            },
                                      );
                                    },
                                  ),
                                ),
                                if (_aiBusy)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: AnimatedDotsText(
                                          text: '[AIが編集中',
                                          suffix: ']',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (settings.charCountEnabled)
                                  Positioned(
                                    right: 8,
                                    bottom: 6,
                                    child:
                                        ValueListenableBuilder<
                                          TextEditingValue
                                        >(
                                          valueListenable: _controller,
                                          builder: (context, value, _) {
                                            final count = _countText(
                                              value.text,
                                              settings.charCountExcludeSymbols,
                                            );
                                            final suffix =
                                                settings.charCountExcludeSymbols
                                                ? '（記号含まず）'
                                                : '';
                                            return Text(
                                              '$count$suffix',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            );
                                          },
                                        ),
                                  ),
                                if (_isDragOver)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.08),
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isResizableLayout)
                        MouseRegion(
                          cursor: SystemMouseCursors.resizeColumn,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (_) {
                              setState(() => _isResizingAiChat = true);
                            },
                            onHorizontalDragUpdate: (details) {
                              _resizeAiChat(
                                details.delta.dx,
                                constraints.maxWidth,
                              );
                            },
                            onHorizontalDragEnd: (_) {
                              if (!mounted) return;
                              setState(() => _isResizingAiChat = false);
                            },
                            onHorizontalDragCancel: () {
                              if (!mounted) return;
                              setState(() => _isResizingAiChat = false);
                            },
                            child: SizedBox(
                              width: 6,
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  width: 1.5,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color:
                                        (_isResizingAiChat
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.outlineVariant)
                                            .withValues(
                                              alpha: _isResizingAiChat
                                                  ? 0.9
                                                  : 0.75,
                                            ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: chatWidth,
                        child: _aiChatOpen
                            ? DropTarget(
                                onDragEntered: (_) =>
                                    setState(() => _isChatDragOver = true),
                                onDragExited: (_) =>
                                    setState(() => _isChatDragOver = false),
                                onDragDone: (details) async {
                                  setState(() => _isChatDragOver = false);
                                  await _handleChatDrop(details.files);
                                },
                                child: _buildAiChatPanel(note, settings),
                              )
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );

        return body;
      },
      error: (e, _) => Center(child: Text('エラー: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _AiChatPromptOption {
  const _AiChatPromptOption({required this.index, required this.definition});

  final int index;
  final AiChatSystemPrompt definition;
}

class _AiChatDraftImage {
  const _AiChatDraftImage({
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

class _AiChatMessage {
  const _AiChatMessage({
    required this.role,
    required this.text,
    this.images = const [],
    this.isLoading = false,
  });

  final AiChatRole role;
  final String text;
  final List<_AiChatDraftImage> images;
  final bool isLoading;

  AiChatMessageInput toInput() {
    return AiChatMessageInput(
      role: role,
      text: text,
      images: images.map((image) => image.toInput()).toList(growable: false),
    );
  }
}

class AiEditTarget {
  const AiEditTarget({
    required this.originalText,
    required this.selectionStart,
    required this.selectionEnd,
    required this.cursorOffset,
    required this.hasSelection,
  });

  final String originalText;
  final int selectionStart;
  final int selectionEnd;
  final int cursorOffset;
  final bool hasSelection;
}

class AiEditDialog extends ConsumerStatefulWidget {
  const AiEditDialog({
    super.key,
    required this.targetText,
    required this.targetLabel,
    required this.images,
    required this.previewEnabled,
    required this.sendKey,
    required this.initialPrompt,
    required this.autoRun,
    required this.onBusyChanged,
  });

  final String targetText;
  final String targetLabel;
  final List<AiImageInput> images;
  final bool previewEnabled;
  final AiPromptSendKey sendKey;
  final String? initialPrompt;
  final bool autoRun;
  final ValueChanged<bool> onBusyChanged;

  @override
  ConsumerState<AiEditDialog> createState() => _AiEditDialogState();
}

class _AiEditDialogState extends ConsumerState<AiEditDialog> {
  final _promptController = TextEditingController();
  final _promptFocusNode = FocusNode();
  String _currentResult = '';
  bool _hasResult = false;
  bool _running = false;
  int _runToken = 0;
  double _splitRatio = 0.5;
  _DiffResult? _diffResult;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) {
      _promptController.text = widget.initialPrompt!;
    }
    if (widget.autoRun && _promptController.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runPrompt());
    }
  }

  @override
  void dispose() {
    widget.onBusyChanged(false);
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  Future<void> _runPrompt() async {
    if (_running) return;
    final instruction = _promptController.text.trim();
    if (instruction.isEmpty) return;

    final token = ++_runToken;
    setState(() => _running = true);
    widget.onBusyChanged(true);

    String result;
    try {
      final settings = ref.read(appSettingsProvider);
      final ai = ref.read(aiServiceProvider);
      result = await ai.editTextWithImages(
        instruction: instruction,
        originalText: widget.targetText,
        images: widget.images,
        useAppleIntelligence: settings.aiAppleIntelligenceEnabled,
        useExternalApi: settings.aiExternalApiEnabled,
      );
    } catch (_) {
      if (!mounted || token != _runToken) return;
      showTopRightToast(context, 'AI編集に失敗しました。');
      return;
    } finally {
      if (mounted && token == _runToken) {
        setState(() => _running = false);
        widget.onBusyChanged(false);
      }
    }

    if (!mounted || token != _runToken) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty || trimmed == widget.targetText) {
      showTopRightToast(context, '空もしくは変更がありませんでした。');
      return;
    }

    if (!widget.previewEnabled) {
      Navigator.of(context).pop(trimmed);
      return;
    }

    setState(() {
      _currentResult = trimmed;
      _hasResult = true;
      _diffResult = _buildDiff(widget.targetText, trimmed);
    });
  }

  void _cancel() {
    _runToken++;
    widget.onBusyChanged(false);
    Navigator.of(context).pop();
  }

  void _apply() {
    Navigator.of(context).pop(_currentResult);
  }

  KeyEventResult _handleDialogKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        widget.previewEnabled &&
        _hasResult &&
        !_running &&
        !_promptFocusNode.hasFocus) {
      _apply();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handlePromptKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    if (widget.sendKey == AiPromptSendKey.ctrlEnter) {
      if (keyboard.isControlPressed) {
        _runPrompt();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _runPrompt();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final previewArea = widget.previewEnabled
        ? Expanded(
            child: Stack(
              children: [
                _buildPreviewContent(context),
                if (_running)
                  Center(
                    child: AnimatedDotsText(
                      text: '[AIが編集中',
                      suffix: ']',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          )
        : SizedBox(
            height: 120,
            child: Center(
              child: _running
                  ? AnimatedDotsText(
                      text: '[AIが編集中',
                      suffix: ']',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : const Text('実行すると本文に反映されます'),
            ),
          );

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('AI文章編集')),
          IconButton(
            tooltip: '閉じる',
            onPressed: _cancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: Focus(
        autofocus: true,
        onKeyEvent: _handleDialogKeyEvent,
        child: SizedBox(
          width: 760,
          height: widget.previewEnabled ? 560 : 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('対象: ${widget.targetLabel}'),
              const SizedBox(height: 8),
              const Text('注意: 対象テキストはAIへ送信されます。'),
              const SizedBox(height: 12),
              previewArea,
              const SizedBox(height: 12),
              Focus(
                onKeyEvent: _handlePromptKeyEvent,
                child: TextField(
                  focusNode: _promptFocusNode,
                  controller: _promptController,
                  decoration: appInputDecoration(labelText: '指示を入力'),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _running ? null : _runPrompt,
                  child: const Text('送信'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('キャンセル')),
        if (widget.previewEnabled)
          FilledButton(
            onPressed: _hasResult && !_running ? _apply : null,
            child: const Text('適用'),
          ),
      ],
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    if (!_hasResult) {
      return const SizedBox.shrink();
    }

    final diff = _diffResult ?? _buildDiff(widget.targetText, _currentResult);
    final leftStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final rightStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF00C853));

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final dividerWidth = 6.0;
        final leftWidth = (totalWidth * _splitRatio)
            .clamp(120.0, totalWidth - 120.0)
            .toDouble();
        final rightWidth = totalWidth - leftWidth - dividerWidth;
        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: _buildDiffPane(
                spans: _buildDiffSpans(
                  diff.original,
                  leftStyle,
                  Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ),
              ),
            ),
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                final next =
                    _splitRatio +
                    (details.delta.dx / (totalWidth - dividerWidth));
                setState(() => _splitRatio = next.clamp(0.2, 0.8));
              },
              child: Container(
                width: dividerWidth,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            SizedBox(
              width: rightWidth,
              child: _buildDiffPane(
                spans: _buildDiffSpans(
                  diff.modified,
                  rightStyle,
                  const Color(0xFF00C853).withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiffPane({required List<InlineSpan> spans}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: SelectableText.rich(TextSpan(children: spans)),
      ),
    );
  }

  List<InlineSpan> _buildDiffSpans(
    List<_DiffSegment> segments,
    TextStyle? baseStyle,
    Color highlightColor,
  ) {
    return [
      for (final segment in segments)
        TextSpan(
          text: segment.text,
          style: segment.changed
              ? baseStyle?.copyWith(backgroundColor: highlightColor)
              : baseStyle,
        ),
    ];
  }

  _DiffResult _buildDiff(String original, String modified) {
    final originalChars = original.runes
        .map((r) => String.fromCharCode(r))
        .toList();
    final modifiedChars = modified.runes
        .map((r) => String.fromCharCode(r))
        .toList();
    const maxCells = 20000;
    if (originalChars.length * modifiedChars.length > maxCells) {
      return _DiffResult(
        original: [_DiffSegment(original, true)],
        modified: [_DiffSegment(modified, true)],
      );
    }

    final rows = originalChars.length + 1;
    final cols = modifiedChars.length + 1;
    final dp = List.generate(rows, (_) => List<int>.filled(cols, 0));

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        if (originalChars[i - 1] == modifiedChars[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] >= dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }

    final ops = <_DiffOp>[];
    var i = originalChars.length;
    var j = modifiedChars.length;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && originalChars[i - 1] == modifiedChars[j - 1]) {
        ops.add(_DiffOp(_DiffOpType.equal, originalChars[i - 1]));
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        ops.add(_DiffOp(_DiffOpType.insert, modifiedChars[j - 1]));
        j--;
      } else if (i > 0) {
        ops.add(_DiffOp(_DiffOpType.delete, originalChars[i - 1]));
        i--;
      }
    }
    final orderedOps = ops.reversed.toList();

    final originalSegments = <_DiffSegment>[];
    final modifiedSegments = <_DiffSegment>[];

    void appendSegment(List<_DiffSegment> list, String text, bool changed) {
      if (text.isEmpty) return;
      if (list.isNotEmpty && list.last.changed == changed) {
        final last = list.removeLast();
        list.add(_DiffSegment('${last.text}$text', changed));
      } else {
        list.add(_DiffSegment(text, changed));
      }
    }

    for (final op in orderedOps) {
      switch (op.type) {
        case _DiffOpType.equal:
          appendSegment(originalSegments, op.text, false);
          appendSegment(modifiedSegments, op.text, false);
          break;
        case _DiffOpType.delete:
          appendSegment(originalSegments, op.text, true);
          break;
        case _DiffOpType.insert:
          appendSegment(modifiedSegments, op.text, true);
          break;
      }
    }

    return _DiffResult(original: originalSegments, modified: modifiedSegments);
  }
}

class _DiffResult {
  const _DiffResult({required this.original, required this.modified});

  final List<_DiffSegment> original;
  final List<_DiffSegment> modified;
}

class _DiffSegment {
  const _DiffSegment(this.text, this.changed);

  final String text;
  final bool changed;
}

enum _DiffOpType { equal, delete, insert }

class _DiffOp {
  const _DiffOp(this.type, this.text);

  final _DiffOpType type;
  final String text;
}
