import 'package:flutter/foundation.dart';

import '../models/duel_model.dart';
import '../repositories/duel_repository.dart';

class DuelProvider extends ChangeNotifier {
  DuelProvider({DuelRepository? repository})
    : _repository = repository ?? DuelRepository();

  final DuelRepository _repository;
  List<DuelModel> _duels = const [];
  bool _isLoading = false;
  String? _errorMessage;
  int _generation = 0;

  List<DuelModel> get duels => _duels;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clear() {
    _duels = const [];
    _isLoading = false;
    _errorMessage = null;
    _generation += 1;
    notifyListeners();
  }

  List<DuelModel> yourTurn(String userId) =>
      _duels.where((duel) => duel.isUsersTurn(userId)).toList(growable: false);

  List<DuelModel> pending(String userId) =>
      _duels.where((duel) => duel.isPendingFor(userId)).toList(growable: false);

  List<DuelModel> finished() => _duels
      .where((duel) => duel.status != DuelStatus.waitingB || duel.isExpired)
      .toList(growable: false);

  Future<void> loadDuels() async {
    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final duels = await _repository.getDuels();
      if (generation != _generation) return;
      _duels = duels;
    } on DuelRepositoryException catch (error) {
      if (generation != _generation) return;
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> createDuel({
    required String deckId,
    String? opponentId,
  }) async {
    final duelId = await _repository.createDuel(
      deckId: deckId,
      opponentId: opponentId,
    );
    await loadDuels();
    return duelId;
  }

  Future<void> refreshAfterBattle() => loadDuels();
}
