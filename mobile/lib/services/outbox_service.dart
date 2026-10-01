import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Deterministic offline outbox per specification §5.
class OutboxEvent {
  final String clientEventId;
  final String entityType;
  final String payloadJson;
  final String occurredAt;
  final int createdAt;
  final String syncStatus;
  final int retryCount;
  final String? lastError;
  final String idempotencyKey;

  OutboxEvent({
    required this.clientEventId,
    required this.entityType,
    required this.payloadJson,
    required this.occurredAt,
    required this.createdAt,
    this.syncStatus = 'PENDING',
    this.retryCount = 0,
    this.lastError,
    required this.idempotencyKey,
  });

  Map<String, Object?> toMap() => {
        'client_event_id': clientEventId,
        'entity_type': entityType,
        'payload_json': payloadJson,
        'occurred_at': occurredAt,
        'created_at': createdAt,
        'sync_status': syncStatus,
        'retry_count': retryCount,
        'last_error': lastError,
        'idempotency_key': idempotencyKey,
      };
}

/// Causal pipeline order — lower number syncs first when possible.
const Map<String, int> entityOrder = {
  'CHECK_IN': 1,
  'DELIVERY': 2,
  'RETURN': 3,
  'PAYMENT': 4,
  'STOP_FINALIZATION': 5,
  'EXCEPTION': 6,
  'SAFETY': 7,
  'CLOSEOUT': 8,
};

class OutboxService {
  OutboxService._();
  static final OutboxService instance = OutboxService._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'gaz_outbox.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE local_outbox (
    client_event_id TEXT PRIMARY KEY,
    entity_type TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    occurred_at TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    sync_status TEXT NOT NULL,
    retry_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    idempotency_key TEXT NOT NULL
);
''');
        await db.execute('''
CREATE TABLE local_domain (
    key TEXT PRIMARY KEY,
    entity_type TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    updated_at INTEGER NOT NULL
);
''');
      },
    );
  }

  /// Atomic local commit: domain table + outbox insert in one transaction.
  Future<void> enqueue({
    required String entityType,
    required Map<String, dynamic> payload,
    String? clientEventId,
    String? idempotencyKey,
    String? occurredAt,
  }) async {
    final database = await db;
    final id = clientEventId ?? const Uuid().v4();
    final now = DateTime.now().toUtc();
    final event = OutboxEvent(
      clientEventId: id,
      entityType: entityType,
      payloadJson: jsonEncode({
        'client_event_id': id,
        ...payload,
      }),
      occurredAt: occurredAt ?? now.toIso8601String(),
      createdAt: now.millisecondsSinceEpoch,
      idempotencyKey: idempotencyKey ?? id,
    );
    await database.transaction((txn) async {
      await txn.insert(
        'local_domain',
        {
          'key': id,
          'entity_type': entityType,
          'payload_json': event.payloadJson,
          'updated_at': event.createdAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert('local_outbox', event.toMap());
    });
  }

  Future<int> pendingCount() async {
    final database = await db;
    final rows = await database.rawQuery(
      "SELECT COUNT(*) as c FROM local_outbox WHERE sync_status IN ('PENDING','FAILED')",
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// FIFO by created_at, then by causal entity order for same batch.
  Future<List<OutboxEvent>> nextBatch({int limit = 20}) async {
    final database = await db;
    final rows = await database.query(
      'local_outbox',
      where: "sync_status IN ('PENDING','FAILED')",
      orderBy: 'created_at ASC',
      limit: limit,
    );
    final events = rows.map(_fromRow).toList();
    events.sort((a, b) {
      final oa = entityOrder[a.entityType] ?? 99;
      final ob = entityOrder[b.entityType] ?? 99;
      if (a.createdAt != b.createdAt) return a.createdAt.compareTo(b.createdAt);
      return oa.compareTo(ob);
    });
    return events;
  }

  Future<void> markInFlight(String id) => _setStatus(id, 'IN_FLIGHT');
  Future<void> markCommitted(String id) => _setStatus(id, 'COMMITTED');

  Future<void> markFailed(String id, String error, {bool isTerminal = false}) async {
    final database = await db;
    if (isTerminal) {
      await database.rawUpdate(
        'UPDATE local_outbox SET sync_status = ?, retry_count = retry_count + 1, last_error = ? WHERE client_event_id = ?',
        ['DEAD_LETTER', error, id],
      );
      return;
    }
    await database.rawUpdate(
      'UPDATE local_outbox SET sync_status = CASE WHEN retry_count + 1 >= 5 THEN ? ELSE ? END, retry_count = retry_count + 1, last_error = ? WHERE client_event_id = ?',
      ['DEAD_LETTER', 'FAILED', error, id],
    );
  }

  Future<void> _setStatus(String id, String status) async {
    final database = await db;
    await database.update(
      'local_outbox',
      {'sync_status': status},
      where: 'client_event_id = ?',
      whereArgs: [id],
    );
  }

  OutboxEvent _fromRow(Map<String, Object?> row) => OutboxEvent(
        clientEventId: row['client_event_id'] as String,
        entityType: row['entity_type'] as String,
        payloadJson: row['payload_json'] as String,
        occurredAt: row['occurred_at'] as String,
        createdAt: row['created_at'] as int,
        syncStatus: row['sync_status'] as String,
        retryCount: (row['retry_count'] as int?) ?? 0,
        lastError: row['last_error'] as String?,
        idempotencyKey: row['idempotency_key'] as String,
      );
}
