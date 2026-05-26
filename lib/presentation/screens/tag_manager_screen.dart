import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/tag_dictionary_repository.dart';
import '../providers/tag_dictionary_repository_provider.dart';
import '../providers/tag_summaries_provider.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/patto_surface.dart';

class TagManagerScreen extends ConsumerWidget {
  const TagManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(tagSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('タグ管理')),
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: summariesAsync.when(
          data: (summaries) {
            if (summaries.isEmpty) {
              return const Center(child: Text('タグがありません'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: summaries.length,
              itemBuilder: (context, index) {
                final summary = summaries[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TagSummaryTile(summary: summary),
                );
              },
            );
          },
          error: (e, _) => Center(child: Text('エラー: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _TagSummaryTile extends ConsumerWidget {
  const _TagSummaryTile({required this.summary});

  final TagSummary summary;

  Future<void> _renameTag(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: summary.tag);
    final repo = ref.read(tagDictionaryRepositoryProvider);

    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('タグ名を変更'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: appInputDecoration(hintText: 'タグ名'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) =>
                Navigator.of(dialogContext).pop(controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (next == null) return;

    final from = TagDictionaryRepository.normalizeTag(summary.tag);
    final to = TagDictionaryRepository.normalizeTag(next);
    if (to.isEmpty || from == to) return;

    await repo.renameTag(from: from, to: to);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('タグを「#$to」に変更しました')));
  }

  Future<void> _deleteTag(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(tagDictionaryRepositoryProvider);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('タグを削除'),
              content: Text(
                'タグ「#${summary.tag}」を削除します。\n'
                'このタグはメモからも外れます。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('削除'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) return;

    await repo.deleteTag(summary.tag);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('タグ「#${summary.tag}」を削除しました')));
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _TagMenuAction action,
  ) async {
    switch (action) {
      case _TagMenuAction.rename:
        await _renameTag(context, ref);
      case _TagMenuAction.delete:
        await _deleteTag(context, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = '#${summary.tag}';
    final countText = '${summary.noteCount}件';

    return PattoSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      muted: true,
      onTap: () => _renameTag(context, ref),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.sell_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(countText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<_TagMenuAction>(
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _TagMenuAction.rename, child: Text('名前を変更')),
              PopupMenuItem(value: _TagMenuAction.delete, child: Text('削除')),
            ],
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }
}

enum _TagMenuAction { rename, delete }
