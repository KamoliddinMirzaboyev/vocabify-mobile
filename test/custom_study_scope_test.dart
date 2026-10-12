import 'package:flutter_test/flutter_test.dart';
import 'package:vocabify_app/models/card_model.dart';
import 'package:vocabify_app/providers/study_provider.dart';

void main() {
  group('Custom Study and Scope Tests', () {
    late List<CardModel> dummyCards;

    setUp(() {
      dummyCards = List.generate(
        60,
        (i) => CardModel(
          id: 'card_$i',
          userId: 'user_1',
          deckId: 'deck_1',
          word: 'Word $i',
          translation: 'Tarjima $i',
          pronunciation: '/wɜːd/',
          definition: 'Definition $i',
          easeFactor: 2.5,
          intervalDays: 1,
          repetitions: 0,
          dueDate: '2026-10-12',
          totalReviews: 0,
          correctReviews: 0,
        ),
      );
    });

    test('StudyProvider.initSession accepts customCards correctly', () async {
      final provider = StudyProvider();
      final subset = dummyCards.sublist(19, 40); // 20 to 40 inclusive (21 items)

      expect(subset.length, 21);

      await provider.initSession(
        userId: 'user_1',
        customCards: subset,
        startInTypingMode: true,
      );

      expect(provider.queue.length, 21);
      expect(provider.queue.first.word, 'Word 19');
      expect(provider.queue.last.word, 'Word 39');
      expect(provider.isTypingMode, isTrue);
      expect(provider.isLoading, isFalse);
    });

    test('Range filtering correctly slices specific bounds (e.g. 20 to 40)', () {
      const rangeStart = 20;
      const rangeEnd = 40;

      final start = (rangeStart - 1).clamp(0, dummyCards.length - 1);
      final end = rangeEnd.clamp(start + 1, dummyCards.length);

      final sliced = dummyCards.sublist(start, end);

      expect(sliced.length, 21);
      expect(sliced.first.word, 'Word 19');
      expect(sliced.last.word, 'Word 39');
    });

    test('Random subset takes requested count without duplicates', () {
      const randomCount = 15;
      final shuffled = List<CardModel>.from(dummyCards)..shuffle();
      final randomSubset = shuffled.take(randomCount).toList();

      expect(randomSubset.length, 15);
      final uniqueIds = randomSubset.map((c) => c.id).toSet();
      expect(uniqueIds.length, 15);
    });
  });
}
