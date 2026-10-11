class DailyCount {
  final String date; // YYYY-MM-DD
  final int count;

  DailyCount({required this.date, required this.count});
}

class RatingCounts {
  final int again;
  final int hard;
  final int good;
  final int easy;

  const RatingCounts({
    this.again = 0,
    this.hard = 0,
    this.good = 0,
    this.easy = 0,
  });
}

class TroubleCardItem {
  final String id;
  final String word;
  final String translation;
  final String? pronunciation;
  final int totalReviews;
  final int correctReviews;
  final int wrongReviews;
  final double errorRate;
  final double easeFactor;

  const TroubleCardItem({
    required this.id,
    required this.word,
    required this.translation,
    this.pronunciation,
    required this.totalReviews,
    required this.correctReviews,
    required this.wrongReviews,
    required this.errorRate,
    this.easeFactor = 2.5,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'translation': translation,
    'pronunciation': pronunciation,
    'total_reviews': totalReviews,
    'correct_reviews': correctReviews,
    'wrong_reviews': wrongReviews,
    'error_rate': errorRate,
    'ease_factor': easeFactor,
  };

  factory TroubleCardItem.fromJson(Map<String, dynamic> json) =>
      TroubleCardItem(
        id: json['id'] as String? ?? '',
        word: json['word'] as String? ?? '',
        translation: json['translation'] as String? ?? '',
        pronunciation: json['pronunciation'] as String?,
        totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
        correctReviews: (json['correct_reviews'] as num?)?.toInt() ?? 0,
        wrongReviews: (json['wrong_reviews'] as num?)?.toInt() ?? 0,
        errorRate: (json['error_rate'] as num?)?.toDouble() ?? 0.0,
        easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
      );
}

class StatsDataModel {
  final int streak;
  final int longest;
  final int goal;
  final int totalCards;
  final int totalReviews;
  final int correctReviews;
  final int reviewsToday;
  final int accuracy;
  final int dueToday;
  final int mastered;
  final int learning;
  final int newCards;
  final RatingCounts ratingCounts;
  final List<DailyCount> last7;
  final List<TroubleCardItem> troubleWords;

  int get wrongReviews =>
      totalReviews >= correctReviews ? totalReviews - correctReviews : 0;

  StatsDataModel({
    this.streak = 0,
    this.longest = 0,
    this.goal = 20,
    this.totalCards = 0,
    this.totalReviews = 0,
    this.correctReviews = 0,
    this.reviewsToday = 0,
    this.accuracy = 0,
    this.dueToday = 0,
    this.mastered = 0,
    this.learning = 0,
    this.newCards = 0,
    this.ratingCounts = const RatingCounts(),
    this.last7 = const [],
    this.troubleWords = const [],
  });

  StatsDataModel copyWith({
    int? streak,
    int? longest,
    int? goal,
    int? totalCards,
    int? totalReviews,
    int? correctReviews,
    int? reviewsToday,
    int? accuracy,
    int? dueToday,
    int? mastered,
    int? learning,
    int? newCards,
    RatingCounts? ratingCounts,
    List<DailyCount>? last7,
    List<TroubleCardItem>? troubleWords,
  }) {
    return StatsDataModel(
      streak: streak ?? this.streak,
      longest: longest ?? this.longest,
      goal: goal ?? this.goal,
      totalCards: totalCards ?? this.totalCards,
      totalReviews: totalReviews ?? this.totalReviews,
      correctReviews: correctReviews ?? this.correctReviews,
      reviewsToday: reviewsToday ?? this.reviewsToday,
      accuracy: accuracy ?? this.accuracy,
      dueToday: dueToday ?? this.dueToday,
      mastered: mastered ?? this.mastered,
      learning: learning ?? this.learning,
      newCards: newCards ?? this.newCards,
      ratingCounts: ratingCounts ?? this.ratingCounts,
      last7: last7 ?? this.last7,
      troubleWords: troubleWords ?? this.troubleWords,
    );
  }
}
