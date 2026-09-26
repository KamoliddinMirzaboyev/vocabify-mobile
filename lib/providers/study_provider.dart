import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/services/supabase_service.dart';
import '../core/services/offline_queue_service.dart';
import '../core/services/cache_service.dart';
import '../core/services/tts_service.dart';
import '../core/utils/srs.dart';
import '../core/utils/helpers.dart';
import '../models/card_model.dart';
import '../models/profile_model.dart';

class StudyProvider extends ChangeNotifier {
  List<CardModel> _queue = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isTypingMode = false;
  bool _isLoading = false;

  // Typing mode states
  String _typedAnswer = '';
  bool _isTypingChecked = false;
  bool _isTypingCorrect = false;
  int _typingAttempts = 0;
  int _hintLevel = 0;

  // Rating counters
  int _countAgain = 0;
  int _countHard = 0;
  int _countGood = 0;
  int _countEasy = 0;

  // Exit animation state ('left' | 'right' | null)
  String? _exitAnim;

  List<CardModel> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isFlipped => _isFlipped;
  bool get isTypingMode => _isTypingMode;
  bool get isLoading => _isLoading;

  String get typedAnswer => _typedAnswer;
  bool get isTypingChecked => _isTypingChecked;
  bool get isTypingCorrect => _isTypingCorrect;
  int get typingAttempts => _typingAttempts;
  int get hintLevel => _hintLevel;

  int get countAgain => _countAgain;
  int get countHard => _countHard;
  int get countGood => _countGood;
  int get countEasy => _countEasy;
  String? get exitAnim => _exitAnim;

