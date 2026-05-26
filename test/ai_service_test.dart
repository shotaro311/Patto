import 'package:flutter_test/flutter_test.dart';
import 'package:patto/services/ai_service.dart';

void main() {
  test('expandAiTitleRulePrompt expands today without separators', () {
    final result = expandAiTitleRulePrompt(
      '{{today}}_日記の内容（10文字以内）',
      now: DateTime(2026, 4, 13),
    );

    expect(result, '20260413_日記の内容（10文字以内）');
  });

  test('normalizeAiGeneratedTitle keeps compact leading date', () {
    expect(normalizeAiGeneratedTitle('20260413_日記タイトル'), '20260413_日記タイトル');
  });

  test('normalizeAiGeneratedTitle strips numeric bullet only', () {
    expect(normalizeAiGeneratedTitle('1. 20260413_日記タイトル'), '20260413_日記タイトル');
  });
}
