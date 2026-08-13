import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'error': error,
      'stackTrace': stackTrace,
    };
  }

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      level: LogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      message: json['message'] ?? '',
      error: json['error'],
      stackTrace: json['stackTrace'],
    );
  }
}

class LogService {
  static const _logsKey = 'app_logs_key';
  static const int _maxLogs = 200; // Limit logs count to prevent memory/storage bloat

  static Future<void> log(
    String message, {
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    try {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
      );

      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getStringList(_logsKey) ?? [];

      logsJson.add(jsonEncode(entry.toJson()));

      if (logsJson.length > _maxLogs) {
        logsJson.removeRange(0, logsJson.length - _maxLogs);
      }

      await prefs.setStringList(_logsKey, logsJson);
    } catch (_) {
      // Fail-silent logging to ensure the app never crashes because of a logging error
    }
  }

  static Future<void> info(String message) => log(message, level: LogLevel.info);
  static Future<void> warning(String message) => log(message, level: LogLevel.warning);
  static Future<void> error(String message, {Object? error, StackTrace? stackTrace}) =>
      log(message, level: LogLevel.error, error: error, stackTrace: stackTrace);

  static Future<List<LogEntry>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getStringList(_logsKey) ?? [];
      return logsJson
          .map((jsonStr) {
            try {
              return LogEntry.fromJson(jsonDecode(jsonStr));
            } catch (_) {
              return null;
            }
          })
          .whereType<LogEntry>()
          .toList()
          .reversed // Newest logs first
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logsKey);
    } catch (_) {}
  }
}
