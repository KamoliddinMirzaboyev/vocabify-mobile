class ReviewModel {
  final String id;
  final String userId;
  final String cardId;
  final int rating; // 0=Again, 1=Hard, 2=Good, 3=Easy
  final DateTime reviewedAt;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.cardId,
    required this.rating,
    required this.reviewedAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      cardId: json['card_id'] as String,
      rating: (json['rating'] as num).toInt(),
      reviewedAt: DateTime.parse(json['reviewed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'card_id': cardId,
      'rating': rating,
      'reviewed_at': reviewedAt.toIso8601String(),
    };
  }
}
