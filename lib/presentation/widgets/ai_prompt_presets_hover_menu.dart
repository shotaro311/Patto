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
    required this.onSelect,
    this.runningIndex,
    this.onCancelRunning,
    this.closeOnSelect = true,
    this.keepOpenWhileRunning = false,
  });

  final List<AiPromptPreset> presets;
  final bool enabled;
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
          presets: _items,
          onSelect: (preset, index) {
            widget.onSelect(preset, index);
            _close();
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
  void didUpdateWidget(covariant AiPromptPresetsHoverMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_entry == null) return;
    final nextItems = _items;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entry == null) return;
      _overlayKey.currentState?.syncFromHost(
        enabled: widget.enabled,
        presets: nextItems,
      );
    });
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
    final isRunning = widget.runningIndex != null;
    final canOpen = widget.enabled && !isRunning;

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) {
          if (canOpen) _open();
        },
        onExit: (_) {
          if (!isRunning) _scheduleClose();
        },
        child: Tooltip(
          message: isRunning
              ? 'AI編集中… クリックでキャンセル'
              : widget.enabled
                  ? 'カスタムプロンプト'
                  : 'AI編集は設定で有効化してください',
          child: IconButton(
            onPressed:
                isRunning ? widget.onCancelRunning : (canOpen ? _open : null),
            icon: isRunning
                ? const _InlineCancelLoader()
                : const Icon(Icons.playlist_play),
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
    required this.presets,
    required this.onSelect,
    required this.onTapOutside,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onDismissed,
  });

  final LayerLink link;
  final bool enabled;
  final List<AiPromptPreset> presets;
  final void Function(AiPromptPreset preset, int index) onSelect;
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
  late bool _enabled;
  late List<AiPromptPreset> _presets;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    _presets = widget.presets;
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

  @override
  void didUpdateWidget(covariant _AiPromptPresetsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _enabled = widget.enabled;
    _presets = widget.presets;
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

  void syncFromHost({
    required bool enabled,
    required List<AiPromptPreset> presets,
  }) {
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _presets = presets;
    });
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
                            for (var index = 0;
                                index < _presets.length;
                                index++)
                              InkWell(
                                onTap: _enabled
                                    ? () =>
                                        widget.onSelect(_presets[index], index)
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
                                          _presets[index].name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
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
