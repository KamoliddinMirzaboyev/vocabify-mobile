import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_service.dart';
import '../models/duel_model.dart';

class DuelRepositoryException implements Exception {
  const DuelRepositoryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class DuelRepository {
  DuelRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<BattleOpponent?> searchOpponent(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return null;
    try {
      final result = await _client.rpc(
        'search_battle_opponent',
        params: {'p_query': normalized},
      );
      if (result == null) return null;
      return BattleOpponent.fromJson(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw DuelRepositoryException(_messageFor(error), error);
    }
  }

  Future<String> createDuel({
    required String deckId,
    String? opponentId,
  }) async {
    try {
      final cleanOpponent = _emptyToNull(opponentId);
      final result = await _client.rpc(
        'create_duel',
        params: {
          'p_deck_id': deckId,
          'p_opponent_id': ?cleanOpponent,
        },
      );
      if (result is! String || result.isEmpty) {
        throw const FormatException('create_duel returned an invalid id');
      }
      return result;
    } catch (error) {
      throw DuelRepositoryException(_messageFor(error), error);
    }
  }

  Future<List<DuelQuestionModel>> getQuestions(String duelId) async {
    try {
      final result = await _client.rpc(
        'get_duel_questions',
        params: {'p_duel_id': duelId},
      );
      final rows = result as List<dynamic>? ?? const [];
      return rows
          .map(
            (row) => DuelQuestionModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } catch (error) {
      throw DuelRepositoryException(_messageFor(error), error);
    }
  }

  Future<DuelSubmissionResult> submitAnswers({
    required String duelId,
    required List<DuelAnswerSubmission> answers,
  }) async {
    if (answers.length != 10) {
      throw const DuelRepositoryException('Exactly 10 answers are required.');
    }
    try {
      final result = await _client.rpc(
        'submit_duel_answers',
        params: {
          'p_duel_id': duelId,
          'p_answers': answers.map((answer) => answer.toJson()).toList(),
        },
      );
      return DuelSubmissionResult.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (error) {
      throw DuelRepositoryException(_messageFor(error), error);
    }
  }

  Future<List<DuelModel>> getDuels() async {
    try {
      final result = await _client.rpc('list_duels');
      return (result as List<dynamic>)
          .map(
            (row) => DuelModel.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(growable: false);
    } catch (error) {
      throw DuelRepositoryException(_messageFor(error), error);
    }
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _messageFor(Object error) {
    if (error is PostgrestException) return error.message;
    return 'Word Battle request failed. Please try again.';
  }
}
