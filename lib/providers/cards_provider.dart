import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/services/supabase_service.dart';
import '../core/services/offline_queue_service.dart';
import '../core/services/cache_service.dart';
import '../core/services/groq_service.dart';
import '../core/utils/srs.dart';
import '../models/card_model.dart';

class CardsProvider extends ChangeNotifier {
  final Map<String, List<CardModel>> _deckCards = {};
  List<CardModel> _allCards = [];
  bool _isLoading = false;

  List<CardModel> getCardsForDeck(String deckId) => _deckCards[deckId] ?? [];
  List<CardModel> get allCards => _allCards;
  bool get isLoading => _isLoading;

  CardsProvider() {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    final cached = await CacheService.instance.getCachedAllCards();
    if (cached.isNotEmpty && _allCards.isEmpty) {
      _allCards = cached;
      notifyListeners();
    }
  }

  Future<void> loadCardsForDeck(String deckId) async {
    // Show cached deck cards immediately
    if (!_deckCards.containsKey(deckId) || _deckCards[deckId]!.isEmpty) {
      final cached = await CacheService.instance.getCachedDeckCards(deckId);
      if (cached.isNotEmpty) {
        _deckCards[deckId] = cached;
        notifyListeners();
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final res = await SupabaseService.client
          .from('cards')
          .select('*')
          .eq('deck_id', deckId)
          .order('created_at', ascending: false);

      final list = (res as List).map((e) => CardModel.fromJson(e as Map<String, dynamic>)).toList();
      _deckCards[deckId] = list;
      await CacheService.instance.cacheDeckCards(deckId, list);
    } catch (e) {
      debugPrint('Error loading cards for deck $deckId: $e');
      if (!_deckCards.containsKey(deckId) || _deckCards[deckId]!.isEmpty) {
        _deckCards[deckId] = await CacheService.instance.getCachedDeckCards(deckId);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAllCards(String userId) async {
    if (_allCards.isEmpty) {
      final cached = await CacheService.instance.getCachedAllCards();
      if (cached.isNotEmpty) {
        _allCards = cached;
        notifyListeners();
      }
    }

    try {
      final res = await SupabaseService.client
          .from('cards')
          .select('id,deck_id,word,translation,due_date,total_reviews,correct_reviews,repetitions,created_at')
          .eq('user_id', userId);

      final list = (res as List).map((e) => CardModel.fromJson(e as Map<String, dynamic>)).toList();
      _allCards = list;
      await CacheService.instance.cacheAllCards(_allCards);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading all cards: $e');
      if (_allCards.isEmpty) {
        _allCards = await CacheService.instance.getCachedAllCards();
        notifyListeners();
      }
    }
  }

  Future<CardModel?> addCard({
    required String userId,
    required String deckId,
    required String word,
    required String translation,
    String? exampleSentence,
    String? pronunciation,
    String? definition,
    String? synonyms,
    String? antonyms,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final today = SrsAlgorithm.todayISO();

    final newCard = CardModel(
      id: id,
      userId: userId,
      deckId: deckId,
      word: word.trim(),
      translation: translation.trim(),
      exampleSentence: exampleSentence?.trim().isEmpty == true ? null : exampleSentence?.trim(),
      pronunciation: pronunciation?.trim().isEmpty == true ? null : pronunciation?.trim(),
      definition: definition?.trim().isEmpty == true ? null : definition?.trim(),
      synonyms: synonyms?.trim().isEmpty == true ? null : synonyms?.trim(),
      antonyms: antonyms?.trim().isEmpty == true ? null : antonyms?.trim(),
      easeFactor: 2.5,
      intervalDays: 0,
      repetitions: 0,
      dueDate: today,
      totalReviews: 0,
      correctReviews: 0,
      createdAt: now,
      updatedAt: now,
    );

    // Optimistic addition
    final currentList = _deckCards[deckId] ?? [];
    _deckCards[deckId] = [newCard, ...currentList];
    _allCards = [newCard, ..._allCards];
    notifyListeners();

    // Cache update
    await CacheService.instance.cacheDeckCards(deckId, _deckCards[deckId]!);
    await CacheService.instance.cacheAllCards(_allCards);

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(
          kind: OpKind.insert,
          table: 'cards',
          rows: [newCard.toJson()],
        ),
      );
      OfflineQueueService.instance.flushQueue();
      return newCard;
    } catch (e) {
      debugPrint('Error inserting card: $e');
      return newCard;
    }
  }

  Future<void> updateCard({
    required String cardId,
    required String deckId,
    required String word,
    required String translation,
    String? exampleSentence,
  }) async {
    final currentList = _deckCards[deckId] ?? [];
    _deckCards[deckId] = currentList.map((c) {
      if (c.id == cardId) {
        return c.copyWith(
          word: word.trim(),
          translation: translation.trim(),
          exampleSentence: exampleSentence?.trim(),
        );
      }
      return c;
    }).toList();

    _allCards = _allCards.map((c) {
      if (c.id == cardId) {
        return c.copyWith(
          word: word.trim(),
          translation: translation.trim(),
          exampleSentence: exampleSentence?.trim(),
        );
      }
      return c;
    }).toList();

    notifyListeners();

    // Cache update
    await CacheService.instance.cacheDeckCards(deckId, _deckCards[deckId]!);
    await CacheService.instance.cacheAllCards(_allCards);

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(
          kind: OpKind.update,
          table: 'cards',
          match: {'id': cardId},
          values: {
            'word': word.trim(),
            'translation': translation.trim(),
            'example_sentence': exampleSentence?.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        ),
      );
      OfflineQueueService.instance.flushQueue();
    } catch (e) {
      debugPrint('Error updating card: $e');
    }
  }

  Future<void> deleteCard(String cardId, String deckId) async {
    final currentList = _deckCards[deckId] ?? [];
    _deckCards[deckId] = currentList.where((c) => c.id != cardId).toList();
    _allCards = _allCards.where((c) => c.id != cardId).toList();
    notifyListeners();

    // Cache update
    await CacheService.instance.cacheDeckCards(deckId, _deckCards[deckId]!);
    await CacheService.instance.cacheAllCards(_allCards);

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(
          kind: OpKind.delete,
          table: 'cards',
          match: {'id': cardId},
        ),
      );
      OfflineQueueService.instance.flushQueue();
    } catch (e) {
      debugPrint('Error deleting card: $e');
    }
  }

