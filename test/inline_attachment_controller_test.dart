import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:patto/data/models/note.dart';
import 'package:patto/presentation/widgets/inline_attachment_controller.dart';

void main() {
  testWidgets('InlineAttachmentEditingController keeps span length aligned', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(textDirection: TextDirection.ltr, child: SizedBox()),
    );
    final context = tester.element(find.byType(SizedBox));

    final controller = InlineAttachmentEditingController(
      attachmentBuilder: (context, attachment, token) => const SizedBox(
        width: 10,
        height: 10,
      ),
    );

    const token = '![image](attachment:abc)';
    controller.text = 'before\n$token\nafter';
    final attachment = NoteAttachment()
      ..id = 'abc'
      ..localPath = '';
    controller.setAttachments([attachment]);

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 14),
      withComposing: false,
    );

    // Selection offsets in EditableText are based on controller.text length,
    // so the rendered span must have the same plain-text length.
    expect(span.toPlainText().length, controller.text.length);
  });

  test('caret snaps over token start when moving forward', () {
    final controller = InlineAttachmentEditingController(
      attachmentBuilder: (context, attachment, token) => const SizedBox(),
    );
    const token = '![image](attachment:abc)';
    final text = 'a\n$token\nb';
    final match = InlineAttachmentEditingController.tokenPattern.firstMatch(
      text,
    )!;

    controller.text = text;
    controller.setAttachments([NoteAttachment()..id = 'abc']);

    // Place caret before token, then simulate navigation landing on start.
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: match.start - 1),
    );
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: match.start),
    );

    expect(controller.selection.baseOffset, match.end);
  });

  test('caret snaps over token end when moving backward', () {
    final controller = InlineAttachmentEditingController(
      attachmentBuilder: (context, attachment, token) => const SizedBox(),
    );
    const token = '![image](attachment:abc)';
    final text = 'a\n$token\nb';
    final match = InlineAttachmentEditingController.tokenPattern.firstMatch(
      text,
    )!;

    controller.text = text;
    controller.setAttachments([NoteAttachment()..id = 'abc']);

    // Place caret after token, then simulate navigation landing on end.
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: match.end + 1),
    );
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: match.end),
    );

    expect(controller.selection.baseOffset, match.start);
  });
}

