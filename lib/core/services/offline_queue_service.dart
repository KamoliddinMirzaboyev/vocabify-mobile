import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
          ? (json['rows'] as List).map((e) => Map<String, dynamic>.from(e)).toList()
          : null,
      match: json['match'] != null ? Map<String, dynamic>.from(json['match']) : null,
      values: json['values'] != null ? Map<String, dynamic>.from(json['values']) : null,
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

  Future<void> initialize() async {
    final ops = await _readQueue();
    pendingCountNotifier.value = ops.length;
    // Attempt initial flush
    flushQueue();
  }

  Future<List<QueuedOp>> _readQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.outboxKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) => QueuedOp.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error reading offline queue: $e');
      return [];
    }
  }

  Future<void> _writeQueue(List<QueuedOp> ops) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(ops.map((e) => e.toJson()).toList());
      await prefs.setString(AppConstants.outboxKey, raw);
      pendingCountNotifier.value = ops.length;
    } catch (e) {
      debugPrint('Error writing offline queue: $e');
    }
  }

  Future<void> enqueue(QueuedOp op) async {
    final ops = await _readQueue();
    ops.add(op);
    await _writeQueue(ops);
  }

  Future<void> queuedWrite(QueuedOp op) async {
    try {
      await _applyOp(op);
    } catch (e) {
      debugPrint('Direct write failed, enqueuing op: $e');
      await enqueue(op);
    }
  }

  Future<void> _applyOp(QueuedOp op) async {
    final client = SupabaseService.client;
    switch (op.kind) {
      case OpKind.insert:
        if (op.rows != null && op.rows!.isNotEmpty) {
          await client.from(op.table).insert(op.rows!);
        }
        break;
      case OpKind.update:
        if (op.match != null && op.values != null) {
          var query = client.from(op.table).update(op.values!);
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

    try {
      var ops = await _readQueue();
      while (ops.isNotEmpty) {
        final current = ops.first;
        try {
          await _applyOp(current);
          ops.removeAt(0);
          await _writeQueue(ops);
        } catch (e) {
          debugPrint('Failed to flush op, will retry later: $e');
          break; // Stop flushing until connection is better
        }
      }
    } finally {
      _isFlushing = false;
    }
  }
}
