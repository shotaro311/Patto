import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note.dart';
import '../providers/ai_providers.dart';
import '../providers/app_settings_controller.dart';
import '../providers/note_repository_provider.dart';
import '../providers/notes_providers.dart';
import '../providers/quick_launch_provider.dart';

class NoteEditorPane extends ConsumerStatefulWidget {
  const NoteEditorPane({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorPane> createState() => _NoteEditorPaneState();
}

class _NoteEditorPaneState extends ConsumerState<NoteEditorPane> {
  final _focusNode = FocusNode();
  late final TextEditingController _controller;
  ProviderSubscription<int>? _quickLaunchSub;

  Timer? _debounce;
  bool _preview = false;
  bool _pendingFocus = true;
  String _lastLoaded = '';

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

    _quickLaunchSub = ref.listenManual<int>(quickLaunchEventProvider, (previous, next) {
      if (_preview) {
        setState(() => _preview = false);
      }
      _markFocusPending(delay: const Duration(milliseconds: 80));
    });

    _markFocusPending();
  }

  @override
  void didUpdateWidget(covariant NoteEditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId) {
      _lastLoaded = '';
      _controller.text = '';
      _markFocusPending();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _quickLaunchSub?.close();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final repo = ref.read(noteRepositoryProvider);
      await repo.updateContent(widget.noteId, _controller.text);
    });
  }

  Future<void> _delete() async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.softDelete(widget.noteId);
    ref.read(selectedNoteIdProvider.notifier).state = null;
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openAiEditDialog(Note note) async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.aiEnabled) return;

    final selection = _controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final selectionStart = hasSelection ? selection.start : null;
    final selectionEnd = hasSelection ? selection.end : null;
    final initialText = hasSelection
        ? _controller.text.substring(selection.start, selection.end)
        : note.content;

    final result = await showDialog<_AiEditResult>(
      context: context,
      builder: (_) => _AiEditDialog(
        initialText: initialText,
        targetLabel: hasSelection ? '選択範囲' : '全文',
      ),
    );
    if (result == null) return;

    switch (result.action) {
      case _AiApplyAction.replace:
        if (hasSelection && selectionStart != null && selectionEnd != null) {
          final current = _controller.text;
          final start = selectionStart < selectionEnd ? selectionStart : selectionEnd;
          final end = selectionStart < selectionEnd ? selectionEnd : selectionStart;
          final next = current.replaceRange(start, end, result.text);
          _controller.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: start + result.text.length),
          );
        } else {
          _controller.text = result.text;
        }
      case _AiApplyAction.append:
        final current = _controller.text;
        if (hasSelection && selectionStart != null && selectionEnd != null) {
          final end = selectionStart < selectionEnd ? selectionEnd : selectionStart;
          final insertion = '\n${result.text}';
          final next = current.replaceRange(end, end, insertion);
          _controller.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: end + insertion.length),
          );
        } else {
          _controller.text = current.isEmpty ? result.text : '$current\n${result.text}';
        }
      case _AiApplyAction.cancel:
        return;
    }
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final noteAsync = ref.watch(noteByIdProvider(widget.noteId));

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

        return Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'AI編集',
                      onPressed: () => _openAiEditDialog(note),
                      icon: const Icon(Icons.auto_fix_high),
                    ),
                    IconButton(
                      tooltip: _preview ? '編集' : 'プレビュー',
                      onPressed: () => setState(() => _preview = !_preview),
                      icon: Icon(_preview ? Icons.edit : Icons.preview),
                    ),
                    IconButton(
                      tooltip: '削除',
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _preview
                  ? Markdown(data: _controller.text)
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        expands: true,
                        textAlign: TextAlign.left,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'メモを書く…',
                        ),
                        onChanged: (_) => _scheduleSave(),
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

class _AiEditDialog extends ConsumerStatefulWidget {
  const _AiEditDialog({
    required this.initialText,
    required this.targetLabel,
  });

  final String initialText;
  final String targetLabel;

  @override
  ConsumerState<_AiEditDialog> createState() => _AiEditDialogState();
}

class _AiEditDialogState extends ConsumerState<_AiEditDialog> {
  final _instructionController = TextEditingController();
  AsyncValue<String> _result = const AsyncValue.data('');

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final instruction = _instructionController.text.trim();
    if (instruction.isEmpty) return;

    setState(() => _result = const AsyncValue.loading());
    _result = await AsyncValue.guard(() async {
      final ai = ref.read(aiServiceProvider);
      return ai.editText(
        instruction: instruction,
        originalText: widget.initialText,
      );
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI文章編集'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('対象: ${widget.targetLabel}'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _instructionController,
              decoration: const InputDecoration(
                labelText: '指示（例: もっと丁寧に）',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('注意: 対象テキストはAIへ送信されます。'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _run,
                child: const Text('実行'),
              ),
            ),
            const SizedBox(height: 12),
            _result.when(
              data: (text) => text.isEmpty
                  ? const SizedBox.shrink()
                  : SizedBox(
                      height: 180,
                      child: SingleChildScrollView(
                        child: SelectableText(text),
                      ),
                    ),
              error: (e, _) => Text('エラー: $e'),
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        TextButton(
          onPressed: _result.valueOrNull == null || _result.valueOrNull!.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    _AiEditResult(_AiApplyAction.append, _result.valueOrNull!),
                  ),
          child: const Text('追記'),
        ),
        FilledButton(
          onPressed: _result.valueOrNull == null || _result.valueOrNull!.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    _AiEditResult(_AiApplyAction.replace, _result.valueOrNull!),
                  ),
          child: const Text('置換して適用'),
        ),
      ],
    );
  }
}

enum _AiApplyAction { replace, append, cancel }

class _AiEditResult {
  const _AiEditResult(this.action, this.text);
  final _AiApplyAction action;
  final String text;
}
