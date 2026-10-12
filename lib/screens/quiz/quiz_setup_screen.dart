import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/card_model.dart';
import '../../models/deck_model.dart';
import 'quiz_play_screen.dart';

enum QuizScope { all, random, range }

class QuizSetupScreen extends StatefulWidget {
  final DeckModel deck;
  final List<CardModel> cards;

  const QuizSetupScreen({super.key, required this.deck, required this.cards});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  String _direction = 'en-uz';
  QuizScope _scope = QuizScope.all;

  int _randomCount = 20;
  int _rangeStart = 1;
  int _rangeEnd = 20;

  @override
  void initState() {
    super.initState();
    final total = widget.cards.length;
    if (total <= 20) {
      _randomCount = min(10, total);
      _scope = QuizScope.all;
    } else {
      _randomCount = 20;
    }
    _rangeStart = 1;
    _rangeEnd = min(20, total > 0 ? total : 1);
  }

  List<CardModel> _computeSelectedCards() {
    if (widget.cards.isEmpty) return [];

    switch (_scope) {
      case QuizScope.all:
        return List<CardModel>.from(widget.cards);

      case QuizScope.random:
        final count = _randomCount.clamp(1, widget.cards.length).toInt();
        final shuffled = List<CardModel>.from(widget.cards)..shuffle();
        return shuffled.take(count).toList();

      case QuizScope.range:
        final start =
            (_rangeStart - 1).clamp(0, widget.cards.length - 1).toInt();
        final end = _rangeEnd.clamp(start + 1, widget.cards.length).toInt();
        return widget.cards.sublist(start, end);
    }
  }

  void _setRange(int start, int end) {
    final total = widget.cards.length;
    final clampedStart = start.clamp(1, max(1, total)).toInt();
    final clampedEnd = end.clamp(clampedStart, max(1, total)).toInt();

    setState(() {
      _rangeStart = clampedStart;
      _rangeEnd = clampedEnd;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCards = _computeSelectedCards();
    final canStart = selectedCards.length >= 4;

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
                          '${widget.cards.length} ta so\'z mavjud',
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

            // Scope Selector Card
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
                    'SAVOLLAR QAMROVI',
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

                  // Scope Segmented Buttons
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildScopeButton(
                            label: 'Barchasi',
                            icon: Icons.all_inclusive_rounded,
                            scope: QuizScope.all,
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: _buildScopeButton(
                            label: 'Tasodifiy',
                            icon: Icons.shuffle_rounded,
                            scope: QuizScope.random,
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: _buildScopeButton(
                            label: 'Oraliq',
                            icon: Icons.view_column_rounded,
                            scope: QuizScope.range,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Scope details
                  if (_scope == QuizScope.random)
                    _buildRandomOptions(widget.cards.length, isDark)
                  else if (_scope == QuizScope.range)
                    _buildRangeOptions(widget.cards.length, isDark)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'To\'plamdagi barcha ${widget.cards.length} ta so\'z testga kiritiladi.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
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
                              '${selectedCards.length}',
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
                            cards: selectedCards,
                            direction: _direction,
                          ),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                'Boshlash (${selectedCards.length} ta savol)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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

  Widget _buildScopeButton({
    required String label,
    required IconData icon,
    required QuizScope scope,
    required bool isDark,
  }) {
    final isSelected = _scope == scope;
    return InkWell(
      onTap: () => setState(() => _scope = scope),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkCard : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? (isDark ? AppColors.brandDark : AppColors.brand)
                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.darkText : AppColors.lightText)
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRandomOptions(int totalCards, bool isDark) {
    final presets = [10, 20, 30, 50].where((p) => p <= totalCards).toList();
    if (presets.isEmpty && totalCards >= 4) {
      presets.add(totalCards);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tasodifiy savollar:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.brandDark : AppColors.brand,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_randomCount ta',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((count) {
            final isChosen = _randomCount == count;
            return ChoiceChip(
              label: Text('$count ta'),
              selected: isChosen,
              onSelected: (val) {
                if (val) setState(() => _randomCount = count);
              },
              selectedColor: isDark ? AppColors.brandDark : AppColors.brand,
              labelStyle: TextStyle(
                color: isChosen
                    ? Colors.white
                    : (isDark ? AppColors.darkText : AppColors.lightText),
                fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
        if (totalCards > 10) ...[
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: isDark ? AppColors.brandDark : AppColors.brand,
              thumbColor: isDark ? AppColors.brandDark : AppColors.brand,
            ),
            child: Slider(
              value: _randomCount.toDouble().clamp(4.0, totalCards.toDouble()),
              min: min(4.0, totalCards.toDouble()),
              max: totalCards.toDouble(),
              divisions: max(1, totalCards - min(4, totalCards)),
              label: '$_randomCount ta',
              onChanged: (val) {
                setState(() => _randomCount = val.round());
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRangeOptions(int totalCards, bool isDark) {
    final batchSize = totalCards > 50 ? 25 : 20;
    final batches = <Map<String, int>>[];
    for (int i = 1; i <= totalCards; i += batchSize) {
      final end = min(i + batchSize - 1, totalCards);
      batches.add({'start': i, 'end': end});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bo\'laklab o\'rganish (Oraliq):',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 8),

        if (batches.length > 1) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: batches.map((b) {
              final isChosen =
                  _rangeStart == b['start'] && _rangeEnd == b['end'];
              return ActionChip(
                label: Text('${b['start']} - ${b['end']}'),
                backgroundColor: isChosen
                    ? (isDark ? AppColors.brandDark : AppColors.brand)
                    : (isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary),
                labelStyle: TextStyle(
                  color: isChosen
                      ? Colors.white
                      : (isDark ? AppColors.darkText : AppColors.lightText),
                  fontWeight: isChosen ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12,
                ),
                onPressed: () => _setRange(b['start']!, b['end']!),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dan (#):',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: _rangeStart > 1
                              ? () => _setRange(_rangeStart - 1, _rangeEnd)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            '$_rangeStart',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: _rangeStart < _rangeEnd
                              ? () => _setRange(_rangeStart + 1, _rangeEnd)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gacha (#):',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: _rangeEnd > _rangeStart
                              ? () => _setRange(_rangeStart, _rangeEnd - 1)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            '$_rangeEnd',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: _rangeEnd < totalCards
                              ? () => _setRange(_rangeStart, _rangeEnd + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
