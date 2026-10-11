import 'package:flutter_test/flutter_test.dart';
import 'package:vocabify_app/models/stats_data_model.dart';

void main() {
  group('StatsDataModel & Trouble Words Tests', () {
    test('Calculates wrongReviews correctly', () {
      final stats = StatsDataModel(totalReviews: 25, correctReviews: 18);

      expect(stats.wrongReviews, 7);
    });

    test('TroubleCardItem serialization roundtrip', () {
      final trouble = TroubleCardItem(
        id: 'c-1',
        word: 'meticulous',
        translation: 'o\'ta sinchkov',
        pronunciation: '/məˈtɪkjələs/',
        totalReviews: 5,
        correctReviews: 2,
        wrongReviews: 3,
        errorRate: 60.0,
        easeFactor: 1.8,
      );

      final json = trouble.toJson();
      final fromJson = TroubleCardItem.fromJson(json);

      expect(fromJson.id, 'c-1');
      expect(fromJson.word, 'meticulous');
      expect(fromJson.translation, 'o\'ta sinchkov');
      expect(fromJson.wrongReviews, 3);
      expect(fromJson.errorRate, 60.0);
      expect(fromJson.easeFactor, 1.8);
    });

    test('StatsDataModel with trouble words copyWith and properties', () {
      final trouble1 = TroubleCardItem(
        id: 'c-1',
        word: 'diligent',
        translation: 'mehnatsevar',
        totalReviews: 4,
        correctReviews: 1,
        wrongReviews: 3,
        errorRate: 75.0,
      );

      final stats = StatsDataModel(
        streak: 5,
        longest: 10,
        goal: 20,
        totalCards: 15,
        totalReviews: 20,
        correctReviews: 15,
        reviewsToday: 5,
        accuracy: 75,
        dueToday: 3,
        mastered: 6,
        learning: 5,
        newCards: 4,
        troubleWords: [trouble1],
      );

      expect(stats.streak, 5);
      expect(stats.longest, 10);
      expect(stats.mastered, 6);
      expect(stats.wrongReviews, 5);
      expect(stats.troubleWords.length, 1);
      expect(stats.troubleWords.first.word, 'diligent');

      final updated = stats.copyWith(mastered: 7, troubleWords: []);

      expect(updated.mastered, 7);
      expect(updated.troubleWords, isEmpty);
      expect(updated.streak, 5);
    });
  });
}
