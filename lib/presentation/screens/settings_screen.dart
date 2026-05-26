// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/config/env.dart';
import '../../core/providers.dart';
import '../../data/models/note.dart';
import '../../domain/app_settings.dart';
import '../../services/ai_service.dart';
import '../../services/sync_service.dart';
import '../providers/ai_providers.dart';
import '../providers/app_settings_controller.dart';
import '../providers/auth_providers.dart';
import '../providers/note_repository_provider.dart';
import '../providers/sync_providers.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/patto_surface.dart';
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

    final hasModifier =
        event.isMetaPressed ||
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
  final _scrollController = ScrollController();
  final _syncSectionKey = GlobalKey();
  final _quickLaunchSectionKey = GlobalKey();
  final _displaySectionKey = GlobalKey();
  final _tagSectionKey = GlobalKey();
  final _aiSectionKey = GlobalKey();
  final _editPromptSectionKey = GlobalKey();
  final _titlePromptSectionKey = GlobalKey();
  final _chatPromptSectionKey = GlobalKey();
  final _aiKeyController = TextEditingController();
  final _aiBaseUrlController = TextEditingController();
  final _aiModelController = TextEditingController();
  final _aiImageLimitController = TextEditingController();
  final _aiBaseUrlFocus = FocusNode();
  final _aiModelFocus = FocusNode();
  final _aiImageLimitFocus = FocusNode();
  final _presetNameControllers = List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(),
  );
  final _presetPromptControllers = List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(),
  );
  final _titleRuleNameControllers = List<TextEditingController>.generate(
    3,
    (_) => TextEditingController(),
  );
  final _titleRulePromptControllers = List<TextEditingController>.generate(
    3,
    (_) => TextEditingController(),
  );
  final _chatSystemPromptNameControllers = List<TextEditingController>.generate(
    3,
    (_) => TextEditingController(),
  );
  final _chatSystemPromptControllers = List<TextEditingController>.generate(
    3,
    (_) => TextEditingController(),
  );
  Timer? _presetDebounce;
  Timer? _titleRuleDebounce;
  Timer? _chatSystemPromptDebounce;
  Timer? _aiConnectionDebounce;
  Timer? _aiImageLimitDebounce;
  var _aiKeyVisible = false;
  var _aiKeyRegistered = false;
  var _syncing = false;
  var _selectedSection = _SettingsSection.sync;
  var _localModelsLoading = false;
  String? _localModelsError;
  String _lastLocalModelsRequestKey = '';
  List<String> _localModels = const [];

  @override
  void initState() {
    super.initState();
    _syncPresetControllers(ref.read(appSettingsProvider).aiPromptPresets);
    _syncTitleRuleControllers(ref.read(appSettingsProvider).aiTitleRules);
    _syncChatSystemPromptControllers(
      ref.read(appSettingsProvider).aiChatSystemPrompts,
    );
    _syncAiConnectionControllers(ref.read(appSettingsProvider));
    _aiImageLimitController.text = ref
        .read(appSettingsProvider)
        .aiImageSendLimit
        .toString();
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
    _scrollController.dispose();
    _aiKeyController.dispose();
    _aiBaseUrlController.dispose();
    _aiModelController.dispose();
    _aiBaseUrlFocus.dispose();
    _aiModelFocus.dispose();
    _aiImageLimitDebounce?.cancel();
    _aiConnectionDebounce?.cancel();
    _aiImageLimitController.dispose();
    _aiImageLimitFocus.dispose();
    for (final controller in _presetNameControllers) {
      controller.dispose();
    }
    for (final controller in _presetPromptControllers) {
      controller.dispose();
    }
    for (final controller in _titleRuleNameControllers) {
      controller.dispose();
    }
    for (final controller in _titleRulePromptControllers) {
      controller.dispose();
    }
    for (final controller in _chatSystemPromptNameControllers) {
      controller.dispose();
    }
    for (final controller in _chatSystemPromptControllers) {
      controller.dispose();
    }
    _presetDebounce?.cancel();
    _titleRuleDebounce?.cancel();
    _chatSystemPromptDebounce?.cancel();
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

  void _syncTitleRuleControllers(List<AiTitleRule> rules) {
    for (var i = 0; i < _titleRuleNameControllers.length; i++) {
      final rule = i < rules.length
          ? rules[i]
          : const AiTitleRule(name: '', prompt: '');
      if (_titleRuleNameControllers[i].text != rule.name) {
        _titleRuleNameControllers[i].text = rule.name;
      }
      if (_titleRulePromptControllers[i].text != rule.prompt) {
        _titleRulePromptControllers[i].text = rule.prompt;
      }
    }
  }

  void _scheduleTitleRuleSave() {
    _titleRuleDebounce?.cancel();
    _titleRuleDebounce = Timer(const Duration(milliseconds: 300), () {
      final rules = List<AiTitleRule>.generate(
        3,
        (index) => AiTitleRule(
          name: _titleRuleNameControllers[index].text,
          prompt: _titleRulePromptControllers[index].text,
        ),
      );
      ref.read(appSettingsProvider.notifier).setAiTitleRules(rules);
    });
  }

  void _syncChatSystemPromptControllers(List<AiChatSystemPrompt> prompts) {
    for (var i = 0; i < _chatSystemPromptNameControllers.length; i++) {
      final prompt = i < prompts.length
          ? prompts[i]
          : const AiChatSystemPrompt(name: '', prompt: '');
      if (_chatSystemPromptNameControllers[i].text != prompt.name) {
        _chatSystemPromptNameControllers[i].text = prompt.name;
      }
      if (_chatSystemPromptControllers[i].text != prompt.prompt) {
        _chatSystemPromptControllers[i].text = prompt.prompt;
      }
    }
  }

  void _scheduleChatSystemPromptSave() {
    _chatSystemPromptDebounce?.cancel();
    _chatSystemPromptDebounce = Timer(const Duration(milliseconds: 300), () {
      final prompts = List<AiChatSystemPrompt>.generate(
        3,
        (index) => AiChatSystemPrompt(
          name: _chatSystemPromptNameControllers[index].text,
          prompt: _chatSystemPromptControllers[index].text,
        ),
      );
      ref.read(appSettingsProvider.notifier).setAiChatSystemPrompts(prompts);
    });
  }

  void _syncAiConnectionControllers(AppSettings settings) {
    if (!_aiBaseUrlFocus.hasFocus &&
        _aiBaseUrlController.text != settings.aiExternalBaseUrl) {
      _aiBaseUrlController.text = settings.aiExternalBaseUrl;
    }
    if (!_aiModelFocus.hasFocus &&
        _aiModelController.text != settings.aiExternalModel) {
      _aiModelController.text = settings.aiExternalModel;
    }
  }

  void _scheduleAiConnectionSave() {
    _aiConnectionDebounce?.cancel();
    _aiConnectionDebounce = Timer(const Duration(milliseconds: 300), () {
      final controller = ref.read(appSettingsProvider.notifier);
      controller.setAiExternalBaseUrl(_aiBaseUrlController.text);
      controller.setAiExternalModel(_aiModelController.text);
    });
  }

  String _localModelsRequestKey(AppSettings settings) {
    return '${settings.aiExternalProvider.name}|${settings.aiExternalBaseUrl.trim()}';
  }

  Future<void> _loadLocalModels({
    bool showFeedback = false,
    bool force = false,
  }) async {
    final settings = ref.read(appSettingsProvider);
    if (settings.aiExternalProvider != AiExternalProvider.openAiCompatible) {
      return;
    }
    final requestKey = _localModelsRequestKey(settings);
    if (!force &&
        (_localModelsLoading || _lastLocalModelsRequestKey == requestKey)) {
      return;
    }

    setState(() {
      _localModelsLoading = true;
      _localModelsError = null;
      _lastLocalModelsRequestKey = requestKey;
    });

    try {
      final models = await ref.read(aiServiceProvider).fetchLocalModels();
      if (!mounted) return;

      setState(() {
        _localModelsLoading = false;
        _localModels = models;
        _localModelsError = models.isEmpty ? 'モデルが見つかりませんでした' : null;
      });

      final current = ref.read(appSettingsProvider).aiExternalModel.trim();
      if (models.isNotEmpty && !models.contains(current)) {
        await ref
            .read(appSettingsProvider.notifier)
            .setAiExternalModel(models.first);
      }

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('モデル一覧を更新しました')));
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is AiException ? e.message : 'モデル一覧の取得に失敗しました';
      setState(() {
        _localModelsLoading = false;
        _localModels = const [];
        _localModelsError = message;
      });
      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void _scheduleAutoLoadLocalModels(AppSettings settings) {
    if (settings.aiExternalProvider != AiExternalProvider.openAiCompatible) {
      return;
    }
    final requestKey = _localModelsRequestKey(settings);
    if (settings.aiExternalBaseUrl.trim().isEmpty ||
        requestKey == _lastLocalModelsRequestKey) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadLocalModels();
    });
  }

  void _syncAiImageLimit(int limit) {
    if (_aiImageLimitFocus.hasFocus) return;
    final next = limit.toString();
    if (_aiImageLimitController.text != next) {
      _aiImageLimitController.text = next;
    }
  }

  void _scheduleAiImageLimitSave(String raw) {
    _aiImageLimitDebounce?.cancel();
    _aiImageLimitDebounce = Timer(const Duration(milliseconds: 300), () {
      final parsed = int.tryParse(raw.trim());
      if (parsed == null) return;
      ref.read(appSettingsProvider.notifier).setAiImageSendLimit(parsed);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AI APIキーの保存に失敗しました')));
        return;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI APIキーの保存に失敗しました')));
      return;
    }
    if (!mounted) return;
    setState(() {
      _aiKeyRegistered = true;
      _aiKeyController.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI APIキーを保存しました')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI APIキーを削除しました')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('同期にはログインが必要です')));
      return;
    }

    setState(() => _syncing = true);
    ref.read(syncInProgressProvider.notifier).state = true;
    try {
      final settings = ref.read(appSettingsProvider);
      final result = await service.syncNow(lastSyncAt: settings.lastSyncAt);
      if (result.lastSyncAt != null) {
        await ref
            .read(appSettingsProvider.notifier)
            .setLastSyncAt(result.lastSyncAt);
      }

      if (result.conflictDetails.isNotEmpty && mounted) {
        final resolved = await _resolveConflicts(
          service,
          result.conflictDetails,
        );
        if (resolved && mounted) {
          ref.read(syncConflictsProvider.notifier).state = [];
        }
      }

      if (!mounted) return;
      final msg = result.conflicts > 0
          ? '同期完了（競合: ${result.conflicts}）'
          : '同期完了';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('同期エラー: $e')));
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
        ref.read(syncConflictsProvider.notifier).state = conflicts.sublist(i);
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
              onPressed: () =>
                  Navigator.of(context).pop(_ConflictChoice.keepRemote),
              child: const Text('クラウドを採用'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(_ConflictChoice.keepLocal),
              child: const Text('ローカルを採用'),
            ),
          ],
        );
      },
    );
  }

  GlobalKey _keyForSection(_SettingsSection section) {
    switch (section) {
      case _SettingsSection.sync:
        return _syncSectionKey;
      case _SettingsSection.quickLaunch:
        return _quickLaunchSectionKey;
      case _SettingsSection.display:
        return _displaySectionKey;
      case _SettingsSection.tags:
        return _tagSectionKey;
      case _SettingsSection.ai:
        return _aiSectionKey;
      case _SettingsSection.editPrompts:
        return _editPromptSectionKey;
      case _SettingsSection.titlePrompts:
        return _titlePromptSectionKey;
      case _SettingsSection.chatPrompts:
        return _chatPromptSectionKey;
    }
  }

  Future<void> _jumpToSection(_SettingsSection section) async {
    if (_selectedSection != section && mounted) {
      setState(() => _selectedSection = section);
    }
    final targetKey = _keyForSection(section);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final renderObject = targetKey.currentContext?.findRenderObject();
    if (renderObject == null || !_scrollController.hasClients) return;
    await _scrollController.position.ensureVisible(
      renderObject,
      alignment: 0.04,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  List<({String label, IconData icon, _SettingsSection section})>
  get _sectionNavItems => [
    (label: '同期', icon: Icons.sync, section: _SettingsSection.sync),
    (
      label: '起動と操作',
      icon: Icons.flash_on_outlined,
      section: _SettingsSection.quickLaunch,
    ),
    (
      label: '表示',
      icon: Icons.visibility_outlined,
      section: _SettingsSection.display,
    ),
    (label: 'タグ', icon: Icons.sell_outlined, section: _SettingsSection.tags),
    (label: 'AI', icon: Icons.auto_awesome, section: _SettingsSection.ai),
    (
      label: '編集プリセット',
      icon: Icons.tune_outlined,
      section: _SettingsSection.editPrompts,
    ),
    (
      label: 'タイトル付け',
      icon: Icons.smart_toy_outlined,
      section: _SettingsSection.titlePrompts,
    ),
    (
      label: 'AIチャット文面',
      icon: Icons.chat_bubble_outline,
      section: _SettingsSection.chatPrompts,
    ),
  ];

  Widget _buildSectionCard({
    required BuildContext context,
    required GlobalKey key,
    required String title,
    String? description,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return PattoSurface(
      key: key,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      floating: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildGroupLabel(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptEditorCard({
    required BuildContext context,
    required String title,
    required String nameLabel,
    required TextEditingController nameController,
    required String nameHint,
    required TextEditingController promptController,
    required String promptLabel,
    required String promptHint,
    required VoidCallback onChanged,
    String? helperText,
    int minPromptLines = 2,
    int maxPromptLines = 4,
  }) {
    final theme = Theme.of(context);
    return PattoSurface(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      muted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            decoration: appInputDecoration(
              labelText: nameLabel,
              hintText: nameHint,
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: promptController,
            decoration: appInputDecoration(
              labelText: promptLabel,
              hintText: promptHint,
            ),
            minLines: minPromptLines,
            maxLines: maxPromptLines,
            onChanged: (_) => onChanged(),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 8),
            Text(
              helperText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopNav() {
    return SizedBox(
      width: 208,
      child: PattoSurface(
        margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        floating: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
              child: Text(
                '設定メニュー',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final item in _sectionNavItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    backgroundColor: _selectedSection == item.section
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    foregroundColor: _selectedSection == item.section
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => _jumpToSection(item.section),
                  icon: Icon(item.icon, size: 18),
                  label: Text(item.label),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        bottom: false,
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
                child: Text(
                  '設定メニュー',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final item in _sectionNavItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      backgroundColor: _selectedSection == item.section
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      foregroundColor: _selectedSection == item.section
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(_jumpToSection(item.section));
                    },
                    icon: Icon(item.icon, size: 18),
                    label: Text(item.label),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required AppThemeStyle value,
    required AppThemeStyle selected,
    required String title,
    required String description,
    required List<Color> previewColors,
  }) {
    final isSelected = value == selected;
    return PattoSurface(
      selected: isSelected,
      muted: !isSelected,
      floating: isSelected,
      onTap: () => ref.read(appSettingsProvider.notifier).setThemeStyle(value),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final color in previewColors) ...[
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                if (color != previewColors.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    _syncAiConnectionControllers(settings);
    _syncAiImageLimit(settings.aiImageSendLimit);
    _syncChatSystemPromptControllers(settings.aiChatSystemPrompts);
    _scheduleAutoLoadLocalModels(settings);
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final supabaseConfig = ref.watch(supabaseConfigProvider);
    final userIdAsync = ref.watch(authUserIdStreamProvider);
    final pendingConflicts = ref.watch(syncConflictsProvider);
    const contextWindowOptions = aiChatContextWindowOptions;
    final localModelOptions = <String>{
      if (settings.aiExternalModel.trim().isNotEmpty)
        settings.aiExternalModel.trim(),
      ..._localModels,
    }.toList(growable: false);
    final syncSection = _buildSectionCard(
      context: context,
      key: _syncSectionKey,
      title: '同期',
      description: 'ログイン状態と同期の実行、競合解決をまとめています。',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('同期を有効化（ログイン時のみ）'),
          subtitle: supabaseConfig == null
              ? const Text('Supabaseが未設定です（SUPABASE_URL / SUPABASE_ANON_KEY）')
              : null,
          value: settings.syncEnabled,
          onChanged: supabaseConfig == null ? null : _toggleSync,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
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
          contentPadding: EdgeInsets.zero,
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
            contentPadding: EdgeInsets.zero,
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
                final resolved = await _resolveConflicts(
                  service,
                  pendingConflicts,
                );
                if (!mounted) return;
                if (resolved) {
                  ref.read(syncConflictsProvider.notifier).state = [];
                }
              },
              child: const Text('解決する'),
            ),
          ),
      ],
    );

    final quickLaunchSection = _buildSectionCard(
      context: context,
      key: _quickLaunchSectionKey,
      title: '起動とショートカット',
      description: '起動時の開き方と、macOS の表示ショートカットを設定します。',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
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
            contentPadding: EdgeInsets.zero,
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
            contentPadding: EdgeInsets.zero,
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
      ],
    );

    final displaySection = _buildSectionCard(
      context: context,
      key: _displaySectionKey,
      title: '表示',
      description: '本文まわりの見え方を調整します。',
      children: [
        _buildGroupLabel(
          context,
          title: '明るさ',
          description: 'ライト表示とダーク表示を切り替えます。',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ダークモード'),
          subtitle: const Text('背景や面の色を暗めに切り替えます。'),
          value: settings.darkModeEnabled,
          onChanged: (value) =>
              ref.read(appSettingsProvider.notifier).setDarkModeEnabled(value),
        ),
        const SizedBox(height: 12),
        _buildGroupLabel(
          context,
          title: 'テーマ',
          description: '見た目の柔らかさを 2 つのスタイルから選べます。',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final options = [
              _buildThemeOption(
                context: context,
                value: AppThemeStyle.softPastel,
                selected: settings.themeStyle,
                title: 'Soft Pastel',
                description: 'ミントとピーチのやわらかな雰囲気',
                previewColors: const [
                  Color(0xFFDCEDE2),
                  Color(0xFFF4E3D8),
                  Color(0xFFDCE9F0),
                ],
              ),
              _buildThemeOption(
                context: context,
                value: AppThemeStyle.plainSoft,
                selected: settings.themeStyle,
                title: 'Plain Soft',
                description: '生成りとグレージュの落ち着いた雰囲気',
                previewColors: const [
                  Color(0xFFDCE4EE),
                  Color(0xFFEFE2D2),
                  Color(0xFFDCEBE4),
                ],
              ),
            ];
            if (constraints.maxWidth < 720) {
              return Column(
                children: [options[0], const SizedBox(height: 12), options[1]],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: options[0]),
                const SizedBox(width: 12),
                Expanded(child: options[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('本文の文字数を表示'),
          value: settings.charCountEnabled,
          onChanged: (v) =>
              ref.read(appSettingsProvider.notifier).setCharCountEnabled(v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('句読点・記号を除外してカウント'),
          value: settings.charCountExcludeSymbols,
          onChanged: settings.charCountEnabled
              ? (v) => ref
                    .read(appSettingsProvider.notifier)
                    .setCharCountExcludeSymbols(v)
              : null,
        ),
      ],
    );

    final tagSection = _buildSectionCard(
      context: context,
      key: _tagSectionKey,
      title: 'タグ',
      description: '登録済みタグの確認と編集を行います。',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('タグ管理'),
          subtitle: const Text('登録済みタグの確認と編集'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pushNamed('/tags'),
        ),
      ],
    );

    final aiSection = _buildSectionCard(
      context: context,
      key: _aiSectionKey,
      title: 'AI',
      description: 'AI接続、送信ルール、ショートカットを設定します。',
      children: [
        if (Platform.isMacOS || Platform.isIOS)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Apple Intelligenceを有効化'),
            value: settings.aiAppleIntelligenceEnabled,
            onChanged: _toggleAppleIntelligence,
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('外部AI APIを有効化'),
          value: settings.aiExternalApiEnabled,
          onChanged: (v) =>
              ref.read(appSettingsProvider.notifier).setAiExternalApiEnabled(v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('接続方式'),
          trailing: DropdownButton<AiExternalProvider>(
            value: settings.aiExternalProvider,
            onChanged: (value) {
              if (value == null) return;
              ref
                  .read(appSettingsProvider.notifier)
                  .setAiExternalProvider(value);
            },
            items: const [
              DropdownMenuItem(
                value: AiExternalProvider.gemini,
                child: Text('Gemini'),
              ),
              DropdownMenuItem(
                value: AiExternalProvider.openAiCompatible,
                child: Text('ローカルLLM'),
              ),
            ],
          ),
        ),
        if (settings.aiExternalProvider == AiExternalProvider.openAiCompatible)
          TextField(
            controller: _aiBaseUrlController,
            focusNode: _aiBaseUrlFocus,
            decoration: appInputDecoration(
              labelText: 'ベースURL',
              hintText: 'http://127.0.0.1:1234/v1',
            ),
            onChanged: (_) => _scheduleAiConnectionSave(),
          ),
        if (settings.aiExternalProvider == AiExternalProvider.openAiCompatible)
          const SizedBox(height: 10),
        if (settings.aiExternalProvider == AiExternalProvider.gemini)
          TextField(
            controller: _aiModelController,
            focusNode: _aiModelFocus,
            decoration: appInputDecoration(
              labelText: 'モデル',
              hintText: Env.aiModelName,
            ),
            onChanged: (_) => _scheduleAiConnectionSave(),
          ),
        if (settings.aiExternalProvider == AiExternalProvider.openAiCompatible)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value:
                          localModelOptions.contains(
                            settings.aiExternalModel.trim(),
                          )
                          ? settings.aiExternalModel.trim()
                          : null,
                      decoration: appInputDecoration(
                        labelText: 'モデル',
                        hintText: 'モデルを選択',
                      ),
                      items: [
                        for (final model in localModelOptions)
                          DropdownMenuItem(
                            value: model,
                            child: Text(model, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged:
                          _localModelsLoading || localModelOptions.isEmpty
                          ? null
                          : (value) {
                              if (value == null) return;
                              _aiModelController.text = value;
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setAiExternalModel(value);
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'モデル一覧を更新',
                    onPressed: _localModelsLoading
                        ? null
                        : () =>
                              _loadLocalModels(force: true, showFeedback: true),
                    icon: _localModelsLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (_localModelsError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _localModelsError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_localModelsError == null &&
                  !_localModelsLoading &&
                  localModelOptions.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'ベースURLからモデル一覧を取得できると、ここで選択できます。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        if (settings.aiExternalProvider == AiExternalProvider.openAiCompatible)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('ローカルLLMのコンテキストウィンドウ'),
            subtitle: const Text('AIチャット送信時の上限目安'),
            trailing: DropdownButton<int>(
              value:
                  contextWindowOptions.contains(
                    settings.aiChatContextWindowSize,
                  )
                  ? settings.aiChatContextWindowSize
                  : contextWindowOptions.first,
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(appSettingsProvider.notifier)
                    .setAiChatContextWindowSize(value);
              },
              items: [
                for (final option in contextWindowOptions)
                  DropdownMenuItem(value: option, child: Text('$option')),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('AI編集ダイアログのプレビューを表示'),
          value: settings.aiPreviewEnabled,
          onChanged: (v) =>
              ref.read(appSettingsProvider.notifier).setAiPreviewEnabled(v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('AIに送る画像の最大枚数'),
          subtitle: const Text('メモ上部のトグルがONのときに適用'),
          trailing: SizedBox(
            width: 72,
            child: TextField(
              controller: _aiImageLimitController,
              focusNode: _aiImageLimitFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: appInputDecoration(isDense: true, hintText: '例: 3'),
              onChanged: _scheduleAiImageLimitSave,
            ),
          ),
        ),
        if (Platform.isMacOS)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('AIチャットショートカット（アプリ内）'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(settings.aiEditKeyBinding?.displayLabel() ?? '未設定'),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _selectKeyBinding(
                    title: 'AIチャットショートカット',
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
          contentPadding: EdgeInsets.zero,
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
          contentPadding: EdgeInsets.zero,
          title: const Text('AI APIキー'),
          subtitle: Text(
            settings.aiExternalProvider == AiExternalProvider.openAiCompatible
                ? (_aiKeyRegistered ? '登録済み（未設定でも利用可）' : '未登録（任意）')
                : (_aiKeyRegistered ? '登録済み' : '未登録'),
          ),
          trailing: _aiKeyRegistered
              ? TextButton(onPressed: _deleteAiKey, child: const Text('削除'))
              : null,
        ),
        TextField(
          controller: _aiKeyController,
          obscureText: !_aiKeyVisible,
          decoration: appInputDecoration(
            labelText:
                settings.aiExternalProvider ==
                    AiExternalProvider.openAiCompatible
                ? 'APIキー（必要な場合のみ）'
                : 'APIキーを入力して保存',
            suffixIcon: IconButton(
              tooltip: _aiKeyVisible ? '隠す' : '表示',
              onPressed: () => setState(() => _aiKeyVisible = !_aiKeyVisible),
              icon: Icon(
                _aiKeyVisible ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _saveAiKey, child: const Text('保存')),
        ),
      ],
    );

    final editPromptSection = _buildSectionCard(
      context: context,
      key: _editPromptSectionKey,
      title: '編集プリセット',
      description: 'AI編集で呼び出すプリセットをまとめて管理します。',
      children: [
        for (var i = 0; i < 6; i++)
          _buildPromptEditorCard(
            context: context,
            title: 'プリセット ${i + 1}',
            nameLabel: 'プリセット名',
            nameController: _presetNameControllers[i],
            nameHint: '例: 要約',
            promptController: _presetPromptControllers[i],
            promptLabel: 'プロンプト',
            promptHint: '例: この本文を簡潔に要約する',
            onChanged: _schedulePresetSave,
          ),
      ],
    );

    final titlePromptSection = _buildSectionCard(
      context: context,
      key: _titlePromptSectionKey,
      title: 'タイトル付けプロンプト',
      description: 'タイトル横のロボットボタンから使うルールです。',
      children: [
        for (var i = 0; i < 3; i++)
          _buildPromptEditorCard(
            context: context,
            title: 'ルール ${i + 1}',
            nameLabel: 'ルール名',
            nameController: _titleRuleNameControllers[i],
            nameHint: '例: 日記',
            promptController: _titleRulePromptControllers[i],
            promptLabel: 'ルール内容',
            promptHint: '例: {{today}} を先頭に付けて、本文の要点を10文字以内でまとめる',
            onChanged: _scheduleTitleRuleSave,
            helperText: '{{today}} は 20260413 形式で展開されます',
          ),
      ],
    );

    final chatPromptSection = _buildSectionCard(
      context: context,
      key: _chatPromptSectionKey,
      title: 'AIチャットプロンプト',
      description: 'AIチャット画面のヘッダーから切り替える設定です。本文参照はチャット上部のアイコンでON/OFFできます。',
      children: [
        for (var i = 0; i < 3; i++)
          _buildPromptEditorCard(
            context: context,
            title: 'システムプロンプト ${i + 1}',
            nameLabel: '表示名',
            nameController: _chatSystemPromptNameControllers[i],
            nameHint: '例: 標準',
            promptController: _chatSystemPromptControllers[i],
            promptLabel: 'システムプロンプト',
            promptHint: '例: メモ本文を参考に、編集案を簡潔に返す',
            onChanged: _scheduleChatSystemPromptSave,
            minPromptLines: 2,
            maxPromptLines: 5,
          ),
      ],
    );

    final scrollableContent = Scrollbar(
      controller: _scrollController,
      thumbVisibility: isWide,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              syncSection,
              quickLaunchSection,
              displaySection,
              tagSection,
              aiSection,
              editPromptSection,
              titlePromptSection,
              chatPromptSection,
            ],
          ),
        ),
      ),
    );

    final bodyContent = isWide
        ? Row(
            children: [
              _buildDesktopNav(),
              const VerticalDivider(width: 1),
              Expanded(child: scrollableContent),
            ],
          )
        : scrollableContent;

    return Scaffold(
      drawer: isWide ? null : _buildMobileNavDrawer(context),
      appBar: AppBar(title: const Text('設定')),
      body: bodyContent,
    );
  }
}

enum _SettingsSection {
  sync,
  quickLaunch,
  display,
  tags,
  ai,
  editPrompts,
  titlePrompts,
  chatPrompts,
}

enum _ConflictChoice { keepLocal, keepRemote, later }

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
    final content = note.content.trim().isEmpty
        ? '（本文なし）'
        : note.content.trim();

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
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
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
