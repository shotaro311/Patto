import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note.dart';
import '../../domain/app_settings.dart';
import '../providers/ai_providers.dart';
import '../providers/app_settings_controller.dart';
import '../providers/note_repository_provider.dart';
import '../providers/notes_providers.dart';
import '../providers/quick_launch_provider.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/animated_dots_text.dart';
import '../widgets/ai_prompt_presets_hover_menu.dart';
import '../widgets/top_right_toast.dart';

class NoteEditorPane extends ConsumerStatefulWidget {
  const NoteEditorPane({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorPane> createState() => _NoteEditorPaneState();
}

class _NoteEditorPaneState extends ConsumerState<NoteEditorPane> {
  static final RegExp _symbolPattern =
      RegExp(r'[\p{P}\p{S}]', unicode: true);
  static final RegExp _hashTagPattern =
      RegExp(r'(?<!\w)#([\p{L}\p{N}_-]+)', unicode: true);
  static final RegExp _wikiLinkPattern = RegExp(r'\[\[([^\]]+)\]\]');
  static final RegExp _urlPattern = RegExp(r'https?://[^\s)>\"]+');
  final _focusNode = FocusNode();
  final _titleFocusNode = FocusNode();
  late final TextEditingController _controller;
  late final TextEditingController _titleController;
  ProviderSubscription<int>? _quickLaunchSub;

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
    _controller = TextEditingController();
    _titleController = TextEditingController();

    _quickLaunchSub =
        ref.listenManual<int>(quickLaunchEventProvider, (previous, next) {
      _markFocusPending(delay: const Duration(milliseconds: 80));
    });

    _markFocusPending();
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
      _markFocusPending();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleDebounce?.cancel();
    _quickLaunchSub?.close();
    _controller.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
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
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.toLowerCase();
  }

  Future<void> _addManualTag(Note note) async {
    final controller = TextEditingController();
    try {
      final tag = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('タグを追加'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: appInputDecoration(hintText: '例: todo'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.of(context).pop(controller.text),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('追加'),
              ),
            ],
          );
        },
      );
      final normalized = _normalizeTag(tag ?? '');
      if (normalized.isEmpty) return;
      final next = <String>{
        for (final t in note.manualTags) _normalizeTag(t),
        normalized,
      }.toList()
        ..sort();
      final repo = ref.read(noteRepositoryProvider);
      await repo.setManualTags(note.uuid, next);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _removeManualTag(Note note, String tag) async {
    final target = _normalizeTag(tag);
    final next = note.manualTags.map(_normalizeTag).where((t) => t != target).toList()
      ..sort();
    final repo = ref.read(noteRepositoryProvider);
    await repo.setManualTags(note.uuid, next);
  }

  Future<void> _applyAutoTag(Note note, String tag) async {
    final normalized = _normalizeTag(tag);
    if (normalized.isEmpty) return;
    final next = <String>{
      for (final t in note.autoTags) _normalizeTag(t),
      normalized,
    }.toList()
      ..sort();
    final repo = ref.read(noteRepositoryProvider);
    await repo.setAutoTags(note.uuid, next);
  }

  Future<void> _removeAutoTag(Note note, String tag) async {
    final target = _normalizeTag(tag);
    final next = note.autoTags.map(_normalizeTag).where((t) => t != target).toList()
      ..sort();
    final repo = ref.read(noteRepositoryProvider);
    await repo.setAutoTags(note.uuid, next);
  }

  Future<void> _runAiTagSuggest(Note note) async {
    if (_aiTagSuggesting) return;
    if (!mounted) return;

    final token = ++_aiTagSuggestToken;
    setState(() => _aiTagSuggesting = true);

    try {
      final ai = ref.read(aiServiceProvider);
      final tags = await ai.suggestTags(
        text: _controller.text,
        existingTags: [
          ...note.manualTags,
          ...note.autoTags,
        ],
      );
      if (!mounted || token != _aiTagSuggestToken) return;
      setState(() => _aiSuggestedTags = tags);
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

  Future<void> _saveTitle(Note note, {required bool exitOnSuccess}) async {
    final next = _titleController.text.trim();
    final current = note.title.trim();
    if (next == current) {
      if (exitOnSuccess && mounted) setState(() => _editingTitle = false);
      return;
    }

    if (next.isNotEmpty) {
      final repo = ref.read(noteRepositoryProvider);
      final duplicated =
          await repo.isTitleDuplicate(title: next, excludeId: note.uuid);
      if (duplicated) {
        if (mounted && _lastDuplicateTitle != next) {
          _lastDuplicateTitle = next;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('同じタイトルのメモが既にあります')),
          );
        }
        if (exitOnSuccess && mounted) {
          FocusScope.of(context).requestFocus(_titleFocusNode);
        }
        return;
      }
    }

    _lastDuplicateTitle = null;
    final repo = ref.read(noteRepositoryProvider);
    await repo.updateTitle(note.uuid, next);
    if (exitOnSuccess && mounted) setState(() => _editingTitle = false);
  }

