import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocabify_app/core/constants/app_constants.dart';
import 'package:vocabify_app/core/services/cache_service.dart';
import 'package:vocabify_app/models/card_model.dart';
import 'package:vocabify_app/models/deck_model.dart';
import 'package:vocabify_app/providers/cards_provider.dart';
import 'package:vocabify_app/providers/quiz_provider.dart';
import 'package:vocabify_app/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CacheService.instance.activateUser('test-user');
  });

  group('QuizProvider Option Deduplication Tests', () {
    test('Quiz questions have strictly distinct options even with duplicate translations', () {
      final deck = DeckModel(
        id: 'deck-1',
        userId: 'test-user',
        name: 'Test Deck',
      );

      final cards = <CardModel>[
        CardModel(
          id: 'c1',
          userId: 'test-user',
          deckId: 'deck-1',
          word: 'big',
          translation: 'katta',
          dueDate: '2026-10-12',
        ),
        CardModel(
          id: 'c2',
          userId: 'test-user',
          deckId: 'deck-1',
          word: 'large',
          translation: 'katta', // Duplicate translation
          dueDate: '2026-10-12',
        ),
        CardModel(
          id: 'c3',
          userId: 'test-user',
          deckId: 'deck-1',
          word: 'huge',
          translation: 'katta', // Another duplicate
          dueDate: '2026-10-12',
        ),
        CardModel(
          id: 'c4',
          userId: 'test-user',
          deckId: 'deck-1',
          word: 'small',
          translation: 'kichik',
          dueDate: '2026-10-12',
        ),
        CardModel(
          id: 'c5',
          userId: 'test-user',
          deckId: 'deck-1',
          word: 'tiny',
          translation: 'juda kichik',
          dueDate: '2026-10-12',
        ),
      ];

      final quizProvider = QuizProvider();
      quizProvider.initQuiz(deck: deck, cards: cards, direction: 'en-uz');

      for (final q in quizProvider.questions) {
        final uniqueOptions = q.options.map((o) => o.toLowerCase()).toSet();
        expect(
          uniqueOptions.length,
          equals(q.options.length),
          reason: 'Options should not contain duplicate strings: ${q.options}',
        );
        expect(q.options.contains(q.correctAnswer), isTrue);
      }
      quizProvider.clear();
    });
  });

  group('CardsProvider Deck Deletion Cleanup Tests', () {
    test('removeCardsForDeck clears deck cards and filters allCards', () async {
      final card1 = CardModel(
        id: 'c1',
        userId: 'test-user',
        deckId: 'deck-delete',
        word: 'apple',
        translation: 'olma',
        dueDate: '2026-10-12',
      );
      final card2 = CardModel(
        id: 'c2',
        userId: 'test-user',
        deckId: 'deck-keep',
        word: 'book',
        translation: 'kitob',
        dueDate: '2026-10-12',
      );

      await CacheService.instance.cacheAllCards([card1, card2]);
      await CacheService.instance.cacheDeckCards('deck-delete', [card1]);
      await CacheService.instance.cacheDeckCards('deck-keep', [card2]);

      final cardsProvider = CardsProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await cardsProvider.removeCardsForDeck('deck-delete');

      expect(cardsProvider.getCardsForDeck('deck-delete'), isEmpty);
      expect(cardsProvider.allCards.any((c) => c.deckId == 'deck-delete'), isFalse);

      final cachedDeck = await CacheService.instance.getCachedDeckCards('deck-delete');
      expect(cachedDeck, isEmpty);
    });
  });

  group('ThemeProvider Persistence Tests', () {
    test('setThemeMode persists to SharedPreferences', () async {
      final themeProvider = ThemeProvider();
      await themeProvider.setThemeMode(ThemeMode.dark);
      expect(themeProvider.isDark, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.themeKey), equals('dark'));

      await themeProvider.setThemeMode(ThemeMode.light);
      expect(themeProvider.isDark, isFalse);
      expect(prefs.getString(AppConstants.themeKey), equals('light'));
    });
  });
}
