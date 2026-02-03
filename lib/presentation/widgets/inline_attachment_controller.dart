import 'package:flutter/material.dart';

import '../../data/models/note.dart';

typedef AttachmentSpanBuilder = Widget Function(
  BuildContext context,
  NoteAttachment attachment,
  InlineAttachmentToken token,
);

class InlineAttachmentToken {
  InlineAttachmentToken({
    required this.id,
    required this.start,
    required this.end,
    this.width,
    this.height,
  });

  final String id;
  final int start;
  final int end;
  final double? width;
  final double? height;
}

class InlineAttachmentEditingController extends TextEditingController {
  InlineAttachmentEditingController({
    super.text,
    required AttachmentSpanBuilder attachmentBuilder,
  }) : _attachmentBuilder = attachmentBuilder;

  final AttachmentSpanBuilder _attachmentBuilder;
  Map<String, NoteAttachment> _attachmentsById = const {};

  static final RegExp tokenPattern =
      RegExp(r'!\[image\]\(attachment:([^)]+)\)');

  bool _sanitizing = false;
  TextSelection? _lastSelection;
  bool _suppressSanitizeOnce = false;

  static String buildToken(
    String id, {
    double? width,
    double? height,
  }) {
    if (width == null || height == null) {
      return '![image](attachment:$id)';
    }
    final w = width.round();
    final h = height.round();
    return '![image](attachment:$id?w=$w&h=$h)';
  }

  void setAttachments(List<NoteAttachment> attachments) {
    _attachmentsById = {
      for (final attachment in attachments) attachment.id: attachment,
    };
  }

