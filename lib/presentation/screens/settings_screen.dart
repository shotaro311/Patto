import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../domain/app_settings.dart';
import '../providers/ai_providers.dart';
import '../providers/app_settings_controller.dart';
import '../providers/auth_providers.dart';
import '../providers/note_repository_provider.dart';
import '../providers/supabase_providers.dart';
import '../providers/sync_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _aiKeyController = TextEditingController();
  var _aiKeyVisible = false;
  var _aiKeyRegistered = false;
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(aiKeyRepositoryProvider);
      final key = await repo.readKey();
      if (!mounted) return;
      setState(() => _aiKeyRegistered = key != null && key.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _aiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveAiKey() async {
    final value = _aiKeyController.text.trim();
    if (value.isEmpty) return;
    final repo = ref.read(aiKeyRepositoryProvider);
    await repo.writeKey(value);
    if (!mounted) return;
    setState(() {
      _aiKeyRegistered = true;
      _aiKeyController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI APIキーを保存しました')),
    );
  }

  Future<void> _deleteAiKey() async {
    final repo = ref.read(aiKeyRepositoryProvider);
    await repo.deleteKey();
    if (!mounted) return;
    setState(() => _aiKeyRegistered = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI APIキーを削除しました')),
    );
  }

  Future<void> _toggleSync(bool enabled) async {
    final supabaseConfig = ref.read(supabaseConfigProvider);
    if (supabaseConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabaseが未設定です（dart-defineが必要）')),
      );
      return;
    }

    await ref.read(appSettingsProvider.notifier).setSyncEnabled(enabled);
    if (!enabled) return;

    final userId = ref.read(supabaseUserIdProvider);
    if (userId == null && mounted) {
      await Navigator.of(context).pushNamed('/auth');
    }

    final userId2 = ref.read(supabaseUserIdProvider);
    if (userId2 == null) {
      await ref.read(appSettingsProvider.notifier).setSyncEnabled(false);
      return;
    }

    final repo = ref.read(noteRepositoryProvider);
    await repo.markAllDirty();
    await _syncNow();
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    final service = ref.read(syncServiceProvider);
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同期にはログインが必要です')),
      );
      return;
    }

    setState(() => _syncing = true);
    try {
      final settings = ref.read(appSettingsProvider);
      final result = await service.syncNow(lastSyncAt: settings.lastSyncAt);
      await ref.read(appSettingsProvider.notifier).setLastSyncAt(result.lastSyncAt);

      if (!mounted) return;
      final msg =
          result.conflicts > 0 ? '同期完了（競合: ${result.conflicts}）' : '同期完了';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('同期エラー: $e')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final supabaseConfig = ref.watch(supabaseConfigProvider);
    final userIdAsync = ref.watch(authUserIdStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('同期', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('同期を有効化（ログイン時のみ）'),
            subtitle: supabaseConfig == null
                ? const Text('Supabaseが未設定です（SUPABASE_URL / SUPABASE_ANON_KEY）')
                : null,
            value: settings.syncEnabled,
            onChanged: supabaseConfig == null ? null : _toggleSync,
          ),
          ListTile(
            title: const Text('ログイン状態'),
            subtitle: userIdAsync.when(
              data: (id) => Text(id == null ? '未ログイン' : 'ログイン中'),
              error: (e, _) => Text('エラー: $e'),
              loading: () => const Text('読み込み中…'),
            ),
            trailing: userIdAsync.valueOrNull == null
                ? TextButton(
                    onPressed: () => Navigator.of(context).pushNamed('/auth'),
                    child: const Text('ログイン'),
                  )
                : TextButton(
                    onPressed: () async {
                      final auth = ref.read(authServiceProvider);
                      await auth?.signOut();
                    },
                    child: const Text('ログアウト'),
                  ),
          ),
          ListTile(
            title: const Text('今すぐ同期'),
            trailing: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FilledButton(
                    onPressed: settings.syncEnabled ? _syncNow : null,
                    child: const Text('同期'),
                  ),
          ),
          const Divider(height: 32),
          Text('クイック起動', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('起動時に開くメモ'),
            subtitle: const Text('新規メモ / 前回のメモ'),
            trailing: DropdownButton<QuickLaunchOpenMode>(
              value: settings.quickLaunchOpenMode,
              onChanged: (v) {
                if (v == null) return;
                ref.read(appSettingsProvider.notifier).setQuickLaunchOpenMode(v);
              },
              items: const [
                DropdownMenuItem(
                  value: QuickLaunchOpenMode.newNote,
                  child: Text('新規'),
                ),
                DropdownMenuItem(
                  value: QuickLaunchOpenMode.lastNote,
                  child: Text('前回'),
                ),
              ],
            ),
          ),
          if (Platform.isMacOS)
            ListTile(
              title: const Text('macOS: 装飾キー（ダブルタップ）'),
              trailing: DropdownButton<MacModifierKey>(
                value: settings.macModifierKey,
                onChanged: (v) {
                  if (v == null) return;
                  ref.read(appSettingsProvider.notifier).setMacModifierKey(v);
                },
                items: const [
                  DropdownMenuItem(
                    value: MacModifierKey.command,
                    child: Text('Command'),
                  ),
                  DropdownMenuItem(
                    value: MacModifierKey.control,
                    child: Text('Control'),
                  ),
                  DropdownMenuItem(
                    value: MacModifierKey.option,
                    child: Text('Option'),
                  ),
                  DropdownMenuItem(
                    value: MacModifierKey.shift,
                    child: Text('Shift'),
                  ),
                ],
              ),
            ),
          const Divider(height: 32),
          Text('AI', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('AI文章編集を有効化'),
            value: settings.aiEnabled,
            onChanged: (v) => ref.read(appSettingsProvider.notifier).setAiEnabled(v),
          ),
          ListTile(
            title: const Text('AI APIキー'),
            subtitle: Text(_aiKeyRegistered ? '登録済み' : '未登録'),
            trailing: _aiKeyRegistered
                ? TextButton(
                    onPressed: _deleteAiKey,
                    child: const Text('削除'),
                  )
                : null,
          ),
          const Text(
            '注意: AI文章編集では、選択した本文がAIへ送信されます。',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _aiKeyController,
            obscureText: !_aiKeyVisible,
            decoration: InputDecoration(
              labelText: 'APIキーを入力して保存',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _aiKeyVisible ? '隠す' : '表示',
                onPressed: () => setState(() => _aiKeyVisible = !_aiKeyVisible),
                icon: Icon(_aiKeyVisible ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saveAiKey,
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}
