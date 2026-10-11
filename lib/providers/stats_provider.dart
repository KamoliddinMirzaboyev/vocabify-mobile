import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/services/supabase_service.dart';
import '../core/services/cache_service.dart';
import '../core/utils/srs.dart';
import '../models/stats_data_model.dart';

class StatsProvider extends ChangeNotifier {
  StatsDataModel _stats = StatsDataModel();
  bool _isLoading = false;
  bool _isInitialLoading = false;
  Future<void>? _loadFuture;
  String? _loadedUserId;
  DateTime? _loadedAt;
  int _generation = 0;

  StatsDataModel get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isInitialLoading;

  void clear() {
    _stats = StatsDataModel();
    _isLoading = false;
    _isInitialLoading = false;
    _loadFuture = null;
    _loadedUserId = null;
    _loadedAt = null;
    _generation += 1;
    notifyListeners();
  }

  StatsProvider() {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    final cached = await CacheService.instance.getCachedStats();
    if (cached != null) {
      _stats = cached;
      notifyListeners();
    }
  }

  Future<void> loadStats(String? userId, {bool force = false}) {
    if (userId == null || userId.isEmpty) return Future<void>.value();
    if (_loadFuture != null) return _loadFuture!;
    final loadedRecently =
        _loadedUserId == userId &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(seconds: 30);
    if (!force && loadedRecently) return Future<void>.value();
    final future = _loadStats(userId, _generation);
    _loadFuture = future;
    return future.whenComplete(() {
      if (identical(_loadFuture, future)) _loadFuture = null;
    });
  }

  Future<void> _loadStats(String userId, int generation) async {
    // Fast-path 1: Load cached stats immediately (0ms)
    if (_stats.totalCards == 0 && _stats.streak == 0) {
      final cached = await CacheService.instance.getCachedStats();
      if (cached != null) {
        _stats = cached;
        notifyListeners();
      }
    }

    // Fast-path 2: If still empty, compute instantly from local cached cards (1ms)
    if (_stats.totalCards == 0) {
      final localCards = await CacheService.instance.getCachedAllCards();
      final cachedProfile = await CacheService.instance.getCachedProfile();
      if (localCards.isNotEmpty) {
        int tRev = 0, cRev = 0, due = 0, mast = 0, learn = 0, brandNew = 0;
        final today = SrsAlgorithm.todayISO();
        final localTroubleList = <TroubleCardItem>[];

        for (final c in localCards) {
          final wrong = c.totalReviews - c.correctReviews;
          tRev += c.totalReviews;
          cRev += c.correctReviews;
          if (c.dueDate.compareTo(today) <= 0) due += 1;
          if (c.repetitions >= 3 && c.dueDate.compareTo(today) > 0) mast += 1;
          if (c.repetitions > 0 && c.repetitions < 3) learn += 1;
          if (c.totalReviews == 0) brandNew += 1;

          if (wrong > 0 && c.totalReviews > 0) {
            localTroubleList.add(
              TroubleCardItem(
                id: c.id,
                word: c.word,
                translation: c.translation,
                pronunciation: c.pronunciation,
                totalReviews: c.totalReviews,
                correctReviews: c.correctReviews,
                wrongReviews: wrong,
                errorRate: (wrong / c.totalReviews) * 100,
                easeFactor: c.easeFactor,
              ),
            );
          }
        }

        localTroubleList.sort((a, b) {
          final cmp = b.wrongReviews.compareTo(a.wrongReviews);
          if (cmp != 0) return cmp;
          return b.errorRate.compareTo(a.errorRate);
        });

        final acc = tRev > 0 ? ((cRev / tRev) * 100).round() : 0;
        _stats = _stats.copyWith(
          streak: cachedProfile?.currentStreak ?? _stats.streak,
          longest: cachedProfile?.longestStreak ?? _stats.longest,
          goal: cachedProfile?.dailyGoal ?? _stats.goal,
          totalCards: localCards.length,
          totalReviews: tRev,
          correctReviews: cRev,
          accuracy: acc,
          dueToday: due,
          mastered: mast,
          learning: learn,
          newCards: brandNew,
          troubleWords: localTroubleList,
        );
        notifyListeners();
      }
    }

    _isInitialLoading = (_stats.totalCards == 0 && _stats.streak == 0);
    _isLoading = true;
    notifyListeners();

    try {
      final today = SrsAlgorithm.todayISO();
      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();
      final sevenDaysAgo = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6)).toIso8601String();

