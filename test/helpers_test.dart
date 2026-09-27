import 'package:flutter_test/flutter_test.dart';
import 'package:vocabify_app/core/utils/helpers.dart';
import 'package:vocabify_app/core/services/offline_queue_service.dart';

void main() {
  group('AppHelpers Tests', () {
    test('normalizeAnswer trims, lowercases, and strips punctuation', () {
      expect(AppHelpers.normalizeAnswer('  Hello, World!  '), 'hello world');
      expect(AppHelpers.normalizeAnswer('Ubiquitous...'), 'ubiquitous');
      expect(AppHelpers.normalizeAnswer('apple   banana'), 'apple banana');
    });

    test('maskWord hides target word in sentence with blanks', () {
      final sentence = 'The sun is ubiquitous in summer.';
      final masked = AppHelpers.maskWord(sentence, 'ubiquitous');
      expect(masked, 'The sun is _____ in summer.');
    });

    test('getWordHint provides progressive hint levels', () {
      final word = 'elephant';
      expect(AppHelpers.getWordHint(word, 0), '');
      expect(AppHelpers.getWordHint(word, 1), 'e _ _ _ _ _ _ _');
      final hint2 = AppHelpers.getWordHint(word, 2);
      expect(hint2.startsWith('ele'), isTrue);
    });
  });

  group('OfflineQueueService Model Tests', () {
    test('QueuedOp serialization roundtrip', () {
      final op = QueuedOp(
        kind: OpKind.insert,
        table: 'cards',
        rows: [
          {'id': 'c-1', 'word': 'test'}
        ],
      );
      final json = op.toJson();
      final parsed = QueuedOp.fromJson(json);

      expect(parsed.kind, OpKind.insert);
      expect(parsed.table, 'cards');
      expect(parsed.rows?.first['word'], 'test');
    });
  });
}
