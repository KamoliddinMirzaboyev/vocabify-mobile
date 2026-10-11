class ProfileModel {
  static const String databaseColumns =
      'id, display_name, avatar_url, daily_goal, current_streak, '
      'longest_streak, last_study_date, created_at, updated_at';

  final String id;
  final String? displayName;
  final String? avatarUrl;
  final int dailyGoal;
  final int currentStreak;
  final int longestStreak;
  final String? lastStudyDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProfileModel({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.dailyGoal = 20,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastStudyDate,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      dailyGoal: json['daily_goal'] as int? ?? 20,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastStudyDate: json['last_study_date'] as String?,
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
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'daily_goal': dailyGoal,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_study_date': lastStudyDate,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? displayName,
    String? avatarUrl,
    int? dailyGoal,
    int? currentStreak,
    int? longestStreak,
    String? lastStudyDate,
  }) {
    return ProfileModel(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
