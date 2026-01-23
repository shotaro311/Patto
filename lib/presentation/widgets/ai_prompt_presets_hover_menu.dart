import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/app_settings.dart';

enum AiEditScope {
  full,
  selection,
  cursor,
}

class AiPromptPresetsHoverMenu extends StatefulWidget {
  const AiPromptPresetsHoverMenu({
    super.key,
    required this.presets,
    required this.enabled,
    required this.scope,
    required this.canUseSelection,
    required this.onScopeChanged,
    required this.onSelect,
    this.runningIndex,
    this.onCancelRunning,
    this.closeOnSelect = true,
    this.keepOpenWhileRunning = false,
  });

  final List<AiPromptPreset> presets;
  final bool enabled;
  final AiEditScope scope;
  final bool canUseSelection;
  final void Function(AiEditScope scope) onScopeChanged;
  final void Function(AiPromptPreset preset, int index) onSelect;
  final int? runningIndex;
  final VoidCallback? onCancelRunning;
  final bool closeOnSelect;
  final bool keepOpenWhileRunning;

  @override
  State<AiPromptPresetsHoverMenu> createState() =>
      _AiPromptPresetsHoverMenuState();
}

class _AiPromptPresetsHoverMenuState extends State<AiPromptPresetsHoverMenu> {
  final _link = LayerLink();
  final _overlayKey = GlobalKey<_AiPromptPresetsOverlayState>();
  OverlayEntry? _entry;
  Timer? _closeTimer;

  List<AiPromptPreset> get _items =>
      widget.presets.where((p) => !p.isEmpty).toList(growable: false);

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _scheduleClose() {
    _cancelClose();
    if (widget.keepOpenWhileRunning && widget.runningIndex != null) return;
    _closeTimer = Timer(const Duration(milliseconds: 120), _close);
  }

  void _open() {
    _cancelClose();
    if (_entry != null) return;
    if (_items.isEmpty) return;

    final overlay = Overlay.of(context, rootOverlay: true);

    _entry = OverlayEntry(
      builder: (context) {
        return _AiPromptPresetsOverlay(
          key: _overlayKey,
          link: _link,
          enabled: widget.enabled,
          scope: widget.scope,
          canUseSelection: widget.canUseSelection,
          onScopeChanged: widget.onScopeChanged,
          presets: _items,
          runningIndex: widget.runningIndex,
          onCancelRunning: widget.onCancelRunning,
          onSelect: (preset, index) {
            widget.onSelect(preset, index);
            if (widget.closeOnSelect) {
              _close();
            }
          },
          onTapOutside: _close,
          onHoverEnter: _cancelClose,
          onHoverExit: _scheduleClose,
          onDismissed: () {
            _entry?.remove();
            _entry = null;
          },
        );
      },
    );
    overlay.insert(_entry!);
  }

  void _close() {
    _cancelClose();
    _overlayKey.currentState?.dismiss();
  }

  @override
  void dispose() {
    _cancelClose();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _open(),
        onExit: (_) => _scheduleClose(),
        child: Tooltip(
          message: widget.enabled ? 'カスタムプロンプト' : 'AI編集は設定で有効化してください',
          child: IconButton(
            onPressed: widget.enabled ? _open : null,
            icon: const Icon(Icons.playlist_play),
          ),
        ),
      ),
    );
  }
}

class _AiPromptPresetsOverlay extends StatefulWidget {
  const _AiPromptPresetsOverlay({
    super.key,
    required this.link,
    required this.enabled,
    required this.scope,
    required this.canUseSelection,
    required this.onScopeChanged,
    required this.presets,
    required this.onSelect,
    required this.runningIndex,
    required this.onCancelRunning,
    required this.onTapOutside,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onDismissed,
  });

  final LayerLink link;
  final bool enabled;
  final AiEditScope scope;
  final bool canUseSelection;
  final void Function(AiEditScope scope) onScopeChanged;
  final List<AiPromptPreset> presets;
  final void Function(AiPromptPreset preset, int index) onSelect;
  final int? runningIndex;
  final VoidCallback? onCancelRunning;
  final VoidCallback onTapOutside;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final VoidCallback onDismissed;

  @override
  State<_AiPromptPresetsOverlay> createState() =>
      _AiPromptPresetsOverlayState();
}

class _AiPromptPresetsOverlayState extends State<_AiPromptPresetsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.forward();
  }

  Future<void> dismiss() async {
    if (_closing) return;
    _closing = true;
    try {
      await _controller.reverse();
    } finally {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onTapOutside,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          offset: const Offset(0, 44),
          child: MouseRegion(
            onEnter: (_) => widget.onHoverEnter(),
            onExit: (_) => widget.onHoverExit(),
            child: FadeTransition(
              opacity: _curve,
              child: ClipRect(
                child: SizeTransition(
                  sizeFactor: _curve,
                  axisAlignment: -1,
                  child: Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surface,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _ScopeChip(
                                    label: '全文対象',
                                    selected: widget.scope == AiEditScope.full,
                                    onTap: () => widget
                                        .onScopeChanged(AiEditScope.full),
                                  ),
                                  const SizedBox(width: 6),
                                  _ScopeChip(
                                    label: '選択部分',
                                    selected:
                                        widget.scope == AiEditScope.selection,
                                    onTap: widget.canUseSelection
                                        ? () => widget.onScopeChanged(
                                              AiEditScope.selection,
                                            )
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  _ScopeChip(
                                    label: 'カーソル',
                                    selected:
                                        widget.scope == AiEditScope.cursor,
                                    onTap: () => widget
                                        .onScopeChanged(AiEditScope.cursor),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            for (var index = 0;
                                index < widget.presets.length;
                                index++)
                              InkWell(
                                onTap: widget.enabled
                                    ? () =>
                                        widget.onSelect(widget.presets[index], index)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.auto_fix_high, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.presets[index].name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ),
                                      if (widget.runningIndex == index)
                                        _InlineCancelLoader(
                                          onCancel: widget.onCancelRunning,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
        ),
      ),
    );
  }
}

class _InlineCancelLoader extends StatelessWidget {
  const _InlineCancelLoader({this.onCancel});

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'クリックでキャンセル',
      child: InkWell(
        onTap: onCancel,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
              Icon(
                Icons.close,
                size: 12,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
