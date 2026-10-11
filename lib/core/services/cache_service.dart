import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/card_model.dart';
import '../../models/deck_model.dart';
import '../../models/profile_model.dart';
import '../../models/stats_data_model.dart';

class CacheService {
  static final CacheService instance = CacheService._internal();
  CacheService._internal();

  static const String _keyProfile = 'vocabify_cache_profile_v2';
  static const String _keyDecks = 'vocabify_cache_decks_v2';
  static const String _keyAllCards = 'vocabify_cache_all_cards_v2';
  static const String _keyDeckCardsPrefix = 'vocabify_cache_deck_cards_v2_';
  static const String _keyStats = 'vocabify_cache_stats_v2';

  SharedPreferences? _prefs;
  String? _activeUserId;

  /// Switches all cache reads/writes to an isolated user namespace.
  void activateUser(String? userId) {
    _activeUserId = userId;
  }

  String _scopedKey(String base) => '${base}_${_activeUserId ?? 'signed_out'}';
  String _scopedKeyFor(String base, String? userId) =>
      '${base}_${userId ?? 'signed_out'}';
  String _deckCardsKey(String deckId) =>
      '$_keyDeckCardsPrefix${_activeUserId ?? 'signed_out'}_$deckId';

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ================= PROFILE CACHE =================
  Future<void> cacheProfile(ProfileModel profile) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = jsonEncode(profile.toJson());
      await prefs.setString(_scopedKey(_keyProfile), jsonStr);
    } catch (e) {
      debugPrint('Error caching profile: $e');
    }
  }

  Future<ProfileModel?> getCachedProfile() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_scopedKey(_keyProfile));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ProfileModel.fromJson(map);
    } catch (e) {
      debugPrint('Error reading cached profile: $e');
      return null;
    }
  }

  // ================= DECKS CACHE =================
  Future<void> cacheDecks(List<DeckModel> decks) async {
    try {
      final prefs = await _getPrefs();
      final list = decks.map((d) => d.toJson()).toList();
      await prefs.setString(_scopedKey(_keyDecks), jsonEncode(list));
    } catch (e) {
      debugPrint('Error caching decks: $e');
    }
  }

  Future<List<DeckModel>> getCachedDecks() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_scopedKey(_keyDecks));
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => DeckModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error reading cached decks: $e');
      return [];
    }
  }

  // ================= ALL CARDS CACHE =================
  Future<void> cacheAllCards(List<CardModel> cards) async {
    try {
      final prefs = await _getPrefs();
      final list = cards.map((c) => c.toJson()).toList();
      await prefs.setString(_scopedKey(_keyAllCards), jsonEncode(list));
    } catch (e) {
      debugPrint('Error caching all cards: $e');
    }
  }

  Future<List<CardModel>> getCachedAllCards() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_scopedKey(_keyAllCards));
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => CardModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error reading cached all cards: $e');
      return [];
    }
  }

  // ================= DECK CARDS CACHE =================
  Future<void> cacheDeckCards(String deckId, List<CardModel> cards) async {
    try {
      final prefs = await _getPrefs();
      final list = cards.map((c) => c.toJson()).toList();
      await prefs.setString(_deckCardsKey(deckId), jsonEncode(list));
    } catch (e) {
      debugPrint('Error caching deck cards for $deckId: $e');
    }
  }

  Future<List<CardModel>> getCachedDeckCards(String deckId) async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_deckCardsKey(deckId));
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => CardModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error reading cached deck cards for $deckId: $e');
      return [];
    }
  }

  Future<void> removeDeckCardsCache(String deckId) async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_deckCardsKey(deckId));
    } catch (e) {
      debugPrint('Error removing deck cards cache for $deckId: $e');
    }
  }

  Future<void> updateSingleCachedCard(CardModel updatedCard) async {
    try {
      // 1. Update in deck cards cache
      final deckCards = await getCachedDeckCards(updatedCard.deckId);
      final idx = deckCards.indexWhere((c) => c.id == updatedCard.id);
      if (idx != -1) {
        deckCards[idx] = updatedCard;
        await cacheDeckCards(updatedCard.deckId, deckCards);
      }
      // 2. Update in all cards cache
      final allCards = await getCachedAllCards();
      final allIdx = allCards.indexWhere((c) => c.id == updatedCard.id);
      if (allIdx != -1) {
        allCards[allIdx] = updatedCard;
        await cacheAllCards(allCards);
      }
    } catch (e) {
      debugPrint('Error updating single cached card: $e');
    }
  }

  // ================= STATS CACHE =================
  Future<void> cacheStats(StatsDataModel stats) async {
    try {
      final prefs = await _getPrefs();
      final map = {
        'streak': stats.streak,
        'longest': stats.longest,
        'goal': stats.goal,
        'totalCards': stats.totalCards,
        'totalReviews': stats.totalReviews,
        'correctReviews': stats.correctReviews,
        'reviewsToday': stats.reviewsToday,
        'accuracy': stats.accuracy,
        'dueToday': stats.dueToday,
        'mastered': stats.mastered,
        'learning': stats.learning,
        'newCards': stats.newCards,
        'ratingCounts': {
          'again': stats.ratingCounts.again,
          'hard': stats.ratingCounts.hard,
          'good': stats.ratingCounts.good,
          'easy': stats.ratingCounts.easy,
        },
        'last7': stats.last7
            .map((e) => {'date': e.date, 'count': e.count})
            .toList(),
        'troubleWords': stats.troubleWords.map((e) => e.toJson()).toList(),
      };
      await prefs.setString(_scopedKey(_keyStats), jsonEncode(map));
    } catch (e) {
      debugPrint('Error caching stats: $e');
    }
  }

  Future<StatsDataModel?> getCachedStats() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_scopedKey(_keyStats));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;

      final ratingMap = map['ratingCounts'] as Map<String, dynamic>?;
      final last7List = (map['last7'] as List?) ?? [];
      final troubleList = (map['troubleWords'] as List?) ?? [];

      return StatsDataModel(
        streak: (map['streak'] as num?)?.toInt() ?? 0,
        longest: (map['longest'] as num?)?.toInt() ?? 0,
        goal: (map['goal'] as num?)?.toInt() ?? 20,
        totalCards: (map['totalCards'] as num?)?.toInt() ?? 0,
        totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
        correctReviews: (map['correctReviews'] as num?)?.toInt() ?? 0,
        reviewsToday: (map['reviewsToday'] as num?)?.toInt() ?? 0,
        accuracy: (map['accuracy'] as num?)?.toInt() ?? 0,
        dueToday: (map['dueToday'] as num?)?.toInt() ?? 0,
        mastered: (map['mastered'] as num?)?.toInt() ?? 0,
        learning: (map['learning'] as num?)?.toInt() ?? 0,
        newCards: (map['newCards'] as num?)?.toInt() ?? 0,
        ratingCounts: RatingCounts(
          again: (ratingMap?['again'] as num?)?.toInt() ?? 0,
          hard: (ratingMap?['hard'] as num?)?.toInt() ?? 0,
          good: (ratingMap?['good'] as num?)?.toInt() ?? 0,
          easy: (ratingMap?['easy'] as num?)?.toInt() ?? 0,
        ),
        last7: last7List
            .map(
              (e) => DailyCount(
                date: e['date'] as String? ?? '',
                count: (e['count'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList(),
        troubleWords: troubleList
            .map((e) => TroubleCardItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      debugPrint('Error reading cached stats: $e');
      return null;
    }
  }

  // ================= CLEAR USER CACHE ON LOGOUT =================
  Future<void> clearUserCache({String? userId}) async {
    try {
      final prefs = await _getPrefs();
      final targetUserId = userId ?? _activeUserId;
      await prefs.remove(_scopedKeyFor(_keyProfile, targetUserId));
      await prefs.remove(_scopedKeyFor(_keyDecks, targetUserId));
      await prefs.remove(_scopedKeyFor(_keyAllCards, targetUserId));
      await prefs.remove(_scopedKeyFor(_keyStats, targetUserId));

      // Remove legacy unscoped keys left by older app versions.
      await prefs.remove(_keyProfile);
      await prefs.remove(_keyDecks);
      await prefs.remove(_keyAllCards);
      await prefs.remove(_keyStats);

      // Remove all deck cards keys
      final userDeckPrefix =
          '$_keyDeckCardsPrefix${targetUserId ?? 'signed_out'}_';
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(userDeckPrefix))
          .toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('Error clearing user cache: $e');
    }
  }
}
