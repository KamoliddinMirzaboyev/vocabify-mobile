import 'dart:math';

class AppHelpers {
  static String normalizeAnswer(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String maskWord(String sentence, String word) {
    if (word.isEmpty || sentence.isEmpty) return sentence;
    final escaped = RegExp.escape(word.trim());
    return sentence.replaceAll(RegExp(escaped, caseSensitive: false), '_____');
  }

  static String getWordHint(String word, int level) {
    final clean = word.trim();
    if (level <= 0 || clean.isEmpty) return '';
    if (clean.length <= 2) return clean[0];
    final visibleCount = level == 1 ? 1 : max(2, (clean.length / 3).ceil());
    final visiblePart = clean.substring(0, min(visibleCount, clean.length));
    final remainingCount = max(0, clean.length - visibleCount);
    return '$visiblePart${" _" * remainingCount}';
  }
}
