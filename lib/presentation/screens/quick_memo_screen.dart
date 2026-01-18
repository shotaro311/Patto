import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note.dart';
import '../providers/app_settings_controller.dart';
import '../providers/notes_providers.dart';
import '../providers/quick_launch_provider.dart';
import '../providers/quick_memo_provider.dart';
import '../widgets/app_input_decoration.dart';
import 'external_paste_guard.dart';

class QuickMemoScreen extends ConsumerStatefulWidget {
  const QuickMemoScreen({super.key});

  @override
  ConsumerState<QuickMemoScreen> createState() => _QuickMemoScreenState();
}

class _QuickMemoScreenState extends ConsumerState<QuickMemoScreen> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  late final ExternalPasteGuard _externalPasteGuard;
  String _lastLoaded = '';
  ProviderSubscription<int>? _quickLaunchSub;
  ProviderSubscription<int>? _externalPasteSub;

  @override
  void initState() {
    super.initState();
    _externalPasteGuard = ExternalPasteGuard(
      controller: _controller,
      focusNode: _focusNode,
    );
    _controller.addListener(_onTextChanged);
    _quickLaunchSub = ref.listenManual<int>(
      quickLaunchEventProvider,
      (previous, next) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_focusNode);
      });
      },
    );
    _externalPasteSub = ref.listenManual<int>(
      externalPasteEventProvider,
      (previous, next) {
        final content = ref.read(externalPasteContentProvider);
        if (content == null || content.isEmpty) return;
        _externalPasteGuard.queueExternalPaste(
          content,
          () => ref.read(quickMemoControllerProvider.notifier).updateContent(_controller.text),
        );
      },
    );
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('内容を入力してください')));
      return;
    }

    ref.read(selectedNoteIdProvider.notifier).state = note.uuid;
    await ref.read(appSettingsProvider.notifier).setLastOpenedNoteId(note.uuid);

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickMemoControllerProvider);

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

    final title = deriveTitleFromContent(_controller.text);
    final display = title.isEmpty ? 'クイックメモ' : title;

    return Scaffold(
      appBar: AppBar(
        title: Text(display),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: null,
          expands: true,
          textAlign: TextAlign.left,
          textAlignVertical: TextAlignVertical.top,
          decoration: appInputDecoration(hintText: 'クイックメモを書く…'),
          onChanged: (value) =>
              ref.read(quickMemoControllerProvider.notifier).updateContent(value),
        ),
      ),
    );
  }
}
