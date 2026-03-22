import 'package:ai_service/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoopAiService', () {
    test('generateHint returns empty string', () async {
      const service = NoopAiService();
      final hint = await service.generateHint(front: 'Q', back: 'A');
      expect(hint, isEmpty);
    });

    test('generateUsageExamples returns empty list', () async {
      const service = NoopAiService();
      final examples = await service.generateUsageExamples(text: 'hello');
      expect(examples, isEmpty);
    });
  });
}
