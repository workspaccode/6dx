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
  /// These are always recorded — including in release builds — because they are
  /// what you look for when a tester reports "it does not work". Pass [error]
  /// to record why a step failed.
  ///
  /// `dart:developer` never reaches logcat in a release build, so the line is
  /// mirrored to stdout there; that is the only copy of the event a beta tester
  /// can hand back with `adb logcat | grep -i action`.
  ///
  /// They never contain tokens or personal data.
  static void action(String tag, String message, [Object? error]) {
    final suffix = error == null ? '' : ' — $error';
    final line = '[ACTION] $tag: $message$suffix';
    if (kReleaseMode) {
      // ignore: avoid_print
      print(line);
      return;
    }
    dev.log(line, name: tag);
  }

  static void _log(
    String level,
    String tag,
    String message, [
    Object? error,
  ]) {
    if (kReleaseMode) {
      // Errors and warnings still matter in a release build; the rest stays in
      // debug only so the log does not become noise.
      if (level == 'ERROR' || level == 'WARN') {
        final suffix = error == null ? '' : ' — $error';
        // ignore: avoid_print
        print('[$level] $tag: $message$suffix');
      }
      return;
    }
    dev.log('[$level] $tag: $message', name: tag, error: error);
  }
}
