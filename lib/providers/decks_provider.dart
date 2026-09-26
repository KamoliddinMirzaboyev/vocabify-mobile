import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/services/supabase_service.dart';
import '../core/services/offline_queue_service.dart';
import '../core/services/cache_service.dart';
import '../models/deck_model.dart';

class DecksProvider extends ChangeNotifier {
  List<DeckModel> _decks = [];
  bool _isLoading = false;

  List<DeckModel> get decks => _decks;
  bool get isLoading => _isLoading;

  DecksProvider() {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    final cached = await CacheService.instance.getCachedDecks();
    if (cached.isNotEmpty && _decks.isEmpty) {
      _decks = cached;
      notifyListeners();
    }
  }

  Future<void> loadDecks(String? userId) async {
    if (userId == null || userId.isEmpty) return;

    // If memory is empty, try cache first to avoid blank screen
    if (_decks.isEmpty) {
      final cached = await CacheService.instance.getCachedDecks();
      if (cached.isNotEmpty) {
        _decks = cached;
        notifyListeners();
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final res = await SupabaseService.client
          .from('decks')
          .select('*, cards(count)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = (res as List).map((e) => DeckModel.fromJson(e as Map<String, dynamic>)).toList();
      _decks = list;
      await CacheService.instance.cacheDecks(_decks);
    } catch (e) {
      debugPrint('Error loading decks: $e');
      if (_decks.isEmpty) {
        _decks = await CacheService.instance.getCachedDecks();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DeckModel?> createDeck({
    required String userId,
    required String name,
    String? description,
    required String icon,
    required String color,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    final newDeck = DeckModel(
      id: id,
      userId: userId,
      name: name,
      description: description,
      icon: icon,
      color: color,
      cardCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    // Optimistic addition
    _decks = [newDeck, ..._decks];
    notifyListeners();
    await CacheService.instance.cacheDecks(_decks);

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(
          kind: OpKind.insert,
          table: 'decks',
          rows: [newDeck.toJson()],
        ),
      );
      OfflineQueueService.instance.flushQueue();
      return newDeck;
    } catch (e) {
      debugPrint('Error creating deck: $e');
      return newDeck;
    }
  }

  Future<void> deleteDeck(String deckId, String userId) async {
    _decks = _decks.where((d) => d.id != deckId).toList();
    notifyListeners();
    await CacheService.instance.cacheDecks(_decks);

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(
          kind: OpKind.delete,
          table: 'decks',
          match: {'id': deckId},
        ),
      );
      OfflineQueueService.instance.flushQueue();
    } catch (e) {
      debugPrint('Error deleting deck: $e');
    }
  }

  void updateCardCount(String deckId, int delta) {
    _decks = _decks.map((d) {
      if (d.id == deckId) {
        final newCount = (d.cardCount + delta).clamp(0, 999999);
        return d.copyWith(cardCount: newCount);
      }
      return d;
    }).toList();
    notifyListeners();
    CacheService.instance.cacheDecks(_decks);
  }
}
