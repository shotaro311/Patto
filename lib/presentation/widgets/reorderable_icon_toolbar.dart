import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/toolbar_order_provider.dart';

class ToolbarAction {
  const ToolbarAction({
    required this.id,
    required this.builder,
    this.feedback,
  });

  final String id;
  final Widget Function(BuildContext context) builder;
  final Widget Function(BuildContext context)? feedback;
}

class ReorderableIconToolbar extends ConsumerStatefulWidget {
  const ReorderableIconToolbar({
    super.key,
    required this.actions,
  });

  final List<ToolbarAction> actions;

  @override
  ConsumerState<ReorderableIconToolbar> createState() =>
      _ReorderableIconToolbarState();
}

class _ReorderableIconToolbarState
    extends ConsumerState<ReorderableIconToolbar> {
  bool _metaPressed = false;

  @override
  void initState() {
    super.initState();
    _metaPressed = HardwareKeyboard.instance.isMetaPressed;
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    final next = HardwareKeyboard.instance.isMetaPressed;
    if (next != _metaPressed) {
      setState(() => _metaPressed = next);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(toolbarOrderProvider);
    final byId = <String, ToolbarAction>{
      for (final a in widget.actions) a.id: a,
    };
    final orderedIds = <String>[
      for (final id in order)
        if (byId.containsKey(id)) id,
      for (final a in widget.actions)
        if (!order.contains(a.id)) a.id,
    ];

    void reorder(String draggedId, int targetIndex) {
      final subset = List<String>.from(orderedIds);
      final from = subset.indexOf(draggedId);
      if (from < 0) return;
      if (targetIndex < 0 || targetIndex >= subset.length) return;
      if (from == targetIndex) return;
      subset.removeAt(from);
      final insertAt = targetIndex > from ? targetIndex - 1 : targetIndex;
      subset.insert(insertAt.clamp(0, subset.length), draggedId);

      final currentFull = ref.read(toolbarOrderProvider);
      final subsetSet = subset.toSet();
      final nextFull = <String>[
        ...subset,
        for (final id in currentFull)
          if (!subsetSet.contains(id)) id,
      ];
      ref.read(toolbarOrderProvider.notifier).setOrder(nextFull);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < orderedIds.length; i++)
          _CmdDraggableToolbarItem(
            id: orderedIds[i],
            index: i,
            childBuilder: (context) => byId[orderedIds[i]]!.builder(context),
            feedbackBuilder: (context) =>
                byId[orderedIds[i]]!.feedback?.call(context) ??
                byId[orderedIds[i]]!.builder(context),
            onReorder: reorder,
            canDrag: _metaPressed,
          ),
      ],
    );
  }
}

class _CmdDraggableToolbarItem extends StatefulWidget {
  const _CmdDraggableToolbarItem({
    required this.id,
    required this.index,
    required this.childBuilder,
    required this.feedbackBuilder,
    required this.onReorder,
    required this.canDrag,
  });

  final String id;
  final int index;
  final WidgetBuilder childBuilder;
  final WidgetBuilder feedbackBuilder;
  final void Function(String draggedId, int targetIndex) onReorder;
  final bool canDrag;

  @override
  State<_CmdDraggableToolbarItem> createState() =>
      _CmdDraggableToolbarItemState();
}

class _CmdDraggableToolbarItemState extends State<_CmdDraggableToolbarItem> {
  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          details.data != widget.id,
      onAcceptWithDetails: (details) =>
          widget.onReorder(details.data, widget.index),
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        final child = widget.childBuilder(context);

        return Draggable<String>(
          data: widget.id,
          maxSimultaneousDrags: widget.canDrag ? 1 : 0,
          allowedButtonsFilter: (buttons) =>
              buttons == kPrimaryButton || buttons == kSecondaryButton,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 18,
                      color: Colors.black26,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: widget.feedbackBuilder(context),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            decoration: highlighted
                ? BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  )
                : null,
            child: child,
          ),
        );
      },
    );
  }
}
