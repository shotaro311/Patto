// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/providers.dart';
import '../../data/models/note.dart';
import '../../domain/app_settings.dart';
import '../../services/sync_service.dart';
import '../providers/ai_providers.dart';
import '../providers/app_settings_controller.dart';
import '../providers/auth_providers.dart';
import '../providers/note_repository_provider.dart';
import '../providers/sync_providers.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/top_right_toast.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _KeyBindingCaptureDialog extends StatefulWidget {
  const _KeyBindingCaptureDialog({required this.title});

  final String title;

  @override
  State<_KeyBindingCaptureDialog> createState() =>
      _KeyBindingCaptureDialogState();
}

class _KeyBindingCaptureDialogState extends State<_KeyBindingCaptureDialog> {
  final _focusNode = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.meta;
  }

  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return;
    }
    if (_isModifierKey(event.logicalKey)) {
      setState(() => _error = '修飾キーだけでは設定できません');
      return;
    }

    if (event.data is! RawKeyEventDataMacOs) {
      setState(() => _error = 'この環境では設定できません');
      return;
    }

    final hasModifier = event.isMetaPressed ||
        event.isControlPressed ||
        event.isAltPressed ||
        event.isShiftPressed;
    if (!hasModifier) {
      setState(() => _error = '修飾キーを1つ以上入れてください');
      return;
    }

    final data = event.data as RawKeyEventDataMacOs;
    final label = event.logicalKey.keyLabel.isNotEmpty
        ? event.logicalKey.keyLabel
        : (event.logicalKey.debugName ?? '');
    final binding = MacKeyBinding(
      keyCode: data.keyCode,
      keyLabel: label,
      command: event.isMetaPressed,
      control: event.isControlPressed,
      option: event.isAltPressed,
      shift: event.isShiftPressed,
    );
    Navigator.of(context).pop(binding);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('割り当てたいキーを押してください'),
              const SizedBox(height: 8),
              const Text('Escでキャンセル'),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
      ],
    );
  }
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _aiKeyController = TextEditingController();
  final _presetNameControllers =
      List<TextEditingController>.generate(6, (_) => TextEditingController());
  final _presetPromptControllers =
      List<TextEditingController>.generate(6, (_) => TextEditingController());
  Timer? _presetDebounce;
  var _aiKeyVisible = false;
  var _aiKeyRegistered = false;
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    _syncPresetControllers(ref.read(appSettingsProvider).aiPromptPresets);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = ref.read(aiKeyRepositoryProvider);
      final key = await repo.readKey();
      if (!mounted) return;
      setState(() {
        if (_aiKeyRegistered) return;
        _aiKeyRegistered = key != null && key.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _aiKeyController.dispose();
    for (final controller in _presetNameControllers) {
      controller.dispose();
    }
    for (final controller in _presetPromptControllers) {
      controller.dispose();
    }
    _presetDebounce?.cancel();
    super.dispose();
  }

  void _syncPresetControllers(List<AiPromptPreset> presets) {
    for (var i = 0; i < _presetNameControllers.length; i++) {
      final preset = i < presets.length
          ? presets[i]
          : const AiPromptPreset(name: '', prompt: '');
      if (_presetNameControllers[i].text != preset.name) {
        _presetNameControllers[i].text = preset.name;
      }
      if (_presetPromptControllers[i].text != preset.prompt) {
        _presetPromptControllers[i].text = preset.prompt;
      }
    }
  }

  void _schedulePresetSave() {
    _presetDebounce?.cancel();
    _presetDebounce = Timer(const Duration(milliseconds: 300), () {
      final presets = List<AiPromptPreset>.generate(
        6,
        (index) => AiPromptPreset(
          name: _presetNameControllers[index].text,
          prompt: _presetPromptControllers[index].text,
        ),
      );
      ref.read(appSettingsProvider.notifier).setAiPromptPresets(presets);
    });
  }

  Future<void> _selectKeyBinding({
    required String title,
    required Future<void> Function(MacKeyBinding? next) onChanged,
  }) async {
    final result = await showDialog<MacKeyBinding?>(
      context: context,
      builder: (_) => _KeyBindingCaptureDialog(title: title),
    );
    if (result == null) return;
    await onChanged(result);
  }

  Future<void> _saveAiKey() async {
    final value = _aiKeyController.text.trim();
    if (value.isEmpty) return;
    final repo = ref.read(aiKeyRepositoryProvider);
    try {
      await repo.writeKey(value);
      final confirmed = await repo.readKey();
      if (confirmed == null || confirmed.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI APIキーの保存に失敗しました')),
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI APIキーの保存に失敗しました')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _aiKeyRegistered = true;
      _aiKeyController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI APIキーを保存しました')),
    );
  }

  Future<void> _toggleAppleIntelligence(bool enabled) async {
    if (!enabled) {
      await ref
          .read(appSettingsProvider.notifier)
          .setAiAppleIntelligenceEnabled(false);
      return;
    }
    final ai = ref.read(aiServiceProvider);
    final availability = await ai.checkAppleIntelligenceAvailability();
    if (!mounted) return;
    if (!availability.isAvailable) {
      showTopRightToast(
        context,
        'Apple Intelligence対応端末でないか、設定がされていないため利用できません。',
      );
      return;
    }
    await ref
        .read(appSettingsProvider.notifier)
        .setAiAppleIntelligenceEnabled(true);
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

    final userId = ref.read(authUserIdStreamProvider).valueOrNull;
    if (userId == null && mounted) {
      await Navigator.of(context).pushNamed('/auth');
    }

    final userId2 = await ref.read(authUserIdStreamProvider.future);
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
    ref.read(syncInProgressProvider.notifier).state = true;
    try {
      final settings = ref.read(appSettingsProvider);
      final result = await service.syncNow(lastSyncAt: settings.lastSyncAt);
      if (result.lastSyncAt != null) {
        await ref.read(appSettingsProvider.notifier).setLastSyncAt(result.lastSyncAt);
      }

      if (result.conflictDetails.isNotEmpty && mounted) {
        final resolved = await _resolveConflicts(service, result.conflictDetails);
        if (resolved && mounted) {
          ref.read(syncConflictsProvider.notifier).state = [];
        }
      }

      if (!mounted) return;
      final msg =
          result.conflicts > 0 ? '同期完了（競合: ${result.conflicts}）' : '同期完了';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('同期エラー: $e')));
    } finally {
      ref.read(syncInProgressProvider.notifier).state = false;
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<bool> _resolveConflicts(
    SyncService service,
    List<SyncConflict> conflicts,
  ) async {
    for (var i = 0; i < conflicts.length; i++) {
      final conflict = conflicts[i];
      if (!mounted) return false;
      final choice = await _showConflictDialog(conflict);
      if (!mounted) return false;
      if (choice == null || choice == _ConflictChoice.later) {
        ref.read(syncConflictsProvider.notifier).state =
            conflicts.sublist(i);
        return false;
      }

      final resolution = choice == _ConflictChoice.keepLocal
          ? SyncConflictResolution.keepLocal
          : SyncConflictResolution.keepRemote;
      await service.resolveConflict(conflict, resolution);
    }
    return true;
  }

  Future<_ConflictChoice?> _showConflictDialog(SyncConflict conflict) {
    return showDialog<_ConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('同期の競合を解決'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ConflictSection(
                    title: 'ローカル',
                    note: conflict.local,
                    updatedAt: conflict.local.localUpdatedAt.toLocal(),
                  ),
                  const SizedBox(height: 16),
                  _ConflictSection(
                    title: 'クラウド',
                    note: conflict.remote,
                    updatedAt:
                        conflict.remote.serverUpdatedAt?.toLocal() ??
                        conflict.remote.localUpdatedAt.toLocal(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ConflictChoice.later),
              child: const Text('後で'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ConflictChoice.keepRemote),
              child: const Text('クラウドを採用'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_ConflictChoice.keepLocal),
              child: const Text('ローカルを採用'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final supabaseConfig = ref.watch(supabaseConfigProvider);
    final userIdAsync = ref.watch(authUserIdStreamProvider);
    final pendingConflicts = ref.watch(syncConflictsProvider);

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
          if (pendingConflicts.isNotEmpty)
            ListTile(
              title: Text('未解決の競合: ${pendingConflicts.length}件'),
              trailing: FilledButton(
                onPressed: () async {
                  final service = ref.read(syncServiceProvider);
                  if (service == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('同期にはログインが必要です')),
                    );
                    return;
                  }
                  final resolved =
                      await _resolveConflicts(service, pendingConflicts);
                  if (!mounted) return;
                  if (resolved) {
                    ref.read(syncConflictsProvider.notifier).state = [];
                  }
                },
                child: const Text('解決する'),
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
          if (Platform.isMacOS) ...[
            ListTile(
              title: const Text('macOS: 表示/非表示（ダブルタップ）'),
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
            ListTile(
              title: const Text('macOS: 表示/非表示（通常キーバインド）'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(settings.macShowHideKeyBinding?.displayLabel() ?? '未設定'),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _selectKeyBinding(
                      title: '表示/非表示のキーバインド',
                      onChanged: (binding) async {
                        await ref
                            .read(appSettingsProvider.notifier)
                            .setMacShowHideKeyBinding(binding);
                      },
                    ),
                    child: const Text('設定'),
                  ),
                  TextButton(
                    onPressed: settings.macShowHideKeyBinding == null
                        ? null
                        : () => ref
                            .read(appSettingsProvider.notifier)
                            .setMacShowHideKeyBinding(null),
                    child: const Text('クリア'),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 32),
          Text('表示', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('本文の文字数を表示'),
            value: settings.charCountEnabled,
            onChanged: (v) =>
                ref.read(appSettingsProvider.notifier).setCharCountEnabled(v),
          ),
          SwitchListTile(
            title: const Text('句読点・記号を除外してカウント'),
            value: settings.charCountExcludeSymbols,
            onChanged: settings.charCountEnabled
                ? (v) => ref
                    .read(appSettingsProvider.notifier)
                    .setCharCountExcludeSymbols(v)
                : null,
          ),
          const Divider(height: 32),
          Text('AI', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (Platform.isMacOS || Platform.isIOS)
            SwitchListTile(
              title: const Text('Apple Intelligenceを有効化'),
              value: settings.aiAppleIntelligenceEnabled,
              onChanged: _toggleAppleIntelligence,
            ),
          SwitchListTile(
            title: const Text('外部AI APIを有効化'),
            value: settings.aiExternalApiEnabled,
            onChanged: (v) => ref
                .read(appSettingsProvider.notifier)
                .setAiExternalApiEnabled(v),
          ),
          SwitchListTile(
            title: const Text('AI編集プレビューを表示'),
            value: settings.aiPreviewEnabled,
            onChanged: (v) => ref
                .read(appSettingsProvider.notifier)
                .setAiPreviewEnabled(v),
          ),
          if (Platform.isMacOS)
            ListTile(
              title: const Text('AI編集ショートカット（アプリ内）'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(settings.aiEditKeyBinding?.displayLabel() ?? '未設定'),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _selectKeyBinding(
                      title: 'AI編集ショートカット',
                      onChanged: (binding) async {
                        await ref
                            .read(appSettingsProvider.notifier)
                            .setAiEditKeyBinding(binding);
                      },
                    ),
                    child: const Text('設定'),
                  ),
                  TextButton(
                    onPressed: settings.aiEditKeyBinding == null
                        ? null
                        : () => ref
                            .read(appSettingsProvider.notifier)
                            .setAiEditKeyBinding(null),
                    child: const Text('クリア'),
                  ),
                ],
              ),
            ),
          ListTile(
            title: const Text('AIプロンプト送信キー'),
            trailing: DropdownButton<AiPromptSendKey>(
              value: settings.aiPromptSendKey,
              onChanged: (v) {
                if (v == null) return;
                ref.read(appSettingsProvider.notifier).setAiPromptSendKey(v);
              },
              items: const [
                DropdownMenuItem(
                  value: AiPromptSendKey.ctrlEnter,
                  child: Text('Ctrl+Enterで送信'),
                ),
                DropdownMenuItem(
                  value: AiPromptSendKey.enter,
                  child: Text('Enterで送信'),
                ),
              ],
            ),
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
            decoration: appInputDecoration(
              labelText: 'APIキーを入力して保存',
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
          const SizedBox(height: 16),
          Text('カスタムプロンプト', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < 6; i++) ...[
            Text('プリセット ${i + 1}'),
            const SizedBox(height: 4),
            TextField(
              controller: _presetNameControllers[i],
              decoration: appInputDecoration(
                labelText: 'プリセット名',
              ),
              onChanged: (_) => _schedulePresetSave(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _presetPromptControllers[i],
              decoration: appInputDecoration(
                labelText: 'プロンプト',
              ),
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => _schedulePresetSave(),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

enum _ConflictChoice {
  keepLocal,
  keepRemote,
  later,
}

class _ConflictSection extends StatelessWidget {
  const _ConflictSection({
    required this.title,
    required this.note,
    required this.updatedAt,
  });

  final String title;
  final Note note;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final displayTitle = note.title.trim().isEmpty ? '（無題）' : note.title.trim();
    final content = note.content.trim().isEmpty ? '（本文なし）' : note.content.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(displayTitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          '更新: ${updatedAt.toString()}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(child: Text(content)),
          ),
        ),
      ],
    );
  }
}
