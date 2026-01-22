import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note.dart';
import '../providers/app_settings_controller.dart';
import '../providers/quick_launch_provider.dart';
import '../providers/quick_memo_provider.dart';
import '../widgets/app_input_decoration.dart';

class QuickMemoScreen extends ConsumerStatefulWidget {
  const QuickMemoScreen({super.key});

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

    await ref.read(appSettingsProvider.notifier).setLastOpenedNoteId(note.uuid);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('保存しました')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickMemoControllerProvider);
    final settings = ref.watch(appSettingsProvider);

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
          PopupMenuButton<String>(
            tooltip: '下書き',
            onSelected: (value) async {
              if (value == '__new') {
                ref.read(quickMemoControllerProvider.notifier).startNewDraft();
              } else {
                await ref
                    .read(quickMemoControllerProvider.notifier)
                    .openDraft(value);
              }
              if (!mounted) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) FocusScope.of(context).requestFocus(_focusNode);
              });
            },
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[
                const PopupMenuItem(
                  value: '__new',
                  child: Text('新規下書き'),
                ),
              ];
              if (state.drafts.isEmpty) return items;
              items.add(const PopupMenuDivider());
              for (final draft in state.drafts) {
                final label = draft.title.trim().isEmpty ? '（無題）' : draft.title.trim();
                items.add(
                  PopupMenuItem(
                    value: draft.uuid,
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                );
              }
              return items;
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.history),
            ),
          ),
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            TextField(
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
    );
  }
}
