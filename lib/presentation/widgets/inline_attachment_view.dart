import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/note.dart';
import 'inline_attachment_controller.dart';

class InlineAttachmentView extends StatefulWidget {
  const InlineAttachmentView({
    super.key,
    required this.attachment,
    required this.token,
    required this.maxWidth,
    required this.onResize,
    this.onContextMenu,
    this.onRequestCaret,
  });

  final NoteAttachment attachment;
  final InlineAttachmentToken token;
  final double maxWidth;
  final void Function(InlineAttachmentToken token, Size size) onResize;
  final void Function(Offset globalPosition)? onContextMenu;
  final void Function(InlineAttachmentToken token, bool after)? onRequestCaret;

  @override
  State<InlineAttachmentView> createState() => _InlineAttachmentViewState();
}

class _InlineAttachmentViewState extends State<InlineAttachmentView> {
  static const double _minWidth = 120;
  static const double _minHeight = 90;
  static const double _defaultWidth = 200;
  static const double _defaultHeight = 150;
  static const double _maxHeightRatio = 2.0;
  static const double _handleSize = 14;

  Size? _dragSize;
  bool _isResizing = false;

  @override
  void didUpdateWidget(covariant InlineAttachmentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isResizing) {
      _dragSize = null;
    }
  }

  Size _sizeFromToken() {
    final maxWidth = widget.maxWidth > 0 ? widget.maxWidth : _defaultWidth;
    final minWidth = _minWidth < maxWidth ? _minWidth : maxWidth;
    final width = (widget.token.width ?? _defaultWidth)
        .clamp(minWidth, maxWidth);
    final maxHeight = maxWidth * _maxHeightRatio;
    final height = (widget.token.height ?? _defaultHeight)
        .clamp(_minHeight, maxHeight);
    return Size(width.toDouble(), height.toDouble());
  }

  Size _clampResize(Size size) {
    final maxWidth = widget.maxWidth > 0 ? widget.maxWidth : _defaultWidth;
    final minWidth = _minWidth < maxWidth ? _minWidth : maxWidth;
    final maxHeight = maxWidth * _maxHeightRatio;
    final width = size.width.clamp(minWidth, maxWidth);
    final height = size.height.clamp(_minHeight, maxHeight);
    return Size(width.toDouble(), height.toDouble());
  }

  void _startResize(DragStartDetails details) {
    setState(() {
      _isResizing = true;
      _dragSize = _sizeFromToken();
    });
  }

  void _updateResize(DragUpdateDetails details) {
    final current = _dragSize ?? _sizeFromToken();
    final next = _clampResize(
      Size(
        current.width + details.delta.dx,
        current.height + details.delta.dy,
      ),
    );
    setState(() => _dragSize = next);
    widget.onResize(widget.token, next);
  }

  void _endResize(DragEndDetails details) {
    setState(() => _isResizing = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = _dragSize ?? _sizeFromToken();
    final file = File(widget.attachment.localPath);
    final maxWidth = widget.maxWidth > 0 ? widget.maxWidth : size.width;

    return SizedBox(
      width: maxWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTapDown: widget.onRequestCaret == null
              ? null
              : (details) {
                  // When clicking on the image span, ask the editor to place the
                  // caret on either side of the token (prevents "stuck in token").
                  final after = details.localPosition.dx >= size.width / 2;
                  widget.onRequestCaret!(widget.token, after);
                },
          onSecondaryTapDown: widget.onContextMenu == null
              ? null
              : (details) => widget.onContextMenu!(details.globalPosition),
          onLongPressStart: widget.onContextMenu == null
              ? null
              : (details) => widget.onContextMenu!(details.globalPosition),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                    child: Image.file(
                      file,
                      width: size.width,
                      height: size.height,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => SizedBox(
                        width: size.width,
                        height: size.height,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpLeftDownRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: _startResize,
                      onPanUpdate: _updateResize,
                      onPanEnd: _endResize,
                      child: SizedBox(
                        width: _handleSize,
                        height: _handleSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.8),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.drag_handle,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
