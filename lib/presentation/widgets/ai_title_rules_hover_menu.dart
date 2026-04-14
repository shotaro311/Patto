import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/app_settings.dart';

class AiTitleRulesHoverMenu extends StatefulWidget {
  const AiTitleRulesHoverMenu({
    super.key,
    required this.rules,
    required this.enabled,
    required this.busy,
    required this.onSelect,
  });

  final List<AiTitleRule> rules;
  final bool enabled;
  final bool busy;
  final void Function(AiTitleRule rule, int index) onSelect;

  @override
  State<AiTitleRulesHoverMenu> createState() => _AiTitleRulesHoverMenuState();
}

class _AiTitleRulesHoverMenuState extends State<AiTitleRulesHoverMenu> {
  final _link = LayerLink();
  final _overlayKey = GlobalKey<_AiTitleRulesOverlayState>();
  OverlayEntry? _entry;
  Timer? _closeTimer;

  List<AiTitleRule> get _items =>
      widget.rules.where((rule) => !rule.isEmpty).toList(growable: false);

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _scheduleClose() {
    _cancelClose();
    _closeTimer = Timer(const Duration(milliseconds: 120), _close);
  }

  void _open() {
    _cancelClose();
    if (_entry != null || _items.length <= 1) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (context) {
        return _AiTitleRulesOverlay(
          key: _overlayKey,
          link: _link,
          enabled: widget.enabled && !widget.busy,
          rules: _items,
          onSelect: (rule, index) {
            widget.onSelect(rule, index);
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
  void didUpdateWidget(covariant AiTitleRulesHoverMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_entry == null) return;
    final nextItems = _items;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entry == null) return;
      _overlayKey.currentState?.syncFromHost(
        enabled: widget.enabled && !widget.busy,
        rules: nextItems,
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
    final hasRules = _items.isNotEmpty;
    final canRun = widget.enabled && !widget.busy && hasRules;
    final canHoverOpen = canRun && _items.length > 1;
    final tooltip = switch ((
      widget.busy,
      widget.enabled,
      hasRules,
      _items.length,
    )) {
      (true, _, _, _) => 'タイトル生成中…',
      (_, false, _, _) => 'AIを設定で有効化してください',
      (_, _, false, _) => 'タイトル付けルールを設定してください',
      (_, _, true, 1) => '本文からタイトルを生成',
      _ => 'タイトル付けルールを選択',
    };

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) {
          if (canHoverOpen) _open();
        },
        onExit: (_) {
          if (canHoverOpen) _scheduleClose();
        },
        child: Tooltip(
          message: tooltip,
          child: IconButton(
            onPressed: !canRun
                ? null
                : () {
                    if (_items.length == 1) {
                      widget.onSelect(_items.first, 0);
                      return;
                    }
                    _open();
                  },
            icon: widget.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.smart_toy_outlined),
          ),
        ),
      ),
    );
  }
}

class _AiTitleRulesOverlay extends StatefulWidget {
  const _AiTitleRulesOverlay({
    super.key,
    required this.link,
    required this.enabled,
    required this.rules,
    required this.onSelect,
    required this.onTapOutside,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.onDismissed,
  });

  final LayerLink link;
  final bool enabled;
  final List<AiTitleRule> rules;
  final void Function(AiTitleRule rule, int index) onSelect;
  final VoidCallback onTapOutside;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final VoidCallback onDismissed;

  @override
  State<_AiTitleRulesOverlay> createState() => _AiTitleRulesOverlayState();
}

class _AiTitleRulesOverlayState extends State<_AiTitleRulesOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  var _closing = false;
  late bool _enabled;
  late List<AiTitleRule> _rules;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    _rules = widget.rules;
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
  void didUpdateWidget(covariant _AiTitleRulesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _enabled = widget.enabled;
    _rules = widget.rules;
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

  void syncFromHost({required bool enabled, required List<AiTitleRule> rules}) {
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _rules = rules;
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
                            for (var index = 0; index < _rules.length; index++)
                              InkWell(
                                onTap: _enabled
                                    ? () =>
                                          widget.onSelect(_rules[index], index)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.smart_toy_outlined,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _rules[index].name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
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
