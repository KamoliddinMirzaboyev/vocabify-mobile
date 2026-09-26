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
  });
}
