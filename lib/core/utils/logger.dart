import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void d(String tag, String message) => _log('DEBUG', tag, message);
  static void i(String tag, String message) => _log('INFO', tag, message);
  static void w(String tag, String message, [Object? error]) =>
      _log('WARN', tag, message, error);
  static void e(String tag, String message, [Object? error]) =>
      _log('ERROR', tag, message, error);

  static void _log(
    String level,
    String tag,
    String message, [
    Object? error,
  ]) {
    if (kReleaseMode) return;
    dev.log('[$level] $tag: $message', name: tag, error: error);
  }
}