  Future<void> _openAiEditDialog({
    AiPromptPreset? preset,
    bool fromContextMenu = false,
  }) async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.aiEnabled) return;

    final selection = _controller.selection;
    final currentText = _controller.text;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final baseOffset = selection.baseOffset >= 0 ? selection.baseOffset : currentText.length;
    final extentOffset =
        selection.extentOffset >= 0 ? selection.extentOffset : currentText.length;
    final start = hasSelection
        ? (baseOffset < extentOffset ? baseOffset : extentOffset)
        : baseOffset;
    final end = hasSelection
        ? (baseOffset < extentOffset ? extentOffset : baseOffset)
        : extentOffset;
    final useFullTextForPreset = preset != null && !hasSelection;
    final isFullSelection = (hasSelection &&
            start == 0 &&
            end == currentText.length &&
            fromContextMenu) ||
        useFullTextForPreset;
    final targetText = useFullTextForPreset
        ? currentText
        : (hasSelection ? currentText.substring(start, end) : '');
    final targetLabel = isFullSelection
        ? '全文'
        : (hasSelection ? '選択範囲' : 'カーソル位置');
    final selectionStart = useFullTextForPreset ? 0 : start;
    final selectionEnd = useFullTextForPreset ? currentText.length : end;
    final treatAsSelection = hasSelection || useFullTextForPreset;
    final target = AiEditTarget(
      originalText: targetText,
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
      cursorOffset: baseOffset,
      hasSelection: treatAsSelection,
    );

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiEditDialog(
        targetText: target.originalText,
        targetLabel: targetLabel,
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

  Widget _buildAiContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
    AppSettings settings,
  ) {
    final presets = settings.aiPromptPresets.where((preset) => !preset.isEmpty);
    final items = <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        label: 'AI編集…',
        onPressed: settings.aiEnabled
            ? () {
                editableTextState.hideToolbar();
                  _openAiEditDialog(fromContextMenu: true);
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

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteByIdProvider(widget.noteId));
    final settings = ref.watch(appSettingsProvider);

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
        final display = title.isEmpty ? '（無題）' : title;
        if (!_editingTitle &&
            (_lastTitleLoaded != note.title ||
                _titleController.text == _lastTitleLoaded)) {
          _titleController.text = note.title;
          _lastTitleLoaded = note.title;
        }

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

        final hasTagBar = note.manualTags.isNotEmpty ||
            note.autoTags.isNotEmpty ||
            suggestions.isNotEmpty ||
            _aiTagSuggesting;

        return Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _editingTitle
                              ? TextField(
                                  controller: _titleController,
                                  focusNode: _titleFocusNode,
                                  decoration: appInputDecoration(
                                    hintText: 'タイトルを入力',
                                    isDense: true,
                                  ),
                                  onChanged: (_) => _scheduleTitleSave(note),
                                  textInputAction: TextInputAction.done,
                                  onEditingComplete: () => _commitTitle(note),
                                  onSubmitted: (_) => _commitTitle(note),
                                )
                              : GestureDetector(
                                  onTap: () {
                                    setState(() => _editingTitle = true);
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (!mounted) return;
                                      _titleController.selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset: _titleController.text.length,
                                      );
                                      FocusScope.of(context)
                                          .requestFocus(_titleFocusNode);
                                    });
                                  },
                                  child: Text(
                                    display,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                        ),
                        AiPromptPresetsHoverMenu(
                          presets: settings.aiPromptPresets,
                          enabled: settings.aiEnabled,
                          onSelect: (preset) => _openAiEditDialog(preset: preset),
                        ),
                        IconButton(
                          tooltip: 'タグを追加',
                          onPressed: () => _addManualTag(note),
                          icon: const Icon(Icons.label_outline),
                        ),
                        Tooltip(
                          message: settings.aiEnabled
                              ? 'AIでタグ提案'
                              : 'AI編集は設定で有効化してください',
                          child: IconButton(
                            onPressed: settings.aiEnabled && !_aiTagSuggesting
                                ? () => _runAiTagSuggest(note)
                                : null,
                            icon: const Icon(Icons.auto_awesome),
                          ),
                        ),
                        Tooltip(
                          message: settings.aiEnabled
                              ? 'AI編集'
                              : 'AI編集は設定で有効化してください',
                          child: IconButton(
                            onPressed: settings.aiEnabled
                                ? () => _openAiEditDialog()
                                : null,
                            icon: const Icon(Icons.auto_fix_high),
                          ),
                        ),
                        IconButton(
                          tooltip: '削除',
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline),
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
                            const Chip(
                              label: Text('AI提案中…'),
                            ),
                          for (final tag in note.manualTags)
                            InputChip(
                              label: Text('#${_normalizeTag(tag)}'),
                              onDeleted: () => _removeManualTag(note, tag),
                            ),
                          for (final tag in note.autoTags)
                            InputChip(
                              label: Text('#${_normalizeTag(tag)}'),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    Focus(
                      onKeyEvent: (node, event) {
                        if (!settings.aiEnabled) {
                          return KeyEventResult.ignored;
                        }
                        if (_matchesAiShortcut(event, settings.aiEditKeyBinding)) {
                          _openAiEditDialog();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        expands: true,
                        readOnly: _aiBusy,
                        enableInteractiveSelection: !_aiBusy,
                        textAlign: TextAlign.left,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: appInputDecoration(hintText: 'メモを書く…'),
                        onChanged: (_) => _scheduleSave(),
                        contextMenuBuilder: (context, editableTextState) {
                          return _buildAiContextMenu(
                            context,
                            editableTextState,
                            settings,
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
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ),
                    if (settings.charCountEnabled)
                      Positioned(
                        right: 8,
                        bottom: 6,
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) {
                            final count = _countText(
                              value.text,
                              settings.charCountExcludeSymbols,
                            );
                            final suffix = settings.charCountExcludeSymbols
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
                  ],
                ),
              ),
            ),
          ],
        );
      },
      error: (e, _) => Center(child: Text('エラー: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
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
    required this.previewEnabled,
    required this.sendKey,
    required this.initialPrompt,
    required this.autoRun,
    required this.onBusyChanged,
  });

  final String targetText;
  final String targetLabel;
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
      final ai = ref.read(aiServiceProvider);
      result = await ai.editText(
        instruction: instruction,
        originalText: widget.targetText,
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
        TextButton(
          onPressed: _cancel,
          child: const Text('キャンセル'),
        ),
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
    final rightStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF00C853),
        );

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
                  Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                final next = _splitRatio +
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

  Widget _buildDiffPane({
    required List<InlineSpan> spans,
  }) {
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
    final originalChars =
        original.runes.map((r) => String.fromCharCode(r)).toList();
    final modifiedChars =
        modified.runes.map((r) => String.fromCharCode(r)).toList();
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
          dp[i][j] = dp[i - 1][j] >= dp[i][j - 1]
              ? dp[i - 1][j]
              : dp[i][j - 1];
        }
      }
    }

    final ops = <_DiffOp>[];
    var i = originalChars.length;
    var j = modifiedChars.length;
    while (i > 0 || j > 0) {
      if (i > 0 &&
          j > 0 &&
          originalChars[i - 1] == modifiedChars[j - 1]) {
        ops.add(_DiffOp(_DiffOpType.equal, originalChars[i - 1]));
        i--;
        j--;
      } else if (j > 0 &&
          (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
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

    void appendSegment(
      List<_DiffSegment> list,
      String text,
      bool changed,
    ) {
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

    return _DiffResult(
      original: originalSegments,
      modified: modifiedSegments,
    );
  }
}

class _DiffResult {
  const _DiffResult({
    required this.original,
    required this.modified,
  });

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
