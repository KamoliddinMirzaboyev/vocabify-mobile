import 'dart:math';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/card_model.dart';
import '../models/deck_model.dart';
import '../screens/quiz/quiz_play_screen.dart';
import '../screens/study/study_screen.dart';

enum StudyScopeType { all, random, range }

enum StudyModeType { flashcard, typing, quiz }

class CustomStudyModal extends StatefulWidget {
  final DeckModel? deck;
  final List<CardModel> cards;
  final bool isGlobal;
  final StudyModeType initialMode;

  const CustomStudyModal({
    super.key,
    this.deck,
    required this.cards,
    this.isGlobal = false,
    this.initialMode = StudyModeType.quiz,
  });

  static Future<void> show(
    BuildContext context, {
    DeckModel? deck,
    required List<CardModel> cards,
    bool isGlobal = false,
    StudyModeType initialMode = StudyModeType.quiz,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomStudyModal(
        deck: deck,
        cards: cards,
        isGlobal: isGlobal,
        initialMode: initialMode,
      ),
    );
  }

  @override
  State<CustomStudyModal> createState() => _CustomStudyModalState();
}

class _CustomStudyModalState extends State<CustomStudyModal> {
  late StudyModeType _studyMode;
  StudyScopeType _scopeType = StudyScopeType.random;
  String _direction = 'en-uz';

  int _randomCount = 20;
  int _rangeStart = 1;
  int _rangeEnd = 20;

  late TextEditingController _startController;
  late TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _studyMode = widget.initialMode;

    final total = widget.cards.length;
    if (total <= 10) {
      _randomCount = total;
    } else if (total <= 20) {
      _randomCount = 10;
    } else {
      _randomCount = 20;
    }

    _rangeStart = 1;
    _rangeEnd = min(20, total > 0 ? total : 1);

