// lib/data/db.dart
// sqflite 로그 DB: logs(ts, type, payload)
// 웹(kIsWeb)에서는 메모리 기반으로 대체하여 동작(개인정보 최소 수집 유지)

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LogsDb {
  final Database? db;
  final List<Map<String, Object?>>? _mem;
  LogsDb._db(this.db) : _mem = null;
  LogsDb._mem() : db = null, _mem = <Map<String, Object?>>[];

  static Future<LogsDb> open() async {
    if (kIsWeb) {
      return LogsDb._mem();
    }
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'gaze_tts_logs.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT NOT NULL,
            type TEXT NOT NULL,
            payload TEXT NOT NULL
          );
        ''');
      },
    );
    return LogsDb._db(db);
  }

  Future<void> insertLog({required String type, required String payloadJson}) async {
    final row = {
      'ts': DateTime.now().toIso8601String(),
      'type': type,
      'payload': payloadJson,
    };
    if (db != null) {
      await db!.insert('logs', row);
    } else {
      final id = (_mem!.length + 1);
      _mem!.add({'id': id, ...row});
    }
  }

  Future<List<Map<String, Object?>>> getAll() async {
    if (db != null) {
      return db!.query('logs', orderBy: 'id ASC');
    }
    return List<Map<String, Object?>>.from(_mem!);
  }

  Future<String> exportCsv() async {
    final rows = await getAll();
    final buf = StringBuffer();
    buf.writeln('id,ts,type,payload');
    for (final r in rows) {
      buf.writeln('${r['id']},${r['ts']},${r['type']},"${(r['payload'] ?? '').toString().replaceAll('"', '""')}"');
    }
    return buf.toString();
  }
}
