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

  /// User action or data operation (sign in, sign up, a query …).
  ///
  /// These are always printed — including in release builds — because they are
  /// what you look for when a tester reports "it does not work". Pass [error]
  /// to record why a step failed.
  ///
  /// They never contain tokens or personal data.
  static void action(String tag, String message, [Object? error]) {
    final suffix = error == null ? '' : ' — $error';
    dev.log('[ACTION] $tag: $message$suffix', name: tag);
  }

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
