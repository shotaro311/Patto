import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note.dart';
import '../providers/app_settings_controller.dart';
import '../providers/notes_providers.dart';
import '../providers/quick_launch_provider.dart';
import '../providers/quick_memo_provider.dart';

class QuickMemoScreen extends ConsumerStatefulWidget {
  const QuickMemoScreen({super.key});

  @override
  ConsumerState<QuickMemoScreen> createState() => _QuickMemoScreenState();
}

class _QuickMemoScreenState extends ConsumerState<QuickMemoScreen> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  String _lastLoaded = '';
  ProviderSubscription<int>? _quickLaunchSub;

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
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'クイックメモを書く…',
          ),
          onChanged: (value) =>
              ref.read(quickMemoControllerProvider.notifier).updateContent(value),
        ),
      ),
    );
  }
}