  CardModel? get currentCard =>
      (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;

  bool get isFinished => !_isLoading && (_queue.isEmpty || _currentIndex >= _queue.length);
  int get totalDone => _countAgain + _countHard + _countGood + _countEasy;
  int get accuracy => totalDone > 0
      ? (((_countGood + _countEasy + _countHard * 0.5) / totalDone) * 100).round()
      : 0;

  Future<void> initSession({
    required String userId,
    String? deckId,
    bool startInTypingMode = false,
    bool forceAllCards = false,
  }) async {
    _isLoading = true;
    _currentIndex = 0;
    _isFlipped = false;
    _isTypingMode = startInTypingMode;
    _countAgain = 0;
    _countHard = 0;
    _countGood = 0;
    _countEasy = 0;
    _resetTyping();
    notifyListeners();

    try {
      final today = SrsAlgorithm.todayISO();
      var filter = SupabaseService.client.from('cards').select('*').eq('user_id', userId);

      if (!forceAllCards) {
        filter = filter.lte('due_date', today);
      }

      if (deckId != null && deckId.isNotEmpty) {
        filter = filter.eq('deck_id', deckId);
      }

      final res = await filter.order('due_date', ascending: true).limit(100);
      final list = (res as List).map((e) => CardModel.fromJson(e as Map<String, dynamic>)).toList();
      _queue = list;
    } catch (e) {
      debugPrint('Error initializing study session from Supabase, loading from cache: $e');
      final today = SrsAlgorithm.todayISO();
      List<CardModel> localCards = [];
      if (deckId != null && deckId.isNotEmpty) {
        localCards = await CacheService.instance.getCachedDeckCards(deckId);
      } else {
        localCards = await CacheService.instance.getCachedAllCards();
      }

      if (forceAllCards) {
        _queue = localCards;
      } else {
        final dueCards = localCards.where((c) => c.dueDate.compareTo(today) <= 0).toList();
        _queue = dueCards.isNotEmpty ? dueCards : localCards;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setTypingMode(bool isTyping) {
    _isTypingMode = isTyping;
    _isFlipped = false;
    _resetTyping();
    notifyListeners();
  }

  void flipCard() {
    _isFlipped = !_isFlipped;
    notifyListeners();
  }

  void updateTypedAnswer(String value) {
    _typedAnswer = value;
    notifyListeners();
  }

  void revealHint() {
    if (_hintLevel < 2) {
      _hintLevel += 1;
      notifyListeners();
    }
  }

  void submitTyping() {
    final card = currentCard;
    if (card == null || _typedAnswer.trim().isEmpty) return;

    final normAnswer = AppHelpers.normalizeAnswer(_typedAnswer);
    final normExpected = AppHelpers.normalizeAnswer(card.word);
    final correct = normAnswer == normExpected;

    _typingAttempts += 1;
    _isTypingCorrect = correct;
    _isTypingChecked = true;
    notifyListeners();

    if (correct) {
      TtsService.instance.speak(card.word);
    }
  }

  Rating getTypingRating() {
    if (!_isTypingCorrect) {
      return _typingAttempts >= 2 ? Rating.again : Rating.hard;
    }
    if (_typingAttempts == 1 && _hintLevel == 0) {
      return Rating.easy;
    }
    return Rating.good;
  }

  Future<void> rate(Rating rating, {required String userId, ProfileModel? currentProfile}) async {
    final card = currentCard;
    if (card == null) return;

    // Trigger exit animation
    _exitAnim = rating == Rating.again ? 'left' : 'right';
    notifyListeners();

    // Calculate SM-2 update
    final state = SrsState(
      easeFactor: card.easeFactor,
      intervalDays: card.intervalDays,
      repetitions: card.repetitions,
    );
    final next = SrsAlgorithm.scheduleNext(state, rating);
    final isCorrect = rating.value > 0;

    // Track counts
    switch (rating) {
      case Rating.again:
        _countAgain += 1;
        break;
      case Rating.hard:
        _countHard += 1;
        break;
      case Rating.good:
        _countGood += 1;
        break;
      case Rating.easy:
        _countEasy += 1;
        break;
    }

    // Queued updates
    final now = DateTime.now().toIso8601String();
    OfflineQueueService.instance.queuedWrite(
      QueuedOp(
        kind: OpKind.update,
        table: 'cards',
        match: {'id': card.id},
        values: {
          'ease_factor': next.easeFactor,
          'interval_days': next.intervalDays,
          'repetitions': next.repetitions,
          'due_date': next.dueDate,
          'last_reviewed_at': now,
          'total_reviews': card.totalReviews + 1,
          'correct_reviews': card.correctReviews + (isCorrect ? 1 : 0),
          'updated_at': now,
        },
      ),
    );

    OfflineQueueService.instance.queuedWrite(
      QueuedOp(
        kind: OpKind.insert,
        table: 'reviews',
        rows: [
          {
            'id': const Uuid().v4(),
            'user_id': userId,
            'card_id': card.id,
            'rating': rating.value,
            'reviewed_at': now,
          }
        ],
      ),
    );
    OfflineQueueService.instance.flushQueue();

    // Also update local cache so offline sessions immediately reflect new scheduling
    final updatedCard = card.copyWith(
      easeFactor: next.easeFactor,
      intervalDays: next.intervalDays,
      repetitions: next.repetitions,
      dueDate: next.dueDate,
      lastReviewedAt: DateTime.tryParse(now),
      totalReviews: card.totalReviews + 1,
      correctReviews: card.correctReviews + (isCorrect ? 1 : 0),
    );
    CacheService.instance.updateSingleCachedCard(updatedCard);

    // Wait for swipe animation
    await Future.delayed(const Duration(milliseconds: 280));
    _exitAnim = null;
    _isFlipped = false;
    _resetTyping();

    // If rating is "Again", re-queue card to end of session
    if (rating == Rating.again) {
      _queue.add(card);
    }

    _currentIndex += 1;
    notifyListeners();

    // If finished session, update streak
    if (_currentIndex >= _queue.length) {
      _updateStreakAfterSession(userId, currentProfile);
    }
  }

  void _updateStreakAfterSession(String userId, ProfileModel? profile) {
    if (profile == null) return;
    final today = SrsAlgorithm.todayISO();
    if (profile.lastStudyDate == today) return;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yISO = DateFormat('yyyy-MM-dd').format(yesterday);

    final isConsecutive = profile.lastStudyDate != null &&
        profile.lastStudyDate == yISO;
    final newStreak = isConsecutive ? profile.currentStreak + 1 : 1;
    final longestStreak = newStreak > profile.longestStreak ? newStreak : profile.longestStreak;

    OfflineQueueService.instance.queuedWrite(
      QueuedOp(
        kind: OpKind.update,
        table: 'profiles',
        match: {'id': userId},
        values: {
          'current_streak': newStreak,
          'longest_streak': longestStreak,
          'last_study_date': today,
          'updated_at': DateTime.now().toIso8601String(),
        },
      ),
    );
    OfflineQueueService.instance.flushQueue();
  }

  void _resetTyping() {
    _typedAnswer = '';
    _isTypingChecked = false;
    _isTypingCorrect = false;
    _typingAttempts = 0;
    _hintLevel = 0;
  }
}