      // Parallel data fetching with 4s timeout for optimal speed and reliability
      final results = await Future.wait<dynamic>([
        // 0: Profile
        SupabaseService.client
            .from('profiles')
            .select('id,current_streak,longest_streak,daily_goal')
            .eq('id', userId)
            .maybeSingle(),
        // 1: Cards with full details for trouble words & learning state
        SupabaseService.client
            .from('cards')
            .select(
              'id,word,translation,pronunciation,ease_factor,due_date,total_reviews,correct_reviews,repetitions',
            )
            .eq('user_id', userId),
        // 2: Reviews last 7 days
        SupabaseService.client
            .from('reviews')
            .select('reviewed_at,rating')
            .eq('user_id', userId)
            .gte('reviewed_at', sevenDaysAgo),
        // 3-6: Server-side counts avoid downloading the user's full review
        // history every time the stats screen opens.
        SupabaseService.client
            .from('reviews')
            .count()
            .eq('user_id', userId)
            .eq('rating', 0),
        SupabaseService.client
            .from('reviews')
            .count()
            .eq('user_id', userId)
            .eq('rating', 1),
        SupabaseService.client
            .from('reviews')
            .count()
            .eq('user_id', userId)
            .eq('rating', 2),
        SupabaseService.client
            .from('reviews')
            .count()
            .eq('user_id', userId)
            .eq('rating', 3),
        // 7: Reviews today count
        SupabaseService.client
            .from('reviews')
            .count()
            .eq('user_id', userId)
            .gte('reviewed_at', startOfDay),
      ]).timeout(const Duration(seconds: 4));

      final profileData = results[0] as Map<String, dynamic>?;
      final cardsData = (results[1] as List?) ?? [];
      final reviews7Data = (results[2] as List?) ?? [];
      final again = results[3] as int? ?? 0;
      final hard = results[4] as int? ?? 0;
      final good = results[5] as int? ?? 0;
      final easy = results[6] as int? ?? 0;
      final reviewsTodayCount = results[7] as int? ?? 0;

