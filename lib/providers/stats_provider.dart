import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../core/services/supabase_service.dart';
import '../core/services/cache_service.dart';
import '../core/utils/srs.dart';
import '../models/stats_data_model.dart';

class StatsProvider extends ChangeNotifier {
  StatsDataModel _stats = StatsDataModel();
  bool _isLoading = false;

  StatsDataModel get stats => _stats;
  bool get isLoading => _isLoading;

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

  Future<void> loadStats(String? userId) async {
    if (userId == null || userId.isEmpty) return;

    // Load from cache first if stats is empty
    if (_stats.totalCards == 0 && _stats.streak == 0) {
      final cached = await CacheService.instance.getCachedStats();
      if (cached != null) {
        _stats = cached;
        notifyListeners();
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final today = SrsAlgorithm.todayISO();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
      final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)).toIso8601String();

      // Parallel data fetching
      final results = await Future.wait<dynamic>([
        // 0: Profile
        SupabaseService.client.from('profiles').select('*').eq('id', userId).maybeSingle(),
        // 1: Cards
        SupabaseService.client.from('cards').select('id,due_date,total_reviews,correct_reviews,repetitions').eq('user_id', userId),
        // 2: Reviews last 7 days
        SupabaseService.client.from('reviews').select('reviewed_at,rating').eq('user_id', userId).gte('reviewed_at', sevenDaysAgo),
        // 3: All reviews for rating distribution
        SupabaseService.client.from('reviews').select('rating').eq('user_id', userId),
        // 4: Reviews today count
        SupabaseService.client.from('reviews').count().eq('user_id', userId).gte('reviewed_at', startOfDay),
      ]);

      final profileData = results[0] as Map<String, dynamic>?;
      final cardsData = (results[1] as List?) ?? [];
      final reviews7Data = (results[2] as List?) ?? [];
      final reviewsAllData = (results[3] as List?) ?? [];
      final reviewsTodayCount = results[4] as int? ?? 0;

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

      for (final c in cardsData) {
        final tRev = (c['total_reviews'] as num?)?.toInt() ?? 0;
        final cRev = (c['correct_reviews'] as num?)?.toInt() ?? 0;
        final reps = (c['repetitions'] as num?)?.toInt() ?? 0;
        final dDate = c['due_date'] as String? ?? today;

        totalReviews += tRev;
        correctReviews += cRev;

        if (dDate.compareTo(today) <= 0) dueToday += 1;
        if (reps >= 3 && dDate.compareTo(today) > 0) mastered += 1;
        if (reps > 0 && reps < 3) learning += 1;
        if (tRev == 0) newCards += 1;
      }

      int again = 0, hard = 0, good = 0, easy = 0;
      for (final r in reviewsAllData) {
        final rating = (r['rating'] as num?)?.toInt() ?? 0;
        if (rating == 0) again += 1;
        if (rating == 1) hard += 1;
        if (rating == 2) good += 1;
        if (rating == 3) easy += 1;
      }

      final accuracy = totalReviews > 0 ? ((correctReviews / totalReviews) * 100).round() : 0;

      _stats = StatsDataModel(
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
        last7: buckets.entries.map((e) => DailyCount(date: e.key, count: e.value)).toList(),
      );

      // Save to cache
      await CacheService.instance.cacheStats(_stats);
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (_stats.totalCards == 0) {
        final cached = await CacheService.instance.getCachedStats();
        if (cached != null) _stats = cached;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
