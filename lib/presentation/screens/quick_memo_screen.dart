import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/note.dart';
import '../../data/repositories/tag_dictionary_repository.dart';
import '../../domain/app_settings.dart';
import '../../services/ai_service.dart';
import '../providers/attachment_repository_provider.dart';
import '../providers/ai_providers.dart';
import '../providers/app_settings_controller.dart';
import '../providers/note_repository_provider.dart';
import '../providers/notes_providers.dart';
import '../providers/quick_launch_provider.dart';
import '../providers/quick_memo_provider.dart';
import '../providers/tag_dictionary_repository_provider.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/ai_prompt_presets_hover_menu.dart';
import '../widgets/reorderable_icon_toolbar.dart';
import '../widgets/inline_attachment_controller.dart';
import '../widgets/inline_attachment_view.dart';
import 'external_paste_guard.dart';
import 'note_editor_pane.dart';

class QuickMemoScreen extends ConsumerStatefulWidget {
  const QuickMemoScreen({super.key, this.showDraftActionSheetOnOpen = false});

  final bool showDraftActionSheetOnOpen;

  @override
  ConsumerState<QuickMemoScreen> createState() => _QuickMemoScreenState();
}

class _QuickMemoScreenState extends ConsumerState<QuickMemoScreen> {
  static const EdgeInsets _editorContentPadding = EdgeInsets.all(12);
  static final RegExp _symbolPattern = RegExp(r'[\p{P}\p{S}]', unicode: true);
  static final RegExp _urlPattern = RegExp(r'https?://[^\s)>\"]+');
  final _focusNode = FocusNode();
  late final InlineAttachmentEditingController _controller;
  late final ExternalPasteGuard _externalPasteGuard;
  String _lastLoaded = '';
  ProviderSubscription<int>? _quickLaunchSub;
  ProviderSubscription<int>? _externalPasteSub;
  bool _didShowDraftActionSheet = false;
  bool _inlineBusy = false;
  int _inlineToken = 0;
  int? _runningPresetIndex;
  AiEditScope _promptScope = AiEditScope.full;
  String _lastScopeKey = '';
  bool _aiImageContextEnabled = false;
  bool _isDragOver = false;
  bool _aiTagSuggesting = false;
  int _aiTagSuggestToken = 0;
  List<String> _aiSuggestedTags = [];
  double _editorWidth = 0;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('選択範囲がありません。')));
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
    AiPromptPreset preset,
    int index, {
    Note? note,
  }) async {
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
      final images = note == null ? const <AiImageInput>[] : await _collectAiImages(note);
      final result = await ai.editTextWithImages(
        instruction: preset.prompt,
        originalText: target.originalText,
        images: images,
        useAppleIntelligence: settings.aiAppleIntelligenceEnabled,
        useExternalApi: settings.aiExternalApiEnabled,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI編集に失敗しました。')));
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
    ref
        .read(quickMemoControllerProvider.notifier)
        .updateContent(_controller.text);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('URLをコピーしました。')));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URLが不正です。')));
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ブラウザで開けませんでした。')));
    }
  }

  Future<void> _addImageAttachment() async {
    final note = await _requireDraftNote(allowEmpty: true);
    if (note == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('画像の取得に失敗しました。')));
      return;
    }
    final repo = ref.read(attachmentRepositoryProvider);
    final attachment = await repo.addImageAttachmentFromFile(
      noteId: note.uuid,
      file: File(path),
    );
    if (attachment == null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('画像の追加に失敗しました。')));
      return;
    }
    if (attachment != null) {
      _insertAttachmentToken(attachment.id);
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
      final attachment =
          await repo.addImageAttachmentFromFile(noteId: note.uuid, file: file);
      if (attachment != null) {
        _insertAttachmentToken(attachment.id);
      }
      return attachment;
    } finally {
      if (bookmark != null && bookmark.isNotEmpty && accessGranted) {
        await DesktopDrop.instance
            .stopAccessingSecurityScopedResource(bookmark: bookmark);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('対応形式は png / jpeg / webp です。')));
    }
  }

  void _insertAttachmentToken(String attachmentId) {
    final token = InlineAttachmentEditingController.buildToken(attachmentId);
    final current = _controller.text;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : current.length;
    final end = selection.isValid ? selection.end : current.length;
    final before = current.substring(0, start);
    final after = current.substring(end);
    final needsLeadingBreak = before.isNotEmpty && !before.endsWith('\n');
    final needsTrailingBreak = after.isNotEmpty && !after.startsWith('\n');
    final insert =
        '${needsLeadingBreak ? '\n' : ''}$token${needsTrailingBreak ? '\n' : ''}\n';
    final next = before + insert + after;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: before.length + insert.length),
    );
    ref
        .read(quickMemoControllerProvider.notifier)
        .updateContent(_controller.text);
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
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: 'ai', child: Text('AI編集…')),
      ],
    );
    if (!mounted || selected == null) return;
    if (selected == 'ai') {
      _openAiEditDialog(note: note, imageOverride: attachment);
    }
  }

  Widget _buildAiImageToggleRow(AppSettings settings) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '画像をAIに含める（上限${settings.aiImageSendLimit}枚）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Switch(
              value: _aiImageContextEnabled,
              onChanged: (value) =>
                  setState(() => _aiImageContextEnabled = value),
            ),
          ],
        ),
        Text('注意: 画像を送信するとAPIコストが増える可能性があります。', style: muted),
      ],
    );
  }

  Widget _buildAttachmentSection(Note? note) {
    return Row(
      children: [
        Text('添付画像', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _addImageAttachment,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('追加'),
        ),
      ],
    );
  }

  Widget _buildInlineAttachment(
    BuildContext context,
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
        ref
            .read(quickMemoControllerProvider.notifier)
            .updateContent(_controller.text);
      },
      onContextMenu: (position) async {
        final note = await _requireDraftNote(allowEmpty: true);
        if (note == null) return;
        _showAttachmentMenu(note, attachment, position);
      },
    );
  }

  Widget _buildTextContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
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
      ...editableTextState.contextMenuButtonItems,
    ];
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = InlineAttachmentEditingController(
      attachmentBuilder: (context, attachment, token) {
        return _buildInlineAttachment(context, attachment, token);
      },
    );
    _externalPasteGuard = ExternalPasteGuard(
      controller: _controller,
      focusNode: _focusNode,
    );
    _controller.addListener(_onTextChanged);
    _quickLaunchSub = ref.listenManual<int>(quickLaunchEventProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_focusNode);
      });
    });
    _externalPasteSub = ref.listenManual<int>(externalPasteEventProvider, (
      previous,
      next,
    ) {
      final content = ref.read(externalPasteContentProvider);
      if (content == null || content.isEmpty) return;
      _externalPasteGuard.queueExternalPaste(
        content,
        () => ref
            .read(quickMemoControllerProvider.notifier)
            .updateContent(_controller.text),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void _onTextChanged() {
    _externalPasteGuard.onTextChanged();
  }

  @override
  void dispose() {
    _quickLaunchSub?.close();
    _externalPasteSub?.close();
    _externalPasteGuard.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final controller = ref.read(quickMemoControllerProvider.notifier);
    final note = await controller.saveAsNote();
    if (note == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('内容を入力してください')));
      return;
    }

    ref.read(selectedNoteIdProvider.notifier).state = note.uuid;
    await ref.read(appSettingsProvider.notifier).setLastOpenedNoteId(note.uuid);

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('保存しました'),
        duration: const Duration(seconds: 2),
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
    return TagDictionaryRepository.normalizeTag(value);
  }

  Future<Note?> _requireDraftNote({bool allowEmpty = false}) async {
    final controller = ref.read(quickMemoControllerProvider.notifier);
    final note = await controller.ensureDraftExists(allowEmpty: allowEmpty);
    if (note == null) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('内容を入力してください')));
      return null;
    }
    return note;
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
    await ref.read(noteRepositoryProvider).setManualTags(note.uuid, next);
    await tagRepo.recordUsage(canonical);
  }

  Future<void> _removeManualTag(Note note, String tag) async {
    final tagRepo = ref.read(tagDictionaryRepositoryProvider);
    final target = await tagRepo.resolveToCanonical(tag);
    final existing = await tagRepo.resolveAll(note.manualTags);
    final next = existing.where((t) => t != target).toList()..sort();
    await ref.read(noteRepositoryProvider).setManualTags(note.uuid, next);
  }

  Future<void> _applyAutoTag(Note note, String tag) async {
    final tagRepo = ref.read(tagDictionaryRepositoryProvider);
    final canonical = await tagRepo.resolveToCanonical(tag);
    if (canonical.isEmpty) return;
    final existing = await tagRepo.resolveAll(note.autoTags);
    final next = <String>{...existing, canonical}.toList()..sort();
    await ref.read(noteRepositoryProvider).setAutoTags(note.uuid, next);
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
    await ref.read(noteRepositoryProvider).setAutoTags(note.uuid, next);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI提案に失敗しました')));
    } finally {
      if (mounted && token == _aiTagSuggestToken) {
        setState(() => _aiTagSuggesting = false);
      }
    }
  }

  Future<void> _openAiEditDialog({
    required Note note,
    AiPromptPreset? preset,
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
        hasSelection && start == 0 && end == currentText.length;
    final autoScope = preset != null
        ? (hasSelection
              ? (isFullSelection ? AiEditScope.full : AiEditScope.selection)
              : AiEditScope.full)
        : (hasSelection
              ? (isFullSelection ? AiEditScope.full : AiEditScope.selection)
              : AiEditScope.cursor);
    final scope = scopeOverride ?? autoScope;
    if (scope == AiEditScope.selection && !hasSelection) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('選択範囲がありません。')));
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
        onBusyChanged: (_) {},
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
    ref
        .read(quickMemoControllerProvider.notifier)
        .updateContent(_controller.text);
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
        await ref
            .read(quickMemoControllerProvider.notifier)
            .discardCurrentDraft();
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

    final hasTagBar =
        (draftNote?.manualTags.isNotEmpty ?? false) ||
        (draftNote?.autoTags.isNotEmpty ?? false) ||
        _aiSuggestedTags.isNotEmpty ||
        _aiTagSuggesting;

    _controller.setAttachments(draftNote?.attachments ?? const []);

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
                      _requireDraftNote().then((note) {
                        if (note == null) return;
                        _openAiEditDialog(
                          note: note,
                          preset: preset,
                          scopeOverride: _promptScope,
                        );
                      });
                      return;
                    }
                    _requireDraftNote().then((note) {
                      if (note == null) return;
                      _runInlineAiEdit(
                        preset,
                        index,
                        note: note,
                      );
                    });
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
                  message: settings.aiEnabled ? 'AIでタグ提案' : 'AI編集は設定で有効化してください',
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
                    onPressed: settings.aiEnabled
                        ? () async {
                            final note = await _requireDraftNote();
                            if (note == null) return;
                            _openAiEditDialog(note: note);
                          }
                        : null,
                    icon: const Icon(Icons.auto_fix_high),
                  ),
                ),
              ),
            ],
          ),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _isDragOver = true),
        onDragExited: (_) => setState(() => _isDragOver = false),
        onDragDone: (details) async {
          setState(() => _isDragOver = false);
          final note = await _requireDraftNote(allowEmpty: true);
          if (note == null) return;
          await _handleDrop(note, details.files);
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildAiImageToggleRow(settings),
                  const SizedBox(height: 4),
                  _buildAttachmentSection(draftNote),
                  const SizedBox(height: 8),
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
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
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
                        Focus(
                          onKeyEvent: (node, event) {
                            if (_handleEnterKey(event)) {
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              _editorWidth = constraints.maxWidth -
                                  _editorContentPadding.horizontal;
                              if (_editorWidth < 0) _editorWidth = 0;
                              return TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                maxLines: null,
                                expands: true,
                                textAlign: TextAlign.left,
                                textAlignVertical: TextAlignVertical.top,
                                inputFormatters:
                                    const [AttachmentTokenInputFormatter()],
                                decoration: appInputDecoration(
                                  hintText: 'クイックメモを書く…',
                                ).copyWith(
                                  contentPadding: _editorContentPadding,
                                ),
                                onChanged: (value) => ref
                                    .read(quickMemoControllerProvider.notifier)
                                    .updateContent(value),
                                contextMenuBuilder:
                                    (context, editableTextState) {
                                  return _buildTextContextMenu(
                                    context,
                                    editableTextState,
                                  );
                                },
                              );
                            },
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
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
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
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _DraftAction { save, edit, discard }