      // Calculate last 7 days buckets
      final Map<String, int> buckets = {};
      final dateFormat = DateFormat('yyyy-MM-dd');
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        buckets[dateFormat.format(d)] = 0;
      }

      for (final r in reviews7Data) {
        final reviewedAt = r['reviewed_at'] as String?;
        if (reviewedAt != null) {
          final k = reviewedAt.substring(0, 10);
          if (buckets.containsKey(k)) {
            buckets[k] = (buckets[k] ?? 0) + 1;
          }
        }
      }

      int totalReviews = 0;
      int correctReviews = 0;
      int dueToday = 0;
      int mastered = 0;
      int learning = 0;
      int newCards = 0;
      final troubleList = <TroubleCardItem>[];

      for (final c in cardsData) {
        final tRev = (c['total_reviews'] as num?)?.toInt() ?? 0;
        final cRev = (c['correct_reviews'] as num?)?.toInt() ?? 0;
        final reps = (c['repetitions'] as num?)?.toInt() ?? 0;
        final dDate = c['due_date'] as String? ?? today;
        final wrong = tRev - cRev;

        totalReviews += tRev;
        correctReviews += cRev;

        if (dDate.compareTo(today) <= 0) dueToday += 1;
        if (reps >= 3 && dDate.compareTo(today) > 0) mastered += 1;
        if (reps > 0 && reps < 3) learning += 1;
        if (tRev == 0) newCards += 1;

        if (wrong > 0 && tRev > 0) {
          troubleList.add(
            TroubleCardItem(
              id: c['id'] as String? ?? '',
              word: c['word'] as String? ?? '',
              translation: c['translation'] as String? ?? '',
              pronunciation: c['pronunciation'] as String?,
              totalReviews: tRev,
              correctReviews: cRev,
              wrongReviews: wrong,
              errorRate: (wrong / tRev) * 100,
              easeFactor: (c['ease_factor'] as num?)?.toDouble() ?? 2.5,
            ),
          );
        }
      }

      troubleList.sort((a, b) {
        final cmp = b.wrongReviews.compareTo(a.wrongReviews);
        if (cmp != 0) return cmp;
        return b.errorRate.compareTo(a.errorRate);
      });

      final accuracy = totalReviews > 0
          ? ((correctReviews / totalReviews) * 100).round()
          : 0;

      final loadedStats = StatsDataModel(
        streak: (profileData?['current_streak'] as num?)?.toInt() ?? 0,
        longest: (profileData?['longest_streak'] as num?)?.toInt() ?? 0,
        goal: (profileData?['daily_goal'] as num?)?.toInt() ?? 20,
        totalCards: cardsData.length,
        totalReviews: totalReviews,
        correctReviews: correctReviews,
        reviewsToday: reviewsTodayCount,
        accuracy: accuracy,
        dueToday: dueToday,
        mastered: mastered,
        learning: learning,
        newCards: newCards,
        ratingCounts: RatingCounts(
          again: again,
          hard: hard,
          good: good,
          easy: easy,
        ),
        last7: buckets.entries
            .map((e) => DailyCount(date: e.key, count: e.value))
            .toList(),
        troubleWords: troubleList,
      );

      if (generation != _generation) return;
      _stats = loadedStats;
      // Save to cache
      await CacheService.instance.cacheStats(_stats);
      _loadedUserId = userId;
      _loadedAt = DateTime.now();
    } catch (e) {
      debugPrint(
        'Error or timeout loading stats from network, fallback to cache: $e',
      );
      if (generation != _generation) return;
      final cached = await CacheService.instance.getCachedStats();
      if (cached != null) {
        _stats = cached;
      }

      final cachedProfile = await CacheService.instance.getCachedProfile();
      final localCards = await CacheService.instance.getCachedAllCards();

      if (localCards.isNotEmpty) {
        int tRev = 0, cRev = 0, due = 0, mast = 0, learn = 0, brandNew = 0;
        final today = SrsAlgorithm.todayISO();
        final localTroubleList = <TroubleCardItem>[];

        for (final c in localCards) {
          final wrong = c.totalReviews - c.correctReviews;
          tRev += c.totalReviews;
          cRev += c.correctReviews;
          if (c.dueDate.compareTo(today) <= 0) due += 1;
          if (c.repetitions >= 3 && c.dueDate.compareTo(today) > 0) mast += 1;
          if (c.repetitions > 0 && c.repetitions < 3) learn += 1;
          if (c.totalReviews == 0) brandNew += 1;

          if (wrong > 0 && c.totalReviews > 0) {
            localTroubleList.add(
              TroubleCardItem(
                id: c.id,
                word: c.word,
                translation: c.translation,
                pronunciation: c.pronunciation,
                totalReviews: c.totalReviews,
                correctReviews: c.correctReviews,
                wrongReviews: wrong,
                errorRate: (wrong / c.totalReviews) * 100,
                easeFactor: c.easeFactor,
              ),
            );
          }
        }

        localTroubleList.sort((a, b) {
          final cmp = b.wrongReviews.compareTo(a.wrongReviews);
          if (cmp != 0) return cmp;
          return b.errorRate.compareTo(a.errorRate);
        });

        final acc = tRev > 0 ? ((cRev / tRev) * 100).round() : 0;
        _stats = _stats.copyWith(
          streak: cachedProfile?.currentStreak ?? _stats.streak,
          longest: cachedProfile?.longestStreak ?? _stats.longest,
          goal: cachedProfile?.dailyGoal ?? _stats.goal,
          totalCards: localCards.length,
          totalReviews: tRev,
          correctReviews: cRev,
          accuracy: acc,
          dueToday: due,
          mastered: mast,
          learning: learn,
          newCards: brandNew,
          troubleWords: localTroubleList,
        );
      }
    } finally {
      _isInitialLoading = false;
      _isLoading = false;
      notifyListeners();
    }
  }
}
