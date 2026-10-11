import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/card_model.dart';
import '../../models/deck_model.dart';
import 'quiz_play_screen.dart';

class QuizSetupScreen extends StatefulWidget {
  final DeckModel deck;
  final List<CardModel> cards;

  const QuizSetupScreen({super.key, required this.deck, required this.cards});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  String _direction = 'en-uz';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canStart = widget.cards.length >= 4;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VIKTORINA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const Text(
              'Quiz sozlamalari',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Deck Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Text(widget.deck.icon, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.deck.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.cards.length} ta so\'z',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Direction Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YO\'NALISH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _direction = 'en-uz'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _direction == 'en-uz'
                                  ? (isDark
                                        ? AppColors.brandDark
                                        : AppColors.brand)
                                  : (isDark
                                        ? AppColors.darkSecondary
                                        : AppColors.lightSecondary),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _direction == 'en-uz'
                                    ? (isDark
                                          ? AppColors.brandDark
                                          : AppColors.brand)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Text(
                                  'EN → UZ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _direction == 'en-uz'
                                        ? Colors.white
                                        : (isDark
                                              ? AppColors.darkText
                                              : AppColors.lightText),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'English to Uzbek',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _direction == 'en-uz'
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : (isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.lightTextMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _direction = 'uz-en'),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _direction == 'uz-en'
                                  ? (isDark
                                        ? AppColors.brandDark
                                        : AppColors.brand)
                                  : (isDark
                                        ? AppColors.darkSecondary
                                        : AppColors.lightSecondary),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _direction == 'uz-en'
                                    ? (isDark
                                          ? AppColors.brandDark
                                          : AppColors.brand)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Text(
                                  'UZ → EN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _direction == 'uz-en'
                                        ? Colors.white
                                        : (isDark
                                              ? AppColors.darkText
                                              : AppColors.lightText),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Uzbek to English',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _direction == 'uz-en'
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : (isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.lightTextMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Info Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSecondary
                                : AppColors.lightSecondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.track_changes_rounded,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.cards.length}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'savol',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSecondary
                                : AppColors.lightSecondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.timer_outlined, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '30s',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'har savol',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (!canStart) ...[
              const Center(
                child: Text(
                  'Viktorina uchun kamida 4 ta so\'z kerak',
                  style: TextStyle(
                    color: AppColors.destructive,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Start Button
            ElevatedButton.icon(
              onPressed: canStart
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizPlayScreen(
                            deck: widget.deck,
                            cards: widget.cards,
                            direction: _direction,
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Boshlash'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
