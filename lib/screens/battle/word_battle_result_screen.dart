import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../models/duel_model.dart';

class WordBattleResultScreen extends StatelessWidget {
  const WordBattleResultScreen({super.key, required this.result});

  final DuelSubmissionResult result;

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.currentUser?.id;
    final completed = result.isCompleted;
    final expired = result.status == DuelStatus.expired;
    final won = completed && result.winnerId == userId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Battle Result'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor:
                        (expired
                                ? AppColors.lightTextMuted
                                : completed
                                ? (won
                                      ? AppColors.success
                                      : AppColors.destructive)
                                : AppColors.accent)
                            .withValues(alpha: .14),
                    child: Text(
                      expired
                          ? '⌛'
                          : completed
                          ? (won ? '🏆' : '⚔️')
                          : '⏳',
                      style: const TextStyle(fontSize: 44),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    expired
                        ? 'Battle expired'
                        : completed
                        ? (won ? 'Victory!' : 'Defeat')
                        : 'Waiting for opponent…',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    expired
                        ? 'This duel passed its 24-hour limit before the answers were submitted.'
                        : completed
                        ? (won
                              ? 'Fast answers made the difference.'
                              : 'Keep training and challenge them again!')
                        : 'Your ${result.score} points are locked in. You can return when the other player finishes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (completed)
                    Row(
                      children: [
                        Expanded(
                          child: _ScoreCard(
                            label: 'Player A',
                            score: result.playerAScore,
                            highlighted: result.submittedAsPlayerA ? won : !won,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'VS',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Expanded(
                          child: _ScoreCard(
                            label: 'Player B',
                            score: result.playerBScore,
                            highlighted: result.submittedAsPlayerA ? !won : won,
                          ),
                        ),
                      ],
                    )
                  else
                    _ScoreCard(
                      label: 'Your score',
                      score: result.score,
                      highlighted: true,
                    ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.sports_martial_arts_rounded),
                      label: const Text('Back to Battle Hub'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.score,
    required this.highlighted,
  });

  final String label;
  final int score;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
    decoration: BoxDecoration(
      color: highlighted
          ? AppColors.success.withValues(alpha: .1)
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: highlighted
            ? AppColors.success
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
    child: Column(
      children: [
        Text(label, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        FittedBox(
          child: Text(
            '$score',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ),
        const Text('points', style: TextStyle(fontSize: 12)),
      ],
    ),
  );
}