  Future<int> bulkImportCards({
    required String userId,
    required String deckId,
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) return 0;
    final today = SrsAlgorithm.todayISO();
    final now = DateTime.now().toIso8601String();

    final rows = items.map((w) {
      final id = const Uuid().v4();
      final word = w['word']?.toString().trim() ?? '';
      final translation = w['translation']?.toString().trim() ?? '';

      String? formatListOrString(dynamic val) {
        if (val == null) return null;
        if (val is List) return val.where((e) => e != null).join(', ');
        return val.toString();
      }

      return {
        'id': id,
        'user_id': userId,
        'deck_id': deckId,
        'word': word,
        'pronunciation': w['pronunciation']?.toString().trim(),
        'translation': translation,
        'definition': w['definition']?.toString().trim(),
        'synonyms': formatListOrString(w['synonyms']),
        'antonyms': formatListOrString(w['antonyms']),
        'example_sentence': (w['example_sentence'] ?? w['example'])?.toString().trim(),
        'ease_factor': 2.5,
        'interval_days': 0,
        'repetitions': 0,
        'due_date': today,
        'total_reviews': 0,
        'correct_reviews': 0,
        'created_at': now,
        'updated_at': now,
      };
    }).toList();

    try {
      await SupabaseService.client.from('cards').insert(rows);
      await loadCardsForDeck(deckId);
      await loadAllCards(userId);
      return rows.length;
    } catch (e) {
      debugPrint('Error in bulk import: $e');
      rethrow;
    }
  }

  /// AI helper to fetch pronunciation, translation, example sentence for a word
  Future<Map<String, dynamic>?> generateWordInfoWithAI(String word) async {
    // 1. First try Supabase edge function
    try {
      final res = await SupabaseService.client.functions.invoke(
        'ai-card-helper',
        body: {'word': word.trim()},
      );

      if (res.status == 200 && res.data != null) {
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (e) {
      debugPrint('Supabase AI helper edge function fallback: $e');
    }

    // 2. Fallback to Groq AI
    try {
      final groqRes = await GroqService.instance.generateWordCardInfo(word);
      if (groqRes != null) return groqRes;
    } catch (e) {
      debugPrint('Groq AI word helper error: $e');
    }

    return null;
  }
}
