import 'package:flutter_test/flutter_test.dart';
import 'package:vocabify_app/models/card_model.dart';
import 'package:vocabify_app/core/services/widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetService tests', () {
    test('syncFromCardsAndStreak handles empty cards list gracefully', () async {
      await expectLater(
        WidgetService.syncFromCardsAndStreak(cards: [], streak: 3),
        completes,
      );
    });

    test('syncFromCardsAndStreak selects a due card when available', () async {
      final now = DateTime.now();
      final todayStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final dueCard = CardModel(
        id: '1',
        userId: 'u1',
        deckId: 'd1',
        word: 'Perseverance',
        translation: 'Sabr-matonat',
        pronunciation: '/ˌpɜː.sɪˈvɪə.rəns/',
        exampleSentence: 'Perseverance is key to success.',
        dueDate: todayStr,
      );

      final futureCard = CardModel(
        id: '2',
        userId: 'u1',
        deckId: 'd1',
        word: 'Ephemeral',
        translation: 'O\'tkinchi',
        dueDate: '2099-01-01',
      );

      await expectLater(
        WidgetService.syncFromCardsAndStreak(
          cards: [futureCard, dueCard],
          streak: 5,
        ),
        completes,
      );
    });
  });
}
