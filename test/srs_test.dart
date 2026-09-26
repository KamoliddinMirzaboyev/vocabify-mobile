import 'package:flutter_test/flutter_test.dart';
import 'package:vocabify_app/core/utils/srs.dart';
import 'package:vocabify_app/models/deck_model.dart';
import 'package:vocabify_app/models/card_model.dart';
import 'package:vocabify_app/models/profile_model.dart';

void main() {
  group('SRS Algorithm SM-2 Tests', () {
    test('Initial rating Again resets repetitions and interval', () {
      final initial = SrsState(
        easeFactor: 2.5,
        intervalDays: 10,
        repetitions: 3,
      );

      final next = SrsAlgorithm.scheduleNext(initial, Rating.again);
      expect(next.repetitions, 0);
      expect(next.intervalDays, 1);
      expect(next.easeFactor, lessThan(2.5));
    });

    test('First successful review gives 1 day interval', () {
      final initial = SrsState(
        easeFactor: 2.5,
        intervalDays: 0,
        repetitions: 0,
      );

      final next = SrsAlgorithm.scheduleNext(initial, Rating.good);
      expect(next.repetitions, 1);
      expect(next.intervalDays, 1);
      expect(next.easeFactor, 2.5);
    });

    test('Second successful review gives 6 days interval', () {
      final initial = SrsState(
        easeFactor: 2.5,
        intervalDays: 1,
        repetitions: 1,
      );

      final next = SrsAlgorithm.scheduleNext(initial, Rating.good);
      expect(next.repetitions, 2);
      expect(next.intervalDays, 6);
    });

    test('Third successful review multiplies interval by easeFactor', () {
      final initial = SrsState(
        easeFactor: 2.5,
        intervalDays: 6,
        repetitions: 2,
      );

      final next = SrsAlgorithm.scheduleNext(initial, Rating.good);
      expect(next.repetitions, 3);
      expect(next.intervalDays, (6 * 2.5).round()); // 15
    });

    test('Ease factor does not drop below 1.3', () {
      var state = SrsState(easeFactor: 1.4, intervalDays: 1, repetitions: 0);
      for (int i = 0; i < 5; i++) {
        state = SrsAlgorithm.scheduleNext(state, Rating.again);
      }
      expect(state.easeFactor, greaterThanOrEqualTo(1.3));
    });
  });

  group('Model Serialization Tests', () {
    test('DeckModel serialization round-trip', () {
      final now = DateTime.now();
      final deck = DeckModel(
        id: 'deck-123',
        userId: 'user-456',
        name: 'IELTS Vocabulary',
        description: 'Advanced words',
        icon: '📚',
        color: 'indigo',
        cardCount: 25,
        createdAt: now,
        updatedAt: now,
      );

      final json = deck.toJson();
      final parsed = DeckModel.fromJson(json);

      expect(parsed.id, deck.id);
      expect(parsed.name, deck.name);
      expect(parsed.icon, deck.icon);
      expect(parsed.cardCount, deck.cardCount);
    });

    test('CardModel serialization round-trip', () {
      final now = DateTime.now();
      final card = CardModel(
        id: 'card-1',
        userId: 'user-1',
        deckId: 'deck-1',
        word: 'ubiquitous',
        translation: 'hamma joyda mavjud',
        easeFactor: 2.5,
        intervalDays: 6,
        repetitions: 2,
        dueDate: '2026-10-01',
        totalReviews: 2,
        correctReviews: 2,
        createdAt: now,
        updatedAt: now,
      );

      final json = card.toJson();
      final parsed = CardModel.fromJson(json);

      expect(parsed.id, card.id);
      expect(parsed.word, card.word);
      expect(parsed.translation, card.translation);
      expect(parsed.intervalDays, 6);
    });

    test('ProfileModel serialization round-trip', () {
      final now = DateTime.now();
      final profile = ProfileModel(
        id: 'user-1',
        displayName: 'Kamoliddin',
        dailyGoal: 30,
        currentStreak: 5,
        longestStreak: 12,
        lastStudyDate: '2026-09-25',
        createdAt: now,
        updatedAt: now,
      );

      final json = profile.toJson();
      final parsed = ProfileModel.fromJson(json);

      expect(parsed.id, profile.id);
      expect(parsed.displayName, 'Kamoliddin');
      expect(parsed.dailyGoal, 30);
      expect(parsed.currentStreak, 5);
      expect(parsed.longestStreak, 12);
    });
  });
}
