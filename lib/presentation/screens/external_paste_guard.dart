import 'dart:async';

import 'package:flutter/material.dart';

class ExternalPasteGuard {
  ExternalPasteGuard({
    required TextEditingController controller,
    required FocusNode focusNode,
    Duration minDelay = const Duration(milliseconds: 180),
    Duration inputGuard = const Duration(milliseconds: 700),
  })  : _controller = controller,
        _focusNode = focusNode,
        _minDelay = minDelay,
        _inputGuard = inputGuard;

  final TextEditingController _controller;
  final FocusNode _focusNode;
  final Duration _minDelay;
  final Duration _inputGuard;

  Timer? _timer;
  String? _pendingContent;
  DateTime? _lastUserInputAt;
  bool _isExternalPasting = false;

  bool get isExternalPasting => _isExternalPasting;

  void dispose() {
    _timer?.cancel();
  }

  void onTextChanged() {
    if (_isExternalPasting) return;
    _lastUserInputAt = DateTime.now();
    final pending = _pendingContent;
    if (pending != null && _isContentAlreadyInserted(pending)) {
      _pendingContent = null;
      _timer?.cancel();
    }
  }

  void queueExternalPaste(String content, VoidCallback onApplied) {
    if (!_focusNode.hasFocus) return;
    if (_isContentAlreadyInserted(content)) {
      _pendingContent = null;
      _timer?.cancel();
      return;
    }

    _pendingContent = content;
    _timer?.cancel();

    var delay = _minDelay;
    final lastInput = _lastUserInputAt;
    if (lastInput != null) {
      final elapsed = DateTime.now().difference(lastInput);
      if (elapsed < _inputGuard) {
        final remaining = _inputGuard - elapsed;
        if (remaining > delay) {
          delay = remaining;
        }
      }
    }

    _timer = Timer(delay, () {
      if (!_focusNode.hasFocus) return;
      final pending = _pendingContent;
      if (pending == null || pending.isEmpty) return;
      if (_isContentAlreadyInserted(pending)) {
        _pendingContent = null;
        return;
      }
      _applyExternalPaste(pending);
      _pendingContent = null;
      onApplied();
    });
  }

  void _applyExternalPaste(String content) {
    final selection = _controller.selection;
    final text = _controller.text;

    _isExternalPasting = true;
    try {
      if (selection.isValid) {
        final newText = text.replaceRange(selection.start, selection.end, content);
        _controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start + content.length),
        );
      } else {
        _controller.text = text + content;
      }
    } finally {
      _isExternalPasting = false;
    }
  }

  bool _isContentAlreadyInserted(String content) {
    final selection = _controller.selection;
    if (!selection.isValid) return false;
    final text = _controller.text;
    if (selection.isCollapsed) {
      final end = selection.start;
      final start = end - content.length;
      if (start < 0) return false;
      return text.substring(start, end) == content;
    }
    final start = selection.start;
    final end = selection.end;
    if (end - start != content.length) return false;
    return text.substring(start, end) == content;
  }
}
