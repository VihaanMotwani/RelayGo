import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed response cache for the AI chat layer.
///
/// Stored in a separate DB (mesh_tester_ai.db) so it is never reset
/// when the mesh packet store is cleared.
///
/// Cache key = SHA-256(normalized_query + knowledge_hash + prompt_version + model_id)
/// computed by ChatService — this class is key-agnostic.
class ChatCacheStore {
  static const _dbName = 'mesh_tester_ai.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<void> initialize() async {
    try {
      final dbDir = await getDatabasesPath();
      final path = '$dbDir/$_dbName';
      _db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE response_cache (
              key         TEXT    PRIMARY KEY,
              answer      TEXT    NOT NULL,
              source_labels TEXT NOT NULL,
              used_rag    INTEGER NOT NULL,
              hit_count   INTEGER NOT NULL DEFAULT 0,
              created_at  INTEGER NOT NULL
            )
          ''');
        },
      );
      debugPrint('[ChatCacheStore] initialized at $path');
    } catch (e) {
      debugPrint('[ChatCacheStore] init failed: $e');
    }
  }

  /// Returns the cached answer for [key], or null on miss.
  /// Increments hit_count on hit.
  Future<String?> lookupResponse(String key) async {
    final db = _db;
    if (db == null) return null;
    try {
      final rows = await db.query(
        'response_cache',
        columns: ['answer'],
        where: 'key = ?',
        whereArgs: [key],
      );
      if (rows.isEmpty) return null;
      await db.rawUpdate(
        'UPDATE response_cache SET hit_count = hit_count + 1 WHERE key = ?',
        [key],
      );
      return rows.first['answer'] as String;
    } catch (e) {
      debugPrint('[ChatCacheStore] lookup error: $e');
      return null;
    }
  }

  /// Persist a generated answer.
  Future<void> saveResponse(
    String key,
    String answer,
    List<String> sourceLabels,
    bool usedRag,
  ) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.insert(
        'response_cache',
        {
          'key': key,
          'answer': answer,
          'source_labels': sourceLabels.join(','),
          'used_rag': usedRag ? 1 : 0,
          'hit_count': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[ChatCacheStore] save error: $e');
    }
  }

  /// Delete all cached responses.
  Future<void> clearAll() async {
    try {
      await _db?.delete('response_cache');
    } catch (e) {
      debugPrint('[ChatCacheStore] clear error: $e');
    }
  }

  /// Number of cached responses.
  Future<int> get size async {
    try {
      final result =
          await _db?.rawQuery('SELECT COUNT(*) as cnt FROM response_cache');
      return (result?.first['cnt'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
