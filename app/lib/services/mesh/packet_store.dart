import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/directive.dart';
import '../../models/emergency_report.dart';
import '../../models/mesh_message.dart';
import '../../models/mesh_packet.dart';

class PacketStore {
  Database? _db;

  /// When true, opens an in-memory SQLite database (used in tests).
  final bool inMemory;

  PacketStore({this.inMemory = false});

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final String path;
    if (inMemory) {
      path = inMemoryDatabasePath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/relaygo_packets.db';
    }

    return openDatabase(
      path,
      version: 2,
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
        await db.execute('''
          CREATE TABLE directives (
            id TEXT PRIMARY KEY,
            ts INTEGER NOT NULL,
            src TEXT NOT NULL,
            name TEXT NOT NULL,
            to_device TEXT,
            zone TEXT,
            body TEXT NOT NULL,
            priority TEXT NOT NULL,
            hops INTEGER DEFAULT 0,
            ttl INTEGER DEFAULT 15,
            received_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS directives (
              id TEXT PRIMARY KEY,
              ts INTEGER NOT NULL,
              src TEXT NOT NULL,
              name TEXT NOT NULL,
              to_device TEXT,
              zone TEXT,
              body TEXT NOT NULL,
              priority TEXT NOT NULL,
              hops INTEGER DEFAULT 0,
              ttl INTEGER DEFAULT 15,
              received_at INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  /// Insert a packet if it doesn't already exist. Returns true if inserted.
  /// For directive packets, also mirrors into the `directives` table for display.
  Future<bool> insertIfNew(MeshPacket packet) async {
    final db = await database;
    final rows = await db.insert('packets', {
      'id': packet.id,
      'kind': packet.kind,
      'json_data': jsonEncode(packet.toJson()),
      'received_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'uploaded': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final isNew = rows > 0;

    // Mirror directive packets into the directives table for display queries.
    if (isNew && packet.isDirective && packet.directive != null) {
      final d = packet.directive!;
      await db.insert('directives', {
        'id': d.id,
        'ts': d.ts,
        'src': d.src,
        'name': d.name,
        'to_device': d.to,
        'zone': d.zone,
        'body': d.body,
        'priority': d.priority,
        'hops': d.hops,
        'ttl': d.ttl,
        'received_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    return isNew;
  }

  Future<bool> insertReport(EmergencyReport report) async {
    return insertIfNew(MeshPacket.fromReport(report));
  }

  Future<bool> insertMessage(MeshMessage message) async {
    return insertIfNew(MeshPacket.fromMessage(message));
  }

  /// Insert a directive. Returns true if it was new (not a duplicate).
  Future<bool> insertDirective(Directive directive) async {
    final db = await database;
    final count = await db.insert('directives', {
      'id': directive.id,
      'ts': directive.ts,
      'src': directive.src,
      'name': directive.name,
      'to_device': directive.to,
      'zone': directive.zone,
      'body': directive.body,
      'priority': directive.priority,
      'hops': directive.hops,
      'ttl': directive.ttl,
      'received_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return count > 0;
  }

  /// Returns all directives sorted newest-first.
  Future<List<Directive>> getAllDirectives() async {
    final db = await database;
    final rows = await db.query('directives', orderBy: 'ts DESC');
    return rows.map((row) {
      return Directive(
        id: row['id'] as String,
        ts: row['ts'] as int,
        src: row['src'] as String,
        name: row['name'] as String,
        to: row['to_device'] as String?,
        zone: row['zone'] as String?,
        body: row['body'] as String,
        priority: row['priority'] as String,
        hops: row['hops'] as int? ?? 0,
        ttl: row['ttl'] as int? ?? 15,
      );
    }).toList();
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
    await db.delete('directives');
  }

  /// Close the database (used in tests).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
