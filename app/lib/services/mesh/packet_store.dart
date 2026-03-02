import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/emergency_report.dart';
import '../../models/mesh_message.dart';
import '../../models/mesh_packet.dart';

class PacketStore {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/relaygo_packets.db';
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE packets (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            json_data TEXT NOT NULL,
            received_at INTEGER NOT NULL,
            uploaded INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  /// Insert a packet if it doesn't already exist. Returns true if inserted.
  Future<bool> insertIfNew(MeshPacket packet) async {
    final db = await database;
    try {
      await db.insert('packets', {
        'id': packet.id,
        'kind': packet.kind,
        'json_data': jsonEncode(packet.toJson()),
        'received_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'uploaded': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> insertReport(EmergencyReport report) async {
    return insertIfNew(MeshPacket.fromReport(report));
  }

  Future<bool> insertMessage(MeshMessage message) async {
    return insertIfNew(MeshPacket.fromMessage(message));
  }

  Future<bool> hasPacket(String id) async {
    final db = await database;
    final result = await db.query('packets', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty;
  }

  Future<List<EmergencyReport>> getAllReports() async {
    final db = await database;
    final rows = await db.query(
      'packets',
      where: 'kind = ?',
      whereArgs: ['report'],
      orderBy: 'received_at DESC',
    );
    return rows.map((row) {
      final json = jsonDecode(row['json_data'] as String);
      return EmergencyReport.fromJson(json);
    }).toList();
  }

  Future<List<MeshMessage>> getAllMessages() async {
    final db = await database;
    final rows = await db.query(
      'packets',
      where: 'kind = ?',
      whereArgs: ['msg'],
      orderBy: 'received_at DESC',
    );
    return rows.map((row) {
      final json = jsonDecode(row['json_data'] as String);
      return MeshMessage.fromJson(json);
    }).toList();
  }

  Future<List<MeshPacket>> getUnuploaded() async {
    final db = await database;
    final rows = await db.query(
      'packets',
      where: 'uploaded = 0',
      orderBy: 'received_at ASC',
    );
    return rows.map((row) {
      final json = jsonDecode(row['json_data'] as String);
      return MeshPacket.fromJson(json);
    }).toList();
  }

  Future<void> markUploaded(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE packets SET uploaded = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  /// Get all packet IDs currently in the store (for UI display).
  Future<List<String>> getAllPacketIds() async {
    final db = await database;
    final rows = await db.query(
      'packets',
      columns: ['id'],
      orderBy: 'received_at ASC',
    );
    return rows.map((row) => row['id'] as String).toList();
  }

  /// Delete all packets from the store.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('packets');
  }
}
