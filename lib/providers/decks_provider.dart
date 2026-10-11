import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/services/supabase_service.dart';
import '../core/services/offline_queue_service.dart';
import '../core/services/cache_service.dart';
import '../models/deck_model.dart';

class DecksProvider extends ChangeNotifier {
  List<DeckModel> _decks = [];
  bool _isLoading = false;
  bool _isInitialLoading = false;
  Future<void>? _loadFuture;
  String? _loadedUserId;
  DateTime? _loadedAt;
  int _generation = 0;

  List<DeckModel> get decks => _decks;
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isInitialLoading;

  void clear() {
    _decks = [];
    _isLoading = false;
    _isInitialLoading = false;
    _loadFuture = null;
    _loadedUserId = null;
    _loadedAt = null;
    _generation += 1;
    notifyListeners();
  }

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

  Future<void> loadDecks(String? userId, {bool force = false}) {
    if (userId == null || userId.isEmpty) return Future<void>.value();
    if (_loadFuture != null) return _loadFuture!;
    final loadedRecently =
        _loadedUserId == userId &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(seconds: 30);
    if (!force && loadedRecently) return Future<void>.value();

    final future = _loadDecks(userId, _generation);
    _loadFuture = future;
    return future.whenComplete(() {
      if (identical(_loadFuture, future)) _loadFuture = null;
    });
  }

  Future<void> _loadDecks(String userId, int generation) async {
    // Fast-path: Hydrate from cache immediately for 0ms rendering
    if (_decks.isEmpty) {
      final cached = await CacheService.instance.getCachedDecks();
      if (cached.isNotEmpty) {
        _decks = cached;
        notifyListeners();
      }
    }

    _isInitialLoading = _decks.isEmpty;
    _isLoading = true;
    notifyListeners();

    try {
      final res = await SupabaseService.client
          .from('decks')
          .select(
            'id, user_id, name, description, icon, color, created_at, updated_at, cards(count)',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 4));

      final list = (res as List)
          .map((e) => DeckModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (generation != _generation) return;
      _decks = list;
      _loadedUserId = userId;
      _loadedAt = DateTime.now();
      await CacheService.instance.cacheDecks(_decks);
    } catch (e) {
      debugPrint('Error loading decks: $e');
      if (generation != _generation) return;
      if (_decks.isEmpty) {
        _decks = await CacheService.instance.getCachedDecks();
      }
    } finally {
      _isInitialLoading = false;
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
          rows: [newDeck.toDbMap()],
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
    await CacheService.instance.removeDeckCardsCache(deckId);

    try {
      await OfflineQueueService.instance.queuedWrite(
        QueuedOp(kind: OpKind.delete, table: 'decks', match: {'id': deckId}),
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
