import 'package:flutter_test/flutter_test.dart';

import 'package:patto/data/models/note.dart';

void main() {
  test('deriveTitleFromContent: empty', () {
    expect(deriveTitleFromContent(''), '');
    expect(deriveTitleFromContent('   \n'), '');
  });

  test('deriveTitleFromContent: first line', () {
    expect(deriveTitleFromContent('Hello\nWorld'), 'Hello');
  });

  test('deriveTitleFromContent: trims and limits', () {
    final title = deriveTitleFromContent('   ${'a' * 200}\nnext');
    expect(title.length, 80);
  });
}
