import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/services/supabase_service.dart';
import '../core/services/offline_queue_service.dart';
import '../models/card_model.dart';
import '../models/deck_model.dart';

class QuizQuestion {
  final CardModel card;
  final List<String> options;
  final String correctAnswer;

  QuizQuestion({
    required this.card,
    required this.options,
    required this.correctAnswer,
  });
}

class QuizResultItem {
  final CardModel card;
  final String selectedAnswer;
  final bool isCorrect;

  QuizResultItem({
    required this.card,
    required this.selectedAnswer,
    required this.isCorrect,
  });
}

class QuizProvider extends ChangeNotifier {
  DeckModel? _deck;
  String _direction = 'en-uz'; // 'en-uz' or 'uz-en'
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  String? _selectedAnswer;
  bool _isAnswered = false;
  int _timeLeft = 30;
  bool _isSubmitting = false;
  final List<QuizResultItem> _results = [];

  Timer? _timer;

  DeckModel? get deck => _deck;
  String get direction => _direction;
  List<QuizQuestion> get questions => _questions;
  int get currentIndex => _currentIndex;
  String? get selectedAnswer => _selectedAnswer;
  bool get isAnswered => _isAnswered;
  int get timeLeft => _timeLeft;
  bool get isSubmitting => _isSubmitting;
  List<QuizResultItem> get results => _results;

  QuizQuestion? get currentQuestion =>
      (_currentIndex >= 0 && _currentIndex < _questions.length)
          ? _questions[_currentIndex]
          : null;

  bool get isQuizFinished => _questions.isNotEmpty && _currentIndex >= _questions.length;

  int get correctCount => _results.where((r) => r.isCorrect).length;
  int get wrongCount => _results.length - correctCount;
  int get scorePercentage =>
      _results.isNotEmpty ? ((correctCount / _results.length) * 100).round() : 0;

  void initQuiz({
    required DeckModel deck,
    required List<CardModel> cards,
    required String direction,
  }) {
    _deck = deck;
    _direction = direction;
    _currentIndex = 0;
    _selectedAnswer = null;
    _isAnswered = false;
    _timeLeft = 30;
    _results.clear();

    final shuffled = List<CardModel>.from(cards)..shuffle();
    _questions = shuffled.map((card) {
      final others = cards.where((c) => c.id != card.id).toList()..shuffle();
      final wrongCards = others.take(3).toList();

      final correctAnswer = direction == 'en-uz' ? card.translation : card.word;
      final wrongAnswers = wrongCards
          .map((c) => direction == 'en-uz' ? c.translation : c.word)
          .toList();

      final options = [correctAnswer, ...wrongAnswers]..shuffle();

      return QuizQuestion(
        card: card,
        options: options,
        correctAnswer: correctAnswer,
      );
    }).toList();

    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timeLeft <= 1) {
        _handleTimeout();
      } else {
        _timeLeft -= 1;
        notifyListeners();
      }
    });
  }

  void _handleTimeout() {
    _timer?.cancel();
    if (_isAnswered || currentQuestion == null) return;

    final q = currentQuestion!;
    _selectedAnswer = '';
    _isAnswered = true;
    _results.add(QuizResultItem(
      card: q.card,
      selectedAnswer: '',
      isCorrect: false,
    ));
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1200), () {
      _nextQuestion();
    });
  }

  void selectOption(String option) {
    if (_isAnswered || currentQuestion == null) return;
    _timer?.cancel();

    final q = currentQuestion!;
    final isCorrect = option == q.correctAnswer;
    _selectedAnswer = option;
    _isAnswered = true;

    _results.add(QuizResultItem(
      card: q.card,
      selectedAnswer: option,
      isCorrect: isCorrect,
    ));
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1200), () {
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    if (_currentIndex + 1 < _questions.length) {
      _currentIndex += 1;
      _selectedAnswer = null;
      _isAnswered = false;
      _startTimer();
      notifyListeners();
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    _timer?.cancel();
    _isSubmitting = true;
    notifyListeners();

    final userId = SupabaseService.currentUser?.id;
    if (userId != null && _results.isNotEmpty) {
      final now = DateTime.now().toIso8601String();

      // 1. Batch insert reviews
      final reviewRows = _results.map((r) => {
        'id': const Uuid().v4(),
        'user_id': userId,
        'card_id': r.card.id,
        'rating': r.isCorrect ? 2 : 0,
        'reviewed_at': now,
      }).toList();

      OfflineQueueService.instance.queuedWrite(
        QueuedOp(
          kind: OpKind.insert,
          table: 'reviews',
          rows: reviewRows,
        ),
      );

      // 2. Update card stats
      for (final r in _results) {
        OfflineQueueService.instance.queuedWrite(
          QueuedOp(
            kind: OpKind.update,
            table: 'cards',
            match: {'id': r.card.id},
            values: {
              'total_reviews': r.card.totalReviews + 1,
              'correct_reviews': r.card.correctReviews + (r.isCorrect ? 1 : 0),
              'updated_at': now,
            },
          ),
        );
      }
      OfflineQueueService.instance.flushQueue();
    }

    _isSubmitting = false;
    _currentIndex = _questions.length; // Mark finished
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
