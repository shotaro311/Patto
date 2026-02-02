import 'package:flutter/material.dart';

import '../../data/models/note.dart';

typedef AttachmentSpanBuilder = Widget Function(
  BuildContext context,
  NoteAttachment attachment,
);

class InlineAttachmentEditingController extends TextEditingController {
  InlineAttachmentEditingController({
    super.text,
    required AttachmentSpanBuilder attachmentBuilder,
  }) : _attachmentBuilder = attachmentBuilder;

  final AttachmentSpanBuilder _attachmentBuilder;
  Map<String, NoteAttachment> _attachmentsById = const {};

  static final RegExp _tokenPattern =
      RegExp(r'!\[image\]\(attachment:([^)]+)\)');

  void setAttachments(List<NoteAttachment> attachments) {
    _attachmentsById = {
      for (final attachment in attachments) attachment.id: attachment,
    };
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    final matches = _tokenPattern.allMatches(text);
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
      final id = match.group(1);
      final attachment = id == null ? null : _attachmentsById[id];
      if (attachment == null) {
        addTextSpan(match.start, match.end);
      } else {
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _attachmentBuilder(context, attachment),
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