    _startController = TextEditingController(text: '$_rangeStart');
    _endController = TextEditingController(text: '$_rangeEnd');
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  List<CardModel> _computeSelectedCards() {
    if (widget.cards.isEmpty) return [];

    switch (_scopeType) {
      case StudyScopeType.all:
        return List<CardModel>.from(widget.cards);

      case StudyScopeType.random:
        final count = _randomCount.clamp(1, widget.cards.length).toInt();
        final shuffled = List<CardModel>.from(widget.cards)..shuffle();
        return shuffled.take(count).toList();

      case StudyScopeType.range:
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
      _startController.text = '$_rangeStart';
      _endController.text = '$_rangeEnd';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCards = widget.cards.length;
    final selectedCards = _computeSelectedCards();
    final canStart = _studyMode == StudyModeType.quiz
        ? selectedCards.length >= 4
        : selectedCards.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 14,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.deck?.icon ?? '🎲',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isGlobal
                              ? 'Umumiy Aralash Sinov'
                              : (widget.deck?.name ?? 'Moslashuvchan mashq'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.isGlobal
                              ? 'Barcha to\'plamlardan • $totalCards ta so\'z'
                              : '$totalCards ta so\'z mavjud',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 1. Study Mode Selector
              _buildSectionHeader('MASHQ TURI', isDark),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildModeTab(
                      type: StudyModeType.quiz,
                      icon: Icons.quiz_rounded,
                      label: 'Viktorina',
                      isSelected: _studyMode == StudyModeType.quiz,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildModeTab(
                      type: StudyModeType.flashcard,
                      icon: Icons.style_rounded,
                      label: 'Kartalar',
                      isSelected: _studyMode == StudyModeType.flashcard,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildModeTab(
                      type: StudyModeType.typing,
                      icon: Icons.keyboard_rounded,
                      label: 'Yozish',
                      isSelected: _studyMode == StudyModeType.typing,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quiz Direction (if quiz)
              if (_studyMode == StudyModeType.quiz) ...[
                _buildSectionHeader('YO\'NALISH', isDark),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDirectionChip(
                        title: 'EN → UZ',
                        subtitle: 'Inglizchadan o\'zbekchaga',
                        isSelected: _direction == 'en-uz',
                        isDark: isDark,
                        onTap: () => setState(() => _direction = 'en-uz'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDirectionChip(
                        title: 'UZ → EN',
                        subtitle: 'O\'zbekchadan inglizchaga',
                        isSelected: _direction == 'uz-en',
                        isDark: isDark,
                        onTap: () => setState(() => _direction = 'uz-en'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 2. Scope Selector
              _buildSectionHeader('SO\'ZLAR QAMROVI', isDark),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSecondary
                      : AppColors.lightSecondary,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildScopeTab(
                        label: 'Tasodifiy',
                        icon: Icons.shuffle_rounded,
                        scope: StudyScopeType.random,
                        isDark: isDark,
                      ),
                    ),
                    Expanded(
                      child: _buildScopeTab(
                        label: 'Oraliq (Range)',
                        icon: Icons.view_column_rounded,
                        scope: StudyScopeType.range,
                        isDark: isDark,
                      ),
                    ),
                    Expanded(
                      child: _buildScopeTab(
                        label: 'Barchasi',
                        icon: Icons.all_inclusive_rounded,
                        scope: StudyScopeType.all,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Scope details based on chosen scope
              if (_scopeType == StudyScopeType.random)
                _buildRandomSection(totalCards, isDark)
              else if (_scopeType == StudyScopeType.range)
                _buildRangeSection(totalCards, isDark)
              else
                _buildAllSection(totalCards, isDark),

              const SizedBox(height: 18),

              // Summary Info Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.brandDark : AppColors.brand)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? AppColors.brandDark : AppColors.brand)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: isDark ? AppColors.brandDark : AppColors.brand,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tanlandi: ${selectedCards.length} ta so\'z (${_getScopeLabel()})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.brandDark : AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (!canStart && _studyMode == StudyModeType.quiz) ...[
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Viktorina uchun kamida 4 ta so\'z tanlanishi kerak',
                    style: TextStyle(
                      color: AppColors.destructive,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Start Button
              ElevatedButton.icon(
                onPressed: canStart ? () => _startSession(selectedCards) : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(
                  'Boshlash (${selectedCards.length} ta so\'z)',
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      ),
    );
  }

  Widget _buildModeTab({
    required StudyModeType type,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => setState(() => _studyMode = type),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.brandDark : AppColors.brand)
              : (isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.brandDark : AppColors.brand)
                : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionChip({
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.brandDark : AppColors.brand)
              : (isDark ? AppColors.darkSecondary : AppColors.lightSecondary),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeTab({
    required String label,
    required IconData icon,
    required StudyScopeType scope,
    required bool isDark,
  }) {
    final isSelected = _scopeType == scope;
    return InkWell(
      onTap: () => setState(() => _scopeType = scope),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkCard : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
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
              size: 16,
              color: isSelected
                  ? (isDark ? AppColors.brandDark : AppColors.brand)
                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            ),
            const SizedBox(width: 6),
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

  Widget _buildRandomSection(int totalCards, bool isDark) {
    final presets = [10, 20, 30, 50].where((p) => p <= totalCards).toList();
    if (presets.isEmpty && totalCards > 0) {
      presets.add(totalCards);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tasodifiy miqdor:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.brandDark : AppColors.brand,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_randomCount ta so\'z',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Preset Chips
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
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor:
                    isDark ? AppColors.brandDark : AppColors.brand,
                thumbColor: isDark ? AppColors.brandDark : AppColors.brand,
                overlayColor: (isDark ? AppColors.brandDark : AppColors.brand)
                    .withValues(alpha: 0.2),
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
      ),
    );
  }

  Widget _buildRangeSection(int totalCards, bool isDark) {
    // Generate quick batch chips (e.g., 1-20, 21-40, 41-60)
    final batchSize = totalCards > 50 ? 25 : 20;
    final batches = <Map<String, int>>[];
    for (int i = 1; i <= totalCards; i += batchSize) {
      final end = min(i + batchSize - 1, totalCards);
      batches.add({'start': i, 'end': end});
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qismlarga bo\'lib yodlash (Oraliq):',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 10),

          // Quick batch chips
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
                      : (isDark ? AppColors.darkCard : Colors.white),
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
            const SizedBox(height: 12),
          ],

          // Precise manual start / end input
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boshlanishi (#):',
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
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
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
                                fontSize: 16,
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tugashi (#):',
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
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
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
                                fontSize: 16,
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
      ),
    );
  }

  Widget _buildAllSection(int totalCards, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.library_books_rounded,
            color: isDark ? AppColors.brandDark : AppColors.brand,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Barcha mavjud $totalCards ta so\'z to\'liq mashqqa kiritiladi.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getScopeLabel() {
    switch (_scopeType) {
      case StudyScopeType.all:
        return 'barchasi';
      case StudyScopeType.random:
        return 'tasodifiy';
      case StudyScopeType.range:
        return '$_rangeStart-$_rangeEnd gacha';
    }
  }

  void _startSession(List<CardModel> selectedCards) {
    Navigator.pop(context);

    if (_studyMode == StudyModeType.quiz) {
      final effectiveDeck = widget.deck ??
          DeckModel(
            id: 'all_decks_mix',
            userId: selectedCards.isNotEmpty ? selectedCards.first.userId : '',
            name: 'Aralash sinov',
            icon: '🎲',
            cardCount: selectedCards.length,
          );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizPlayScreen(
            deck: effectiveDeck,
            cards: selectedCards,
            direction: _direction,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudyScreen(
            deckId: widget.deck?.id,
            customCards: selectedCards,
            startInTypingMode: _studyMode == StudyModeType.typing,
          ),
        ),
      );
    }
  }
}
