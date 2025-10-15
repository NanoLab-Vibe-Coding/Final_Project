// lib/core/logger.dart
// 단순 로깅 파사드 -> sqflite 저장. 개인식별정보 금지.

import 'dart:convert';

import '../data/db.dart';

class AppLogger {
  final LogsDb db;
  AppLogger(this.db);

  Future<void> log(String type, Map<String, dynamic> payload) async {
    await db.insertLog(type: type, payloadJson: jsonEncode(payload));
  }
}