  void setCaretAtTokenEdge(InlineAttachmentToken token, {required bool after}) {
    final offset = after ? token.end : token.start;
    _suppressSanitizeOnce = true;
    value = value.copyWith(
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  @override
  set value(TextEditingValue newValue) {
    if (_sanitizing) {
      super.value = newValue;
      return;
    }
    if (_suppressSanitizeOnce) {
      _suppressSanitizeOnce = false;
      super.value = newValue;
      _lastSelection = newValue.selection;
      return;
    }
    final sanitized = _sanitizeSelection(newValue, previous: _lastSelection);
    _sanitizing = true;
    super.value = sanitized;
    _sanitizing = false;
    _lastSelection = sanitized.selection;
  }

  void replaceAttachmentToken(
    InlineAttachmentToken token, {
    required double width,
    required double height,
  }) {
    final current = value.text;
    if (token.start < 0 ||
        token.end < token.start ||
        token.end > current.length) {
      return;
    }
    final nextToken =
        buildToken(token.id, width: width, height: height);
    final nextText = current.replaceRange(token.start, token.end, nextToken);
    final selection = value.selection;
    final delta = nextToken.length - (token.end - token.start);
    if (!selection.isValid) {
      value = value.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(
          offset: (token.start + nextToken.length).clamp(0, nextText.length),
        ),
      );
      return;
    }
    var base = selection.baseOffset;
    var extent = selection.extentOffset;
    if (base > token.end) {
      base += delta;
    } else if (base > token.start) {
      base = token.start + nextToken.length;
    }
    if (extent > token.end) {
      extent += delta;
    } else if (extent > token.start) {
      extent = token.start + nextToken.length;
    }
    value = value.copyWith(
      text: nextText,
      selection: TextSelection(baseOffset: base, extentOffset: extent),
    );
  }

  TextEditingValue _sanitizeSelection(
    TextEditingValue next, {
    required TextSelection? previous,
  }) {
    final selection = next.selection;
    if (!selection.isValid || selection.baseOffset < 0) return next;
    final text = next.text;
    if (text.isEmpty) return next;

    if (selection.isCollapsed) {
      final snapped = _snapCollapsed(
        selection.baseOffset,
        text,
        previous,
      );
      if (snapped == selection.baseOffset) return next;
      return next.copyWith(
        selection: TextSelection.collapsed(offset: snapped),
      );
    }

    var base = selection.baseOffset;
    var extent = selection.extentOffset;
    for (final match in tokenPattern.allMatches(text)) {
      base = _snapOffset(
        base,
        match.start,
        match.end,
        previous: previous,
        requested: base,
      );
      extent = _snapOffset(
        extent,
        match.start,
        match.end,
        previous: previous,
        requested: extent,
      );
    }
    if (base == selection.baseOffset && extent == selection.extentOffset) {
      return next;
    }
    return next.copyWith(
      selection: TextSelection(baseOffset: base, extentOffset: extent),
    );
  }

  int _snapCollapsed(int offset, String text, TextSelection? previous) {
    var next = offset;
    for (final match in tokenPattern.allMatches(text)) {
      next = _snapOffset(
        next,
        match.start,
        match.end,
        previous: previous,
        requested: offset,
      );
    }
    return next;
  }

  int _snapOffset(
    int offset,
    int start,
    int end, {
    required TextSelection? previous,
    required int requested,
  }) {
    if (offset < start || offset > end) return offset;
    if (previous != null && previous.isValid && previous.isCollapsed) {
      final oldOffset = previous.baseOffset;
      // Arrow-key / keyboard navigation should "jump over" the token.
      if (offset == start && oldOffset < start && requested >= start) {
        return end;
      }
      if (offset == end && oldOffset > end && requested <= end) {
        return start;
      }
      if (oldOffset <= start && requested > oldOffset) return end;
      if (oldOffset >= end && requested < oldOffset) return start;
    } else {
      // If we don't know the navigation direction, keep exact edges as-is.
      if (offset == start || offset == end) return offset;
    }
    final distToStart = (offset - start).abs();
    final distToEnd = (end - offset).abs();
    return distToStart <= distToEnd ? start : end;
  }

  InlineAttachmentToken _parseToken(Match match) {
    final raw = match.group(1) ?? '';
    var id = raw;
    double? width;
    double? height;
    final queryIndex = raw.indexOf('?');
    if (queryIndex != -1) {
      id = raw.substring(0, queryIndex);
      final query = raw.substring(queryIndex + 1);
      for (final part in query.split('&')) {
        final pair = part.split('=');
        if (pair.length != 2) continue;
        final key = pair[0];
        final value = double.tryParse(pair[1]);
        if (value == null) continue;
        if (key == 'w') width = value;
        if (key == 'h') height = value;
      }
    }
    return InlineAttachmentToken(
      id: id,
      start: match.start,
      end: match.end,
      width: width,
      height: height,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    final matches = tokenPattern.allMatches(text);
    final composing = withComposing ? value.composing : TextRange.empty;
    final composingValid = withComposing &&
        composing.isValid &&
        !composing.isCollapsed &&
        composing.end <= text.length;
    final composingStyle = style?.merge(
          const TextStyle(decoration: TextDecoration.underline),
        ) ??
        const TextStyle(decoration: TextDecoration.underline);

    final children = <InlineSpan>[];
    void addTextSpan(int start, int end) {
      if (start >= end) return;
      if (!composingValid) {
        children.add(TextSpan(style: style, text: text.substring(start, end)));
        return;
      }
      final composeStart = composing.start;
      final composeEnd = composing.end;
      if (end <= composeStart || start >= composeEnd) {
        children.add(TextSpan(style: style, text: text.substring(start, end)));
        return;
      }
      if (start < composeStart) {
        children.add(
          TextSpan(style: style, text: text.substring(start, composeStart)),
        );
      }
      final highlightStart = start > composeStart ? start : composeStart;
      final highlightEnd = end < composeEnd ? end : composeEnd;
      children.add(
        TextSpan(
          style: composingStyle,
          text: text.substring(highlightStart, highlightEnd),
        ),
      );
      if (highlightEnd < end) {
        children.add(
          TextSpan(style: style, text: text.substring(highlightEnd, end)),
        );
      }
    }

    var last = 0;
    for (final match in matches) {
      if (match.start > last) {
        addTextSpan(last, match.start);
      }
      final token = _parseToken(match);
      final attachment = _attachmentsById[token.id];
      if (attachment == null) {
        addTextSpan(match.start, match.end);
      } else {
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: _attachmentBuilder(context, attachment, token),
          ),
        );
      }
      last = match.end;
    }
    if (last < text.length) {
      addTextSpan(last, text.length);
    }

    if (children.isEmpty) {
      return TextSpan(style: style, text: text);
    }
    return TextSpan(style: style, children: children);
  }
}
