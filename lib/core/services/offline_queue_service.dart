import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import 'supabase_service.dart';

enum OpKind { insert, update, delete }

class QueuedOp {
  final OpKind kind;
  final String table;
  final List<Map<String, dynamic>>? rows;
  final Map<String, dynamic>? match;
  final Map<String, dynamic>? values;

  QueuedOp({
    required this.kind,
    required this.table,
    this.rows,
    this.match,
    this.values,
  });

  factory QueuedOp.fromJson(Map<String, dynamic> json) {
    return QueuedOp(
      kind: OpKind.values.firstWhere((e) => e.name == json['kind']),
      table: json['table'] as String,
      rows: json['rows'] != null
          ? (json['rows'] as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : null,
      match: json['match'] != null
          ? Map<String, dynamic>.from(json['match'])
          : null,
      values: json['values'] != null
          ? Map<String, dynamic>.from(json['values'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind.name,
      'table': table,
      if (rows != null) 'rows': rows,
      if (match != null) 'match': match,
      if (values != null) 'values': values,
    };
  }
}

class OfflineQueueService {
  static final OfflineQueueService instance = OfflineQueueService._internal();
  OfflineQueueService._internal();

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  bool _isFlushing = false;
  Timer? _periodicTimer;
  String? _activeUserId;
  Future<void> _queueLock = Future<void>.value();

  String get _queueKey =>
      '${AppConstants.outboxKey}_${_activeUserId ?? 'signed_out'}';

  Future<void> initialize() async {
    await activateUser(SupabaseService.currentUser?.id);

    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (pendingCountNotifier.value > 0 && !_isFlushing) {
        flushQueue();
      }
    });
  }

  Future<void> activateUser(String? userId) async {
    _activeUserId = userId;
    final ops = await _readQueue(_queueKey);
    pendingCountNotifier.value = ops.length;
    if (ops.isNotEmpty && userId != null) {
      unawaited(flushQueue());
    }
  }

  Future<T> _withQueueLock<T>(Future<T> Function() action) async {
    final previous = _queueLock;
    final completer = Completer<void>();
    _queueLock = completer.future;
    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  Future<List<QueuedOp>> _readQueue(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => QueuedOp.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error reading offline queue: $e');
      return [];
    }
  }

  Future<void> _writeQueue(String key, List<QueuedOp> ops) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(ops.map((e) => e.toJson()).toList());
      await prefs.setString(key, raw);
      if (key == _queueKey) pendingCountNotifier.value = ops.length;
    } catch (e) {
      debugPrint('Error writing offline queue: $e');
    }
  }

  Future<void> enqueue(QueuedOp op) async {
    final key = _queueKey;
    await _withQueueLock(() async {
      final ops = await _readQueue(key);
      ops.add(op);
      await _writeQueue(key, ops);
    });
  }

  Future<bool> queuedWrite(QueuedOp op) async {
    try {
      await _applyOp(op);
      return true;
    } on PostgrestException catch (e) {
      if (_isPermanentPostgrestError(e)) {
        debugPrint('Server permanently rejected write: $e');
        return false;
      }
      debugPrint('Server write failed, enqueuing op: $e');
      await enqueue(op);
      return true;
    } catch (e) {
      debugPrint('Direct write failed, enqueuing op: $e');
      await enqueue(op);
      return true;
    }
  }

  Future<void> _applyOp(QueuedOp op) async {
    final client = SupabaseService.client;
    switch (op.kind) {
      case OpKind.insert:
        if (op.rows != null && op.rows!.isNotEmpty) {
          final sanitizedRows = op.rows!.map((row) {
            if (op.table == 'decks') {
              final copy = Map<String, dynamic>.from(row);
              copy.remove('card_count');
              return copy;
            }
            return row;
          }).toList();
          await client.from(op.table).insert(sanitizedRows);
        }
        break;
      case OpKind.update:
        if (op.match != null && op.values != null) {
          final copyValues = Map<String, dynamic>.from(op.values!);
          if (op.table == 'decks') {
            copyValues.remove('card_count');
          }
          var query = client.from(op.table).update(copyValues);
          for (final entry in op.match!.entries) {
            query = query.eq(entry.key, entry.value);
          }
          await query;
        }
        break;
      case OpKind.delete:
        if (op.match != null) {
          var query = client.from(op.table).delete();
          for (final entry in op.match!.entries) {
            query = query.eq(entry.key, entry.value);
          }
          await query;
        }
        break;
    }
  }

  Future<void> flushQueue() async {
    if (_isFlushing) return;
    _isFlushing = true;
    final key = _queueKey;
    final userId = _activeUserId;

    try {
      while (true) {
        if (userId == null ||
            _activeUserId != userId ||
            SupabaseService.currentUser?.id != userId) {
          break;
        }
        final current = await _withQueueLock(() async {
          final ops = await _readQueue(key);
          return ops.isEmpty ? null : ops.first;
        });
        if (current == null) break;

        try {
          await _applyOp(current);
          if (_activeUserId != userId) break;
          await _removeFirst(key, current);
        } on PostgrestException catch (e) {
          if (_activeUserId != userId) break;
          if (_isPermanentPostgrestError(e)) {
            // Validation, constraint and RLS failures will not heal on retry.
            // Remove them so one bad record cannot block the user's queue.
            debugPrint('Discarding permanently rejected queued op: $e');
            await _removeFirst(key, current);
          } else {
            debugPrint('Server could not flush op, will retry later: $e');
            break;
          }
        } catch (e) {
          debugPrint('Failed to flush op, will retry later: $e');
          break; // Stop flushing until connection is better
        }
      }
    } finally {
      _isFlushing = false;
    }
  }

  bool _isPermanentPostgrestError(PostgrestException error) {
    final code = error.code ?? '';
    return code.startsWith('22') || code.startsWith('23') || code == '42501';
  }

  Future<void> _removeFirst(String key, QueuedOp completed) {
    return _withQueueLock(() async {
      final ops = await _readQueue(key);
      if (ops.isEmpty) return;
      if (ops.first.table == completed.table &&
          ops.first.kind == completed.kind) {
        ops.removeAt(0);
        await _writeQueue(key, ops);
      } else {
        final index = ops.indexWhere(
          (op) =>
              op.table == completed.table &&
              op.kind == completed.kind &&
              jsonEncode(op.match) == jsonEncode(completed.match),
        );
        if (index != -1) {
          ops.removeAt(index);
          await _writeQueue(key, ops);
        }
      }
    });
  }
}
