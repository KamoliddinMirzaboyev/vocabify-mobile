import 'package:flutter_test/flutter_test.dart';
import 'package:vocabify_app/models/duel_model.dart';

void main() {
  test('battle opponent exposes a useful label and searchable id', () {
    final opponent = BattleOpponent.fromJson({
      'id': 'player-b',
      'email': 'friend@example.com',
      'display_name': 'Friend',
    });

    expect(opponent.label, 'Friend');
    expect(opponent.id, 'player-b');
    expect(opponent.email, 'friend@example.com');
  });

  group('DuelModel', () {
    final json = <String, dynamic>{
      'id': 'duel-1',
      'deck_id': 'deck-1',
      'player_a_id': 'player-a',
      'player_b_id': 'player-b',
      'question_ids': List.generate(10, (index) => 'word-$index'),
      'status': 'waiting_b',
      'player_a_score': 8125,
      'player_b_score': 0,
      'winner_id': null,
      'player_a_submitted_at': '2026-10-11T10:00:00Z',
      'player_b_submitted_at': null,
      'created_at': '2026-10-11T09:55:00Z',
      'expires_at': '2026-10-12T09:55:00Z',
    };

    test('categorizes a submitted player as pending', () {
      final duel = DuelModel.fromJson(json);

      expect(duel.isPendingFor('player-a'), isTrue);
      expect(duel.isUsersTurn('player-a'), isFalse);
      expect(duel.isUsersTurn('player-b'), isTrue);
    });

    test('parses a completed winner', () {
      final duel = DuelModel.fromJson({
        ...json,
        'status': 'completed',
        'player_b_score': 7900,
        'winner_id': 'player-a',
        'player_b_submitted_at': '2026-10-11T11:00:00Z',
      });

      expect(duel.status, DuelStatus.completed);
      expect(duel.winnerId, 'player-a');
      expect(duel.playerAScore, 8125);
    });

    test('offers an open challenge to another player', () {
      final duel = DuelModel.fromJson({...json, 'player_b_id': null});

      expect(duel.isUsersTurn('available-player'), isTrue);
      expect(duel.isUsersTurn('player-a'), isFalse);
    });

    test('converts a DuelModel into a DuelSubmissionResult for a player', () {
      final duel = DuelModel.fromJson({
        ...json,
        'status': 'completed',
        'player_b_score': 7900,
        'winner_id': 'player-a',
      });

      final resultA = duel.toSubmissionResult('player-a');
      expect(resultA.score, 8125);
      expect(resultA.submittedAsPlayerA, isTrue);
      expect(resultA.winnerId, 'player-a');

      final resultB = duel.toSubmissionResult('player-b');
      expect(resultB.score, 7900);
      expect(resultB.submittedAsPlayerA, isFalse);
    });
  });

  test('answer submission clamps client time to the question limit', () {
    const answer = DuelAnswerSubmission(
      wordId: 'word-1',
      selectedOption: 'translation',
      timeSpentMs: 15000,
    );

    expect(answer.toJson()['time_spent_ms'], 10000);
  });

  test('submission result preserves the submitting player role', () {
    final result = DuelSubmissionResult.fromJson({
      'duel_id': 'duel-1',
      'score': 9000,
      'status': 'completed',
      'player_a_score': 8000,
      'player_b_score': 9000,
      'winner_id': 'player-b',
      'submitted_as': 'player_b',
    });

    expect(result.isCompleted, isTrue);
    expect(result.submittedAsPlayerA, isFalse);
  });
}
