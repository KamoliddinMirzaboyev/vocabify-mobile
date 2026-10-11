enum DuelStatus { waitingB, completed, expired, cancelled }

class BattleOpponent {
  const BattleOpponent({required this.id, this.email, this.displayName});

  final String id;
  final String? email;
  final String? displayName;

  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    return id;
  }

  factory BattleOpponent.fromJson(Map<String, dynamic> json) {
    return BattleOpponent(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
    );
  }
}

class DuelModel {
  const DuelModel({
    required this.id,
    required this.deckId,
    required this.playerAId,
    required this.questionIds,
    required this.status,
    required this.playerAScore,
    required this.playerBScore,
    required this.createdAt,
    required this.expiresAt,
    this.playerBId,
    this.winnerId,
    this.playerASubmittedAt,
    this.playerBSubmittedAt,
  });

  final String id;
  final String deckId;
  final String playerAId;
  final String? playerBId;
  final List<String> questionIds;
  final DuelStatus status;
  final int playerAScore;
  final int playerBScore;
  final String? winnerId;
  final DateTime? playerASubmittedAt;
  final DateTime? playerBSubmittedAt;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isExpired =>
      status == DuelStatus.expired ||
      (status == DuelStatus.waitingB && !expiresAt.isAfter(DateTime.now()));

  bool hasSubmitted(String userId) => userId == playerAId
      ? playerASubmittedAt != null
      : userId == playerBId && playerBSubmittedAt != null;

  bool isUsersTurn(String userId) =>
      status == DuelStatus.waitingB &&
      !isExpired &&
      (((userId == playerAId || userId == playerBId) &&
              !hasSubmitted(userId)) ||
          (playerBId == null && userId != playerAId));

  bool isPendingFor(String userId) =>
      status == DuelStatus.waitingB && !isExpired && hasSubmitted(userId);

  factory DuelModel.fromJson(Map<String, dynamic> json) {
    return DuelModel(
      id: json['id'] as String,
      deckId: json['deck_id'] as String,
      playerAId: json['player_a_id'] as String,
      playerBId: json['player_b_id'] as String?,
      questionIds: (json['question_ids'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      status: _statusFromJson(json['status'] as String? ?? 'waiting_b'),
      playerAScore: (json['player_a_score'] as num?)?.toInt() ?? 0,
      playerBScore: (json['player_b_score'] as num?)?.toInt() ?? 0,
      winnerId: json['winner_id'] as String?,
      playerASubmittedAt: _dateOrNull(json['player_a_submitted_at']),
      playerBSubmittedAt: _dateOrNull(json['player_b_submitted_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  static DateTime? _dateOrNull(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  static DuelStatus _statusFromJson(String value) => switch (value) {
    'completed' => DuelStatus.completed,
    'expired' => DuelStatus.expired,
    'cancelled' => DuelStatus.cancelled,
    _ => DuelStatus.waitingB,
  };

  DuelSubmissionResult toSubmissionResult(String currentUserId) {
    final isPlayerA = currentUserId == playerAId;
    return DuelSubmissionResult(
      duelId: id,
      score: isPlayerA ? playerAScore : playerBScore,
      status: status,
      playerAScore: playerAScore,
      playerBScore: playerBScore,
      submittedAsPlayerA: isPlayerA,
      winnerId: winnerId,
    );
  }
}

class DuelQuestionModel {
  const DuelQuestionModel({
    required this.wordId,
    required this.prompt,
    required this.options,
  });

  final String wordId;
  final String prompt;
  final List<String> options;

  factory DuelQuestionModel.fromJson(Map<String, dynamic> json) {
    return DuelQuestionModel(
      wordId: json['word_id'] as String,
      prompt: json['prompt'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }
}

class DuelAnswerSubmission {
  const DuelAnswerSubmission({
    required this.wordId,
    required this.selectedOption,
    required this.timeSpentMs,
  });

  final String wordId;
  final String selectedOption;
  final int timeSpentMs;

  Map<String, dynamic> toJson() => {
    'word_id': wordId,
    'selected_option': selectedOption,
    'time_spent_ms': timeSpentMs.clamp(0, 10000),
  };
}

class DuelSubmissionResult {
  const DuelSubmissionResult({
    required this.duelId,
    required this.score,
    required this.status,
    required this.playerAScore,
    required this.playerBScore,
    required this.submittedAsPlayerA,
    this.winnerId,
  });

  final String duelId;
  final int score;
  final DuelStatus status;
  final int playerAScore;
  final int playerBScore;
  final bool submittedAsPlayerA;
  final String? winnerId;

  bool get isCompleted => status == DuelStatus.completed;

  factory DuelSubmissionResult.fromJson(Map<String, dynamic> json) {
    return DuelSubmissionResult(
      duelId: json['duel_id'] as String,
      score: (json['score'] as num?)?.toInt() ?? 0,
      status: DuelModel._statusFromJson(
        json['status'] as String? ?? 'waiting_b',
      ),
      playerAScore: (json['player_a_score'] as num?)?.toInt() ?? 0,
      playerBScore: (json['player_b_score'] as num?)?.toInt() ?? 0,
      submittedAsPlayerA: json['submitted_as'] == 'player_a',
      winnerId: json['winner_id'] as String?,
    );
  }
}
