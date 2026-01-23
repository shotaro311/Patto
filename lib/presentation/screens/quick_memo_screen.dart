import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note.dart';
import '../../domain/app_settings.dart';
import '../providers/ai_providers.dart';
import '../providers/app_settings_controller.dart';
import '../providers/note_repository_provider.dart';
import '../providers/notes_providers.dart';
import '../providers/quick_launch_provider.dart';
import '../providers/quick_memo_provider.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/ai_prompt_presets_hover_menu.dart';
import '../widgets/reorderable_icon_toolbar.dart';
import 'note_editor_pane.dart';

class QuickMemoScreen extends ConsumerStatefulWidget {
  const QuickMemoScreen({
    super.key,
    this.showDraftActionSheetOnOpen = false,
  });

  final bool showDraftActionSheetOnOpen;

  @override
  ConsumerState<QuickMemoScreen> createState() => _QuickMemoScreenState();
}

class _QuickMemoScreenState extends ConsumerState<QuickMemoScreen> {
  static final RegExp _symbolPattern =
      RegExp(r'[\p{P}\p{S}]', unicode: true);
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  String _lastLoaded = '';
  ProviderSubscription<int>? _quickLaunchSub;
  bool _didShowDraftActionSheet = false;
  bool _aiBusy = false;
  bool _inlineBusy = false;
  int _inlineToken = 0;
  int? _runningPresetIndex;
  AiEditScope _promptScope = AiEditScope.full;
  String _lastScopeKey = '';
  bool _aiTagSuggesting = false;
  int _aiTagSuggestToken = 0;
  List<String> _aiSuggestedTags = [];

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
    final baseOffset =
        selection.baseOffset >= 0 ? selection.baseOffset : currentText.length;
    final extentOffset =
        selection.extentOffset >= 0 ? selection.extentOffset : currentText.length;
    final start = hasSelection
        ? (baseOffset < extentOffset ? baseOffset : extentOffset)
        : baseOffset;
    final end = hasSelection
        ? (baseOffset < extentOffset ? extentOffset : baseOffset)
        : extentOffset;

