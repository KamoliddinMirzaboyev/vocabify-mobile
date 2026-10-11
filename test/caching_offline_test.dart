import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocabify_app/core/services/cache_service.dart';
import 'package:vocabify_app/models/card_model.dart';
import 'package:vocabify_app/models/deck_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CacheService.instance.activateUser('user-1');
  });

  group('CacheService Offline Caching Tests', () {
    test('Can cache and retrieve all cards correctly', () async {
      final cards = [
        CardModel(
          id: 'card-1',
          userId: 'user-1',
          deckId: 'deck-1',
          word: 'flawless',
          translation: 'benuqson',
          exampleSentence: 'The caching was flawless.',
          pronunciation: 'flaw-lis',
          definition: 'without defects',
          synonyms: 'perfect',
          antonyms: 'flawed',
          easeFactor: 2.5,
          intervalDays: 1,
          repetitions: 1,
          dueDate: '2026-10-12',
          totalReviews: 2,
          correctReviews: 2,
        ),
      ];

      await CacheService.instance.cacheAllCards(cards);
      final retrieved = await CacheService.instance.getCachedAllCards();

      expect(retrieved.length, equals(1));
      expect(retrieved.first.word, equals('flawless'));
      expect(retrieved.first.translation, equals('benuqson'));
      expect(
        retrieved.first.exampleSentence,
        equals('The caching was flawless.'),
      );
      expect(retrieved.first.intervalDays, equals(1));
    });

    test(
      'updateSingleCachedCard updates both allCards and deckCards caches',
      () async {
        final card1 = CardModel(
          id: 'c1',
          userId: 'u1',
          deckId: 'd1',
          word: 'serene',
          translation: 'osuda',
          easeFactor: 2.5,
          intervalDays: 0,
          repetitions: 0,
          dueDate: '2026-10-11',
        );

        await CacheService.instance.cacheAllCards([card1]);
        await CacheService.instance.cacheDeckCards('d1', [card1]);

        final updated = card1.copyWith(
          repetitions: 1,
          intervalDays: 1,
          dueDate: '2026-10-12',
          totalReviews: 1,
          correctReviews: 1,
        );

        await CacheService.instance.updateSingleCachedCard(updated);

        final cachedAll = await CacheService.instance.getCachedAllCards();
        final cachedDeck = await CacheService.instance.getCachedDeckCards('d1');

        expect(cachedAll.first.repetitions, equals(1));
        expect(cachedAll.first.dueDate, equals('2026-10-12'));
        expect(cachedDeck.first.intervalDays, equals(1));
      },
    );

    test('removeDeckCardsCache removes deck specific cards', () async {
      final card = CardModel(
        id: 'c2',
        userId: 'u1',
        deckId: 'd2',
        word: 'ancient',
        translation: 'qadimiy',
        dueDate: '2026-10-11',
      );

      await CacheService.instance.cacheDeckCards('d2', [card]);
      var cached = await CacheService.instance.getCachedDeckCards('d2');
      expect(cached.length, equals(1));

      await CacheService.instance.removeDeckCardsCache('d2');
      cached = await CacheService.instance.getCachedDeckCards('d2');
      expect(cached, isEmpty);
    });

    test('Deck caching and retrieval preserves deck info', () async {
      final decks = [
        DeckModel(
          id: 'deck-xyz',
          userId: 'u1',
          name: 'CEFR C1',
          icon: '🎓',
          color: 'violet',
          cardCount: 15,
        ),
      ];

      await CacheService.instance.cacheDecks(decks);
      final retrieved = await CacheService.instance.getCachedDecks();

      expect(retrieved.length, equals(1));
      expect(retrieved.first.name, equals('CEFR C1'));
      expect(retrieved.first.cardCount, equals(15));
    });

    test('cached user data is isolated between authenticated users', () async {
      final userOneCard = CardModel(
        id: 'private-card',
        userId: 'user-1',
        deckId: 'private-deck',
        word: 'private',
        translation: 'maxfiy',
        dueDate: '2026-10-11',
      );

      await CacheService.instance.cacheAllCards([userOneCard]);
      CacheService.instance.activateUser('user-2');

      expect(await CacheService.instance.getCachedAllCards(), isEmpty);
    });

    test(
      'logout clears the original user even after auth namespace changes',
      () async {
        final privateCard = CardModel(
          id: 'logout-card',
          userId: 'user-1',
          deckId: 'logout-deck',
          word: 'private',
          translation: 'maxfiy',
          dueDate: '2026-10-11',
        );

        await CacheService.instance.cacheAllCards([privateCard]);
        CacheService.instance.activateUser(null); // auth event wins the race
        await CacheService.instance.clearUserCache(userId: 'user-1');
        CacheService.instance.activateUser('user-1');

        expect(await CacheService.instance.getCachedAllCards(), isEmpty);
      },
    );
  });
}
