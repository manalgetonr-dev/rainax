// lib/services/crash_log_service.dart
//
// Lightweight in-app log capture. Stores up to 200 entries in
// SharedPreferences so you can read them from the Debug Logs screen
// even after the app restarts — no PC or logcat needed.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { info, warning, error, fatal }

class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
    'time':    time.toIso8601String(),
    'level':   level.index,
    'tag':     tag,
    'message': message,
  };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
    time:    DateTime.parse(j['time'] as String),
    level:   LogLevel.values[j['level'] as int],
    tag:     j['tag'] as String,
    message: j['message'] as String,
  );

  String get levelLabel => ['INFO', 'WARN', 'ERROR', 'FATAL'][level.index];

  String get formatted =>
      '[${time.toLocal().toString().substring(0, 19)}] '
      '[$levelLabel] [$tag]\n$message';
}

class CrashLogService extends ChangeNotifier {
  CrashLogService._();
  static final CrashLogService instance = CrashLogService._();

  static const _prefKey  = 'rainax_crash_logs_v1';
  static const _maxLogs  = 200;

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  // ── Init ──────────────────────────────────────────────────────────

  Future<void> init() async {
    await _load();
    // Capture Flutter framework errors
    FlutterError.onError = (details) {
      fatal('FlutterError', details.exceptionAsString() +
          '\n' + details.stack.toString());
      FlutterError.presentError(details);
    };
  }

  // ── Public API ────────────────────────────────────────────────────

  void info(String tag, String message)    => _add(LogLevel.info,    tag, message);
  void warning(String tag, String message) => _add(LogLevel.warning, tag, message);
  void error(String tag, String message)   => _add(LogLevel.error,   tag, message);
  void fatal(String tag, String message)   => _add(LogLevel.fatal,   tag, message);

  Future<void> clear() async {
    _logs.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    notifyListeners();
  }

  String get fullText => _logs.reversed
      .map((e) => e.formatted)
      .join('\n\n─────────────────────────────────\n\n');

  // ── Internal ──────────────────────────────────────────────────────

  void _add(LogLevel level, String tag, String message) {
    final entry = LogEntry(
      time: DateTime.now(), level: level, tag: tag, message: message,
    );
    _logs.add(entry);
    if (_logs.length > _maxLogs) _logs.removeAt(0);
    _persist();
    notifyListeners();
    // Mirror to debugPrint so it also shows in IDE/adb if available
    debugPrint('[RAINAX-${entry.levelLabel}] [$tag] $message');
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list  = _logs.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_prefKey, list);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list  = prefs.getStringList(_prefKey) ?? [];
      _logs.clear();
      for (final raw in list) {
        try {
          _logs.add(LogEntry.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          ));
        } catch (_) {}
      }
    } catch (_) {}
  }
}