    if (scope == AiEditScope.selection && !hasSelection) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('選択範囲がありません。')));
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

  Future<void> _runInlineAiEdit(AiPromptPreset preset, int index) async {
    if (_inlineBusy) return;
    final target = _buildTargetForScope(_promptScope);
    if (target == null) return;

    final token = ++_inlineToken;
    setState(() {
      _inlineBusy = true;
      _runningPresetIndex = index;
    });

    try {
      final ai = ref.read(aiServiceProvider);
      final result = await ai.editText(
        instruction: preset.prompt,
        originalText: target.originalText,
      );
      if (!mounted || token != _inlineToken) return;
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
      ref
          .read(quickMemoControllerProvider.notifier)
          .updateContent(_controller.text);
    } catch (_) {
      if (!mounted || token != _inlineToken) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('AI編集に失敗しました。')));
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

  @override
  void initState() {
    super.initState();
    _quickLaunchSub = ref.listenManual<int>(
      quickLaunchEventProvider,
      (previous, next) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) FocusScope.of(context).requestFocus(_focusNode);
        });
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _quickLaunchSub?.close();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final controller = ref.read(quickMemoControllerProvider.notifier);
    final note = await controller.saveAsNote();
    if (note == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('内容を入力してください')));
      return;
    }

    ref.read(selectedNoteIdProvider.notifier).state = note.uuid;
    await ref.read(appSettingsProvider.notifier).setLastOpenedNoteId(note.uuid);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('保存しました'),
        action: SnackBarAction(
          label: '開く',
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }

  String _normalizeTag(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.toLowerCase();
  }

  Future<Note?> _requireDraftNote() async {
    final controller = ref.read(quickMemoControllerProvider.notifier);
    final note = await controller.ensureDraftExists();
    if (note == null) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('内容を入力してください')));
      return null;
    }
    return note;
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
      await ref.read(noteRepositoryProvider).setManualTags(note.uuid, next);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _removeManualTag(Note note, String tag) async {
    final target = _normalizeTag(tag);
    final next = note.manualTags.map(_normalizeTag).where((t) => t != target).toList()
      ..sort();
    await ref.read(noteRepositoryProvider).setManualTags(note.uuid, next);
  }

  Future<void> _applyAutoTag(Note note, String tag) async {
    final normalized = _normalizeTag(tag);
    if (normalized.isEmpty) return;
    final next = <String>{
      for (final t in note.autoTags) _normalizeTag(t),
      normalized,
    }.toList()
      ..sort();
    await ref.read(noteRepositoryProvider).setAutoTags(note.uuid, next);
    if (!mounted) return;
    setState(() {
      _aiSuggestedTags = _aiSuggestedTags.where((t) => _normalizeTag(t) != normalized).toList();
    });
  }

  Future<void> _removeAutoTag(Note note, String tag) async {
    final target = _normalizeTag(tag);
    final next = note.autoTags.map(_normalizeTag).where((t) => t != target).toList()
      ..sort();
    await ref.read(noteRepositoryProvider).setAutoTags(note.uuid, next);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('AI提案に失敗しました')));
    } finally {
      if (mounted && token == _aiTagSuggestToken) {
        setState(() => _aiTagSuggesting = false);
      }
    }
  }

  Future<void> _openAiEditDialog({
    AiPromptPreset? preset,
    AiEditScope? scopeOverride,
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
    final isFullSelection = hasSelection && start == 0 && end == currentText.length;
    final autoScope = preset != null
        ? (hasSelection ? (isFullSelection ? AiEditScope.full : AiEditScope.selection)
            : AiEditScope.full)
        : (hasSelection ? (isFullSelection ? AiEditScope.full : AiEditScope.selection)
            : AiEditScope.cursor);
    final scope = scopeOverride ?? autoScope;
    if (scope == AiEditScope.selection && !hasSelection) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('選択範囲がありません。')));
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
    ref.read(quickMemoControllerProvider.notifier).updateContent(_controller.text);
  }

  Future<void> _showDraftActionSheet() async {
    final action = await showModalBottomSheet<_DraftAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('保存'),
                subtitle: const Text('保存済みメモに追加して、クイックメモを空にする'),
                onTap: () => Navigator.of(context).pop(_DraftAction.save),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('編集'),
                subtitle: const Text('このまま編集を続ける'),
                onTap: () => Navigator.of(context).pop(_DraftAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('破棄'),
                subtitle: const Text('この下書きを削除して、クイックメモを空にする'),
                onTap: () => Navigator.of(context).pop(_DraftAction.discard),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (action == null) {
      FocusScope.of(context).requestFocus(_focusNode);
      return;
    }

    switch (action) {
      case _DraftAction.save:
        await _save();
      case _DraftAction.edit:
        FocusScope.of(context).requestFocus(_focusNode);
      case _DraftAction.discard:
        await ref.read(quickMemoControllerProvider.notifier).discardCurrentDraft();
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_focusNode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickMemoControllerProvider);
    final settings = ref.watch(appSettingsProvider);
    final draftNoteAsync = state.currentDraftId == null
        ? const AsyncValue<Note?>.data(null)
        : ref.watch(noteByIdProvider(state.currentDraftId!));
    final draftNote = draftNoteAsync.valueOrNull;

    if (!state.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_lastLoaded != state.content && _controller.text == _lastLoaded) {
      _controller.text = state.content;
      _lastLoaded = state.content;
    } else if (_lastLoaded.isEmpty && _controller.text.isEmpty) {
      _controller.text = state.content;
      _lastLoaded = state.content;
    }

    final selection = _controller.selection;
    _syncPromptScope(selection);

    final title = deriveTitleFromContent(_controller.text);
    final display = title.isEmpty ? 'クイックメモ' : title;

    if (widget.showDraftActionSheetOnOpen &&
        !_didShowDraftActionSheet &&
        state.content.trim().isNotEmpty) {
      _didShowDraftActionSheet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDraftActionSheet();
      });
    }

    final hasTagBar = (draftNote?.manualTags.isNotEmpty ?? false) ||
        (draftNote?.autoTags.isNotEmpty ?? false) ||
        _aiSuggestedTags.isNotEmpty ||
        _aiTagSuggesting;

    return Scaffold(
      appBar: AppBar(
        title: Text(display),
        actions: [
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
                  keepOpenWhileRunning: !settings.aiPreviewEnabled,
                  onSelect: (preset, index) {
                    if (!settings.aiEnabled) return;
                    if (settings.aiPreviewEnabled) {
                      _openAiEditDialog(
                        preset: preset,
                        scopeOverride: _promptScope,
                      );
                      return;
                    }
                    _runInlineAiEdit(preset, index);
                  },
                ),
              ),
              ToolbarAction(
                id: 'add_tag',
                builder: (context) => IconButton(
                  tooltip: 'タグを追加',
                  onPressed: () async {
                    final note = await _requireDraftNote();
                    if (note == null) return;
                    await _addManualTag(note);
                  },
                  icon: const Icon(Icons.label_outline),
                ),
              ),
              ToolbarAction(
                id: 'ai_tag_suggest',
                builder: (context) => Tooltip(
                  message:
                      settings.aiEnabled ? 'AIでタグ提案' : 'AI編集は設定で有効化してください',
                  child: IconButton(
                    onPressed: settings.aiEnabled && !_aiTagSuggesting
                        ? () async {
                            final note = await _requireDraftNote();
                            if (note == null) return;
                            await _runAiTagSuggest(note);
                          }
                        : null,
                    icon: const Icon(Icons.auto_awesome),
                  ),
                ),
              ),
              ToolbarAction(
                id: 'ai_edit',
                builder: (context) => Tooltip(
                  message: settings.aiEnabled ? 'AI編集' : 'AI編集は設定で有効化してください',
                  child: IconButton(
                    onPressed:
                        settings.aiEnabled ? () => _openAiEditDialog() : null,
                    icon: const Icon(Icons.auto_fix_high),
                  ),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (hasTagBar)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (_aiTagSuggesting) const Chip(label: Text('AI提案中…')),
                    if (draftNote != null)
                      for (final tag in draftNote.manualTags)
                        InputChip(
                          label: Text('#${_normalizeTag(tag)}'),
                          onDeleted: () => _removeManualTag(draftNote, tag),
                        ),
                    if (draftNote != null)
                      for (final tag in draftNote.autoTags)
                        InputChip(
                          label: Text('#${_normalizeTag(tag)}'),
                          backgroundColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                          onDeleted: () => _removeAutoTag(draftNote, tag),
                        ),
                    if (draftNote != null)
                      for (final tag in _aiSuggestedTags)
                        ActionChip(
                          label: Text('提案: #${_normalizeTag(tag)}'),
                          onPressed: () => _applyAutoTag(draftNote, tag),
                        ),
                  ],
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    expands: true,
                    readOnly: _aiBusy || _inlineBusy,
                    enableInteractiveSelection: !(_aiBusy || _inlineBusy),
                    textAlign: TextAlign.left,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: appInputDecoration(hintText: 'クイックメモを書く…'),
                    onChanged: (value) => ref
                        .read(quickMemoControllerProvider.notifier)
                        .updateContent(value),
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
          ],
        ),
      ),
    );
  }
}

enum _DraftAction { save, edit, discard }
