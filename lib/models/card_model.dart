import '../core/utils/srs.dart';

class CardModel {
  final String id;
  final String userId;
  final String deckId;
  final String word;
  final String? pronunciation;
  final String translation;
  final String? definition;
  final String? synonyms;
  final String? antonyms;
  final String? exampleSentence;
  final String? mySentence;
  final String? imageUrl;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final String dueDate;
  final DateTime? lastReviewedAt;
  final int totalReviews;
  final int correctReviews;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CardModel({
    required this.id,
    required this.userId,
    required this.deckId,
    required this.word,
    this.pronunciation,
    required this.translation,
    this.definition,
    this.synonyms,
    this.antonyms,
    this.exampleSentence,
    this.mySentence,
    this.imageUrl,
    this.easeFactor = 2.5,
    this.intervalDays = 0,
    this.repetitions = 0,
    required this.dueDate,
    this.lastReviewedAt,
    this.totalReviews = 0,
    this.correctReviews = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      deckId: json['deck_id'] as String? ?? '',
      word: json['word'] as String? ?? '',
      pronunciation: json['pronunciation'] as String?,
      translation: json['translation'] as String? ?? '',
      definition: json['definition'] as String?,
      synonyms: json['synonyms'] as String?,
      antonyms: json['antonyms'] as String?,
      exampleSentence: json['example_sentence'] as String?,
      mySentence: json['my_sentence'] as String?,
      imageUrl: json['image_url'] as String?,
      easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: (json['interval_days'] as num?)?.toInt() ?? 0,
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      dueDate: json['due_date'] as String? ?? SrsAlgorithm.todayISO(),
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.tryParse(json['last_reviewed_at'])
          : null,
      totalReviews: (json['total_reviews'] as num?)?.toInt() ?? 0,
      correctReviews: (json['correct_reviews'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'deck_id': deckId,
      'word': word,
      'pronunciation': pronunciation,
      'translation': translation,
      'definition': definition,
      'synonyms': synonyms,
      'antonyms': antonyms,
      'example_sentence': exampleSentence,
      'my_sentence': mySentence,
      'image_url': imageUrl,
      'ease_factor': easeFactor,
      'interval_days': intervalDays,
      'repetitions': repetitions,
      'due_date': dueDate,
      if (lastReviewedAt != null)
        'last_reviewed_at': lastReviewedAt!.toIso8601String(),
      'total_reviews': totalReviews,
      'correct_reviews': correctReviews,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  CardModel copyWith({
    String? word,
    String? pronunciation,
    String? translation,
    String? definition,
    String? synonyms,
    String? antonyms,
    String? exampleSentence,
    String? mySentence,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    String? dueDate,
    DateTime? lastReviewedAt,
    int? totalReviews,
    int? correctReviews,
    DateTime? updatedAt,
  }) {
    return CardModel(
      id: id,
      userId: userId,
      deckId: deckId,
      word: word ?? this.word,
      pronunciation: pronunciation ?? this.pronunciation,
      translation: translation ?? this.translation,
      definition: definition ?? this.definition,
      synonyms: synonyms ?? this.synonyms,
      antonyms: antonyms ?? this.antonyms,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      mySentence: mySentence ?? this.mySentence,
      imageUrl: imageUrl,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      dueDate: dueDate ?? this.dueDate,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      totalReviews: totalReviews ?? this.totalReviews,
      correctReviews: correctReviews ?? this.correctReviews,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
