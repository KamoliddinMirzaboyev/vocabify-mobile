import 'dart:math';
import 'package:intl/intl.dart';

enum Rating {
  again(0),
  hard(1),
  good(2),
  easy(3);

  final int value;
  const Rating(this.value);

  static Rating fromInt(int val) {
    switch (val) {
      case 0:
        return Rating.again;
      case 1:
        return Rating.hard;
      case 2:
        return Rating.good;
      case 3:
        return Rating.easy;
      default:
        return Rating.again;
    }
  }
}

class SrsState {
  final double easeFactor;
  final int intervalDays;
  final int repetitions;

  const SrsState({
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
  });
}

class SrsResult extends SrsState {
  final String dueDate; // YYYY-MM-DD

  const SrsResult({
    required super.easeFactor,
    required super.intervalDays,
    required super.repetitions,
    required this.dueDate,
  });
}

class SrsAlgorithm {
  static String todayISO() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  static SrsResult scheduleNext(SrsState state, Rating rating) {
    double easeFactor = state.easeFactor;
    int intervalDays = state.intervalDays;
    int repetitions = state.repetitions;

    if (rating == Rating.again) {
      // Again: reset progress, due now
      repetitions = 0;
      intervalDays = 0;
      easeFactor = max(1.3, easeFactor - 0.2);
    } else {
      final q = rating == Rating.hard ? 3 : rating == Rating.good ? 4 : 5;
      easeFactor = max(
        1.3,
        easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)),
      );

      if (repetitions == 0) {
        intervalDays = rating == Rating.hard ? 1 : rating == Rating.good ? 1 : 3;
      } else if (repetitions == 1) {
        intervalDays = rating == Rating.hard ? 3 : rating == Rating.good ? 4 : 7;
      } else {
        final mult = rating == Rating.hard
            ? 1.2
            : rating == Rating.good
                ? easeFactor
                : easeFactor * 1.3;
        intervalDays = max(1, (intervalDays * mult).round());
      }
      repetitions += 1;
    }

    final due = DateTime.now().add(Duration(days: intervalDays));
    final dueDate = DateFormat('yyyy-MM-dd').format(due);

    return SrsResult(
      easeFactor: easeFactor,
      intervalDays: intervalDays,
      repetitions: repetitions,
      dueDate: dueDate,
    );
  }

  static String formatIntervalHint(SrsState state, Rating rating) {
    final next = scheduleNext(state, rating);
    if (next.intervalDays == 0) return '<10m';
    if (next.intervalDays == 1) return '1 kun';
    return '${next.intervalDays} kun';
  }
}
