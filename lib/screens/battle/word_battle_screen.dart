import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../models/duel_model.dart';
import '../../repositories/duel_repository.dart';
import 'word_battle_result_screen.dart';

class WordBattleScreen extends StatefulWidget {
  const WordBattleScreen({super.key, required this.duelId, this.repository});

  final String duelId;
  final DuelRepository? repository;

  @override
  State<WordBattleScreen> createState() => _WordBattleScreenState();
}

class _WordBattleScreenState extends State<WordBattleScreen> {
  static const _questionDuration = Duration(seconds: 10);
  static const _transitionDuration = Duration(milliseconds: 220);

  late final DuelRepository _repository;
  final Stopwatch _stopwatch = Stopwatch();
  final List<DuelAnswerSubmission> _answers = [];
  final ValueNotifier<int> _remainingMs = ValueNotifier<int>(
    _questionDuration.inMilliseconds,
  );
  Timer? _timer;
  List<DuelQuestionModel> _questions = const [];
  int _currentIndex = 0;
  String? _selectedOption;
  bool _isLoading = true;
  bool _isAdvancing = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DuelRepository();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remainingMs.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final questions = await _repository.getQuestions(widget.duelId);
      if (questions.length != 10 ||
          questions.any((q) => q.options.length != 4)) {
        throw const DuelRepositoryException(
          'This battle does not contain 10 valid questions.',
        );
      }
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
      _startQuestion();
    } on DuelRepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  void _startQuestion() {
    _timer?.cancel();
    _stopwatch
      ..reset()
      ..start();
    _remainingMs.value = _questionDuration.inMilliseconds;
    setState(() {
      _selectedOption = null;
      _isAdvancing = false;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final remaining =
          _questionDuration.inMilliseconds - _stopwatch.elapsedMilliseconds;
      if (remaining <= 0) {
        _recordAnswer('');
      } else if (mounted) {
        _remainingMs.value = remaining;
      }
    });
  }

  void _recordAnswer(String option) {
    if (_isAdvancing || _isSubmitting || _questions.isEmpty) return;
    _isAdvancing = true;
    _timer?.cancel();
    _stopwatch.stop();
    HapticFeedback.lightImpact();
    final elapsed = _stopwatch.elapsedMilliseconds.clamp(
      0,
      _questionDuration.inMilliseconds,
    );
    final question = _questions[_currentIndex];
    _answers.add(
      DuelAnswerSubmission(
        wordId: question.wordId,
        selectedOption: option,
        timeSpentMs: elapsed,
      ),
    );
    if (mounted) setState(() => _selectedOption = option);

    Future<void>.delayed(_transitionDuration, () {
      if (!mounted) return;
      if (_currentIndex + 1 < _questions.length) {
        setState(() => _currentIndex += 1);
        _startQuestion();
      } else {
        _submit();
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final result = await _repository.submitAnswers(
        duelId: widget.duelId,
        answers: _answers,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WordBattleResultScreen(result: result),
        ),
      );
    } on DuelRepositoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<bool> _confirmExit() async {
    if (_answers.isEmpty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave battle?'),
            content: const Text(
              'Your current answers are not saved. You can restart before the battle expires.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep playing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: _answers.isEmpty && !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isSubmitting) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait while scores are saved.'),
            ),
          );
          return;
        }
        if (await _confirmExit() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Word Battle')),
        body: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null && _questions.isEmpty) {
      return _ErrorState(message: _errorMessage!, onRetry: _loadQuestions);
    }
    if (_errorMessage != null && _answers.length == _questions.length) {
      return _ErrorState(message: _errorMessage!, onRetry: _submit);
    }
    if (_isSubmitting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scoring your battle…'),
          ],
        ),
      );
    }

    final question = _questions[_currentIndex];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BattleTimer(
              remainingMs: _remainingMs,
              currentIndex: _currentIndex,
              questionCount: _questions.length,
              isDark: isDark,
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(question.wordId),
                children: [
                  Text(
                    'Choose the translation',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question.prompt,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ...question.options.asMap().entries.map((entry) {
              final option = entry.value;
              final selected = option == _selectedOption;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnimatedScale(
                  scale: selected ? .98 : 1,
                  duration: const Duration(milliseconds: 140),
                  child: OutlinedButton(
                    onPressed: _isAdvancing
                        ? null
                        : () => _recordAnswer(option),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 17,
                      ),
                      alignment: Alignment.centerLeft,
                      side: BorderSide(
                        color: selected
                            ? (isDark ? AppColors.brandDark : AppColors.brand)
                            : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        width: selected ? 2 : 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              (isDark ? AppColors.brandDark : AppColors.brand)
                                  .withValues(alpha: .12),
                          child: Text(
                            String.fromCharCode(65 + entry.key),
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.brandDark
                                  : AppColors.brand,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            option,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.destructive),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BattleTimer extends StatelessWidget {
  const _BattleTimer({
    required this.remainingMs,
    required this.currentIndex,
    required this.questionCount,
    required this.isDark,
  });

  final ValueListenable<int> remainingMs;
  final int currentIndex;
  final int questionCount;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: remainingMs,
      builder: (context, milliseconds, _) {
        final progress =
            (milliseconds /
                    _WordBattleScreenState._questionDuration.inMilliseconds)
                .clamp(0.0, 1.0);
        final color = progress < .3
            ? AppColors.destructive
            : (isDark ? AppColors.brandDark : AppColors.brand);
        return Column(
          children: [
            Row(
              children: [
                Text(
                  '${currentIndex + 1} / $questionCount',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Icon(Icons.timer_outlined, color: color, size: 20),
                const SizedBox(width: 5),
                Text(
                  '${(milliseconds / 1000).ceil()}s',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: .14),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
